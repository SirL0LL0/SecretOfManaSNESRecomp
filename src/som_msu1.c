#include "som_msu1.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#define open(path, flags) _open(path, (flags) | _O_BINARY)
#define close _close
#define fstat _fstat64
#define stat _stat64
#define PROT_READ 0
#define MAP_PRIVATE 0
#define MAP_FAILED ((void *)-1)
static void *mmap(void *address,size_t size,int protection,int flags,int fd,int offset) {
  (void)address; (void)protection; (void)flags; (void)offset;
  HANDLE mapping=CreateFileMappingW((HANDLE)_get_osfhandle(fd),NULL,PAGE_READONLY,0,0,NULL);
  if (!mapping) return MAP_FAILED;
  void *view=MapViewOfFile(mapping,FILE_MAP_READ,0,0,size);
  CloseHandle(mapping); return view ? view : MAP_FAILED;
}
static int munmap(void *address,size_t size) {
  (void)size; return UnmapViewOfFile(address) ? 0 : -1;
}
#else
#include <sys/mman.h>
#include <unistd.h>
#endif

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

enum {
    kMsuInputRate = 44100,
    kMsuPcmHeaderSize = 8,
    kMsuMaximumTrack = 239,
    kMsuTrackCount = kMsuMaximumTrack,
};

typedef struct SomMsuTrack {
    const uint8_t *mapping;
    size_t mapping_size;
    uint32_t total_frames;
    uint32_t loop_frame;
    int descriptor;
    bool present;
} SomMsuTrack;

struct SomMsu1 {
    char directory[PATH_MAX];
    SomMsuTrack tracks[kMsuTrackCount];
    const SomMsuTrack *track;
    uint32_t total_frames;
    uint32_t loop_frame;
    uint32_t source_frame;
    uint32_t phase;
    uint16_t song;
    unsigned track_number;
    int16_t current_sample[2];
    int16_t next_sample[2];
    double gain;
    bool loop;
    bool playing;
    bool final_sample;
    bool song_valid;
};

static void SetError(char *error, size_t error_size, const char *message) {
    if (error && error_size)
        (void)snprintf(error, error_size, "%s",
                       message ? message : "unknown error");
}

