#include "som_music.h"

#include "som_spc_music.h"
#include "som_msu1.h"
#include "snes/apu.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { kMuteOffset = 0x01D5C1 }; /* Secret of Mana IRQ vector area used for music mute */

static SomMsu1 *s_player = NULL;
static struct Apu *s_apu = NULL;
static uint8_t *s_rom = NULL;
static size_t s_size = 0;
static char s_directory[4096] = "";
static char s_status[256] = "Original SNES music";
static bool s_enabled = false, s_replacement = false, s_policy_ready = false, s_started = false;
static unsigned s_song = 0, s_variant = 0;
static int s_gain = 100;

static void ApplyPolicy(void) {
    s_policy_ready = false;
    if (!s_rom || s_size <= kMuteOffset + 1) return;
    uint8_t *branch = s_rom + kMuteOffset;
    /* Check for known branch patterns at the music mute location */
    if (!((branch[0] == 0xD0 && branch[1] == 0x05) ||
          (branch[0] == 0x00 && branch[1] == 0x00))) return;
    /* Only the checksum-verified resident image is changed; never the ROM file. */
    const bool mute = s_enabled && s_replacement;
    branch[0] = mute ? 0x00 : 0xD0;
    branch[1] = mute ? 0x00 : 0x05;
    s_policy_ready = SomRestoreSpcMusicPolicy(s_apu, s_rom, s_size) != 0;
}

static void SelectCurrent(void) {
    s_replacement = s_enabled && s_started &&
        SomMsu1Select(s_player, s_song, s_variant);
    if (!s_replacement) SomMsu1Reset(s_player);
    if (!s_enabled)
        snprintf(s_status, sizeof s_status, "Original SNES music");
    else if (!s_player)
        snprintf(s_status, sizeof s_status, "Choose an extracted MSU-1 music folder");
    else if (s_replacement)
        snprintf(s_status, sizeof s_status, "MSU-1 track %u", SomMsu1CurrentTrack(s_player));
    else if (s_started && s_song)
        snprintf(s_status, sizeof s_status, "Track %u unavailable; using SNES music",
                 SomMsu1TrackNumber(s_song, s_variant));
    else
        snprintf(s_status, sizeof s_status, "MSU-1 ready; waiting for music");
    ApplyPolicy();
}

bool SomMusicLoad(const char *directory) {
    char error[256];
    SomMsu1 *next = SomMsu1Open(directory, error, sizeof error);
    if (!next) {
        snprintf(s_status, sizeof s_status, "%s", error);
        return false;
    }
    SomMsu1Close(s_player);
    s_player = next;
    snprintf(s_directory, sizeof s_directory, "%s", directory);
    SomMsu1SetGain(s_player, s_gain);
    s_enabled = true;
    SelectCurrent();
    return true;
}

void SomMusicSetEnabled(bool enabled) { s_enabled = enabled; SelectCurrent(); }
bool SomMusicEnabled(void) { return s_enabled; }
void SomMusicSetGain(int percent) {
    s_gain = percent < 0 ? 0 : percent > 200 ? 200 : percent;
    SomMsu1SetGain(s_player, s_gain);
}
int SomMusicGain(void) { return s_gain; }
const char *SomMusicDirectory(void) { return s_directory; }
const char *SomMusicStatus(void) { return s_status; }

bool SomMusicSaveSettings(void) {
    FILE *f = fopen("msu1.cfg", "w");
    if (!f) return false;
    bool ok = fprintf(f, "%d %d\n%s\n", s_enabled ? 1 : 0, s_gain, s_directory) > 0;
    return fclose(f) == 0 && ok;
}

void SomMusicInitialize(void) {
    char path[4096] = "", line[4096];
    int enabled = 0, gain = 100;
    FILE *f = fopen("msu1.cfg", "r");
    if (f) {
        if (fgets(line, sizeof line, f)) (void)sscanf(line, "%d %d", &enabled, &gain);
        if (fgets(s_directory, sizeof s_directory, f)) s_directory[strcspn(s_directory, "\r\n")] = 0;
        fclose(f);
    }
    const char *gain_override = getenv("SOM_MSU1_VOLUME");
    if (gain_override && *gain_override) {
        char *end = NULL;
        const long parsed = strtol(gain_override, &end, 10);
        if (!*end && parsed >= 0 && parsed <= 200) gain = (int)parsed;
    }
    SomMusicSetGain(gain);
    const char *override = getenv("SOM_MSU1_PATH");
    if (override) {
        snprintf(s_directory, sizeof s_directory, "%s", override);
        enabled = *override != 0;
    }
    if (*s_directory && !SomMusicLoad(s_directory)) {
        fprintf(stderr, "MSU-1: %s\n", s_status);
        s_enabled = false;
    } else SomMusicSetEnabled(enabled != 0);
}

void SomMusicCommand(uint16_t song, uint16_t command) {
    const unsigned action = command & 255u;
    if (action == 255) {
        s_song = song & 255u;
        s_variant = 0;
        s_started = false;
        SelectCurrent();
    } else if (action == 251) {
        s_song = song & 255u;
        s_variant = command >> 8;
        s_started = true;
        SelectCurrent();
    } else if (action == 254 && !s_started) {
        s_song = song & 255u;
        s_started = true;
        SelectCurrent();
    }
}

void SomMusicStateLoaded(struct Apu *apu, const uint8_t *ram) {
    s_song = ram ? ram[0x1C] : 0;
    s_variant = 0;
    if (apu) {
        const unsigned base = apu->ram[0xE5] | (unsigned)apu->ram[0xE6] << 8;
        if (base != 0x1300) for (unsigned i = 1; i <= 5; ++i) {
            const unsigned a = 0x1312 + 2 * i;
            if (base == (apu->ram[a] | (unsigned)apu->ram[a + 1] << 8)) {
                s_variant = i;
                break;
            }
        }
    }
    s_started = true;
    SelectCurrent();
}

void SomMusicFrame(struct Apu *apu, uint8_t *rom, size_t size, const uint8_t *ram) {
    (void)ram;
    s_apu = apu;
    s_rom = rom;
    s_size = size;
    ApplyPolicy();
}

void SomMusicMix(int16_t *samples, int frames, int rate) {
    if (s_enabled && s_replacement && s_policy_ready)
        SomMsu1Mix(s_player, samples, frames, 2, rate);
}