static uint32_t ReadLittle32(const uint8_t bytes[4]) {
    return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
           ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static int16_t ReadLittle16(const uint8_t bytes[2]) {
    return (int16_t)(uint16_t)(bytes[0] | ((uint16_t)bytes[1] << 8));
}

static void CloseTrack(SomMsu1 *player) {
    player->track = NULL;
    player->playing = false;
    player->final_sample = false;
    player->track_number = 0;
    player->total_frames = 0;
    player->loop_frame = 0;
    player->source_frame = 0;
    player->phase = 0;
    player->current_sample[0] = player->current_sample[1] = 0;
    player->next_sample[0] = player->next_sample[1] = 0;
    player->loop = false;
    player->playing = false;
    player->final_sample = false;
    player->song_valid = false;
}

static bool ReadPcmHeader(SomMsu1 *player, SomMsuTrack *track) {
    if (track->mapping_size < kMsuPcmHeaderSize)
        return false;
    track->total_frames = ReadLittle32(track->mapping + 0);
    track->loop_frame = ReadLittle32(track->mapping + 4);
    return true;
}

static bool OpenTrack(SomMsu1 *player, unsigned track_number) {
    CloseTrack(player);
    if (track_number == 0 || track_number > kMsuTrackCount)
        return false;
    SomMsuTrack *track = &player->tracks[track_number - 1];
    if (!track->present) {
        char path[PATH_MAX];
        snprintf(player->directory, sizeof(player->directory), "%s", player->directory);
        snprintf(player->directory + strlen(player->directory), 
                 sizeof(player->directory) - strlen(player->directory), 
                 "/%u.pcm", track_number);
        int fd = open(player->directory, O_RDONLY);
        if (fd < 0) {
            track->present = false;
            return false;
        }
        struct stat st;
        if (fstat(fd, &st) != 0) {
            close(fd);
            track->present = false;
            return false;
        }
        track->mapping_size = st.st_size;
        track->mapping = mmap(NULL, track->mapping_size, PROT_READ, MAP_PRIVATE, fd, 0);
        close(fd);
        if (track->mapping == MAP_FAILED) {
            track->mapping = NULL;
            track->mapping_size = 0;
            track->present = false;
            return false;
        }
        track->present = true;
    }
    if (!ReadPcmHeader(player, track)) {
        CloseTrack(player);
        return false;
    }
    player->track = &player->tracks[track_number - 1];
    player->track_number = track_number;
    player->total_frames = player->track->total_frames;
    player->loop_frame = player->track->loop_frame;
    player->source_frame = 0;
    player->phase = 0;
    player->current_sample[0] = player->current_sample[1] = 0;
    player->next_sample[0] = player->next_sample[1] = 0;
    player->loop = true;
    player->playing = true;
    player->final_sample = false;
    player->song_valid = true;
    return true;
}

SomMsu1 *SomMsu1Open(const char *directory, char *error, size_t error_size) {
    SomMsu1 *player = calloc(1, sizeof(SomMsu1));
    if (!player) {
        SetError(error, error_size, "out of memory");
        return NULL;
    }
    strncpy(player->directory, directory, PATH_MAX - 1);
    player->gain = 1.0;
    return player;
}

void SomMsu1Close(SomMsu1 *player) {
    if (!player) return;
    for (unsigned i = 0; i < kMsuTrackCount; i++) {
        if (player->tracks[i].mapping) {
            munmap((void *)player->tracks[i].mapping, player->tracks[i].mapping_size);
            player->tracks[i].mapping = NULL;
        }
    }
    free(player);
}

unsigned SomMsu1TrackNumber(unsigned song, unsigned variant) {
    (void)variant;
    return song;
}

bool SomMsu1Select(SomMsu1 *player, unsigned song, unsigned variant) {
    (void)variant;
    if (!player) return false;
    if (song == 0) {
        CloseTrack(player);
        return false;
    }
    if (song == player->song && player->track && player->track_number == SomMsu1TrackNumber(song, 0)) {
        return true;
    }
    unsigned track_number = SomMsu1TrackNumber(song, 0);
    if (OpenTrack(player, track_number)) {
        player->song = song;
        return true;
    }
    return false;
}

void SomMsu1Reset(SomMsu1 *player) {
    if (!player) return;
    CloseTrack(player);
}

void SomMsu1SetGain(SomMsu1 *player, int percent) {
    if (!player) return;
    if (percent < 0) percent = 0;
    if (percent > 200) percent = 200;
    player->gain = percent / 100.0;
}

void SomMsu1Mix(SomMsu1 *player, int16_t *samples, int frames, int channels, int output_rate) {
    if (!player || !player->track || !player->playing) {
        memset(samples, 0, frames * channels * sizeof(int16_t));
        return;
    }

    double ratio = (double)kMsuInputRate / output_rate;
    const uint8_t *data = player->track->mapping + kMsuPcmHeaderSize;
    size_t data_size = player->track->mapping_size - kMsuPcmHeaderSize;

    for (int i = 0; i < frames; i++) {
        double pos = player->source_frame * ratio + player->phase;
        uint32_t idx = (uint32_t)pos;
        double frac = pos - idx;

        if (idx >= player->total_frames) {
            if (player->loop && player->loop_frame < player->total_frames) {
                player->source_frame = player->loop_frame;
                player->phase = 0;
                idx = player->loop_frame;
                frac = 0;
            } else {
                player->playing = false;
                memset(samples + i * 2, 0, (frames - i) * 2 * sizeof(int16_t));
                break;
            }
        }

        int16_t sample_l = ReadLittle16(data + idx * 4 + 0);
        int16_t sample_r = ReadLittle16(data + idx * 4 + 2);

        int16_t next_l = sample_l;
        int16_t next_r = sample_r;
        if (idx + 1 < player->total_frames) {
            next_l = ReadLittle16(data + (idx + 1) * 4 + 0);
            next_r = ReadLittle16(data + (idx + 1) * 4 + 2);
        }

        int16_t interp_l = sample_l + (int16_t)((next_l - sample_l) * frac);
        int16_t interp_r = sample_r + (int16_t)((next_r - sample_r) * frac);

        samples[i * 2 + 0] = (int16_t)(interp_l * player->gain);
        samples[i * 2 + 1] = (int16_t)(interp_r * player->gain);

        player->source_frame++;
    }
}

unsigned SomMsu1CurrentTrack(const SomMsu1 *player) {
    return player ? player->track_number : 0;
}

const char *SomMsu1Directory(const SomMsu1 *player) {
    return player ? player->directory : "";
}