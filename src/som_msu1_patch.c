/*
 * som_msu1_patch.c — DarkShock's "Secret of Mana MSU-1" hack v1.0, as a mod.
 *
 * The hack (github.com/mlarouche/SecretOfMana-MSU1, secret_of_mana_msu1.asm)
 * patches the ROM in three places:
 *
 *   C3:0004  jmp $0160 -> jmp MSU_Hijack   (the music-command routine)
 *   00:8008  jml Reset_Hijack              (fade variables + NMI trampoline)
 *   C0:FFEA  NMI vector -> $0122           (NMI_Update: the volume fade)
 *
 * and puts its code at CB:3400. None of that can be applied as bytes here:
 * C3:0004 and the reset path are recompiled code, so changed ROM bytes would
 * never run, and the Italian translation keeps its credits text at CB:3400.
 * Instead this file is the same program in C, routine for routine:
 *
 *   MSU_Hijack/MSU_Main  -> som_msu_sound_entry, which the build links in
 *                           place of bank_C3_0004_M1X0 at its call sites
 *                           (CMakeLists.txt). Where the hack returns carry
 *                           set (fall through to `jmp $0160`), the recompiled
 *                           original runs; carry clear returns at once. No
 *                           path goes through the interpreter.
 *   NMI_Update           -> a once-per-frame mod callback.
 *   Reset_Hijack         -> plugin activation (boot).
 *
 * Its variables stay where the hack put them ($7E1EDD-$7E1EE5) so they are
 * part of save states like the rest of WRAM. One addition: $7E1EDC holds the
 * MSU-1 track the hack started, plus one (0 = SPC music), so a save-state load
 * can restart the right track -- MSU-1 playback itself is not in a state.
 */

#include "som_msu1_patch.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common_cpu_infra.h"
#include "common_rtl.h"
#include "cpu_state.h"
#include "mod_runtime.h"
#include "snes/msu1.h"

#define SOM_MSU1_PACKAGE  "som.msu1"
#define SOM_MSU1_FEATURE  "msu1"
#define SOM_MSU1_RESOURCE "pack"
#define SOM_MSU1_PLUGIN   "som.msu1"

/* MSU-1 registers and status bits (the hack's constants). */
enum {
    kMsuStatus = 0x2000, kMsuId = 0x2002, kMsuTrackLo = 0x2004,
    kMsuTrackHi = 0x2005, kMsuVolume = 0x2006, kMsuControl = 0x2007,
    kMsuTrackMissing = 0x08, kMsuAudioBusy = 0x40,
    kFullVolume = 0xFF,              /* the released patch: hardware volume */
};

/* Game variables. */
enum {
    kMusicCommand = 0x1E00, kRequestedSong = 0x1E01, kPreviousSong = 0x1E05,
};

/* The hack's variables, and this port's resume marker. */
enum {
    kMsuResumeTrack = 0x1EDC,
    kFadeState = 0x1EDD, kFadeVolume = 0x1EDE, kFadeStep = 0x1EE0,
    kFadeTemp = 0x1EE2, kFadeCount = 0x1EE4, kFrameCount = 0x1EE5,
};

/* The address the native RTL below reports as its source (the RTL that ends
 * the original music routine). */
#define SOM_RTL_PC24 0xC30197u

RecompReturn bank_C3_0004_M1X0(CpuState *cpu);
RecompReturn som_msu_sound_entry(CpuState *cpu);

static bool s_active;           /* feature on and the plugin activated */
static int s_track = -1;        /* track this file last started, -1 none */

static uint16_t Ram16(uint16_t addr) {
    return (uint16_t)(g_ram[addr] | g_ram[addr + 1] << 8);
}

static void SetRam16(uint16_t addr, uint16_t value) {
    g_ram[addr] = (uint8_t)value;
    g_ram[addr + 1] = (uint8_t)(value >> 8);
}

static bool MsuPresent(void) {
    /* CheckMSUPresence: lda MSU_ID / cmp #'S'. */
    return s_active && msu1_enabled() && msu1_read(kMsuId) == 'S';
}

/* Charge the CPU time of one instruction, as recompiled code does, so the
 * SPC keeps running while the handshake below polls it. */
static void Spend(CpuState *cpu, unsigned cycles) {
    cpu->coprocessor_master_cycles = cpu->master_cycles;
    cpu->cycles += cycles;
    cpu->master_cycles += cycles * ((g_memsel && (cpu->PB & 0x80)) ? 6 : 8);
}

/* `sta SPC_COMM_0` then `cmp SPC_COMM_0 / bne` until the SPC echoes. */
static void SpcCommand(CpuState *cpu, uint8_t command) {
    Spend(cpu, 5);
    cpu_write8(cpu, 0x00, 0x2140, command);
    for (unsigned spin = 0;; ++spin) {
        Spend(cpu, 7);
        if (cpu_read8(cpu, 0x00, 0x2140) == command) break;
        if (spin == 200000) {
            fprintf(stderr, "[MSU-1] SPC did not echo $%02X; continuing\n", command);
            break;
        }
    }
    Spend(cpu, 5);
    cpu_write8(cpu, 0x00, 0x2140, 0x00);
}

/* Stop_SPC: stop SPC music ($F1), then looping sound effects ($F2). */
static void StopSpc(CpuState *cpu) {
    SpcCommand(cpu, 0xF1);
    SpcCommand(cpu, 0xF2);
}

/* TrackNeedLooping: jingles and sound effects play once. */
static uint8_t TrackControl(uint8_t song) {
    static const uint8_t kOnce[] = {
        0x17, 0x19, 0x1A, 0x1E, 0x21, 0x22, 0x23, 0x28, 0x2D, 0x2E, 0x2F, 0x30, 0x35,
    };
    for (size_t i = 0; i < sizeof(kOnce); ++i)
        if (song == kOnce[i]) return 0x01;
    return 0x03;
}

/* Gain for tracks of the pack mastered far below the rest: the title theme
 * ($2C) averages -24.8 dBFS against about -15 for the others and opens with
 * 80 s of peaks near 3000. msu1 limits the loud passages. */
static double TrackGain(uint8_t song) {
    return song == 0x2C ? 3.0 : 1.0;
}

/* Select a track and wait out the busy bit. True when the track exists. */
static bool MsuSelect(uint8_t track) {
    msu1_write(kMsuTrackLo, track);
    msu1_write(kMsuTrackHi, 0x00);
    for (unsigned spin = 0; spin < 100000 && (msu1_read(kMsuStatus) & kMsuAudioBusy); ++spin) {}
    return (msu1_read(kMsuStatus) & kMsuTrackMissing) == 0;
}

/* MSU_PlayMusic. Returns the carry: true = let the SPC play it. */
static bool MsuPlayMusic(CpuState *cpu) {
    const uint8_t variant = g_ram[0x1E02] & 0x0F;
    const uint8_t song = g_ram[kRequestedSong];
    /* cpx PreviousSong: song and variant both already playing. */
    if (Ram16(kPreviousSong) == (uint16_t)(song | variant << 8))
        return false;

    StopSpc(cpu);
    if (!MsuSelect(song)) {
        /* TrackMissing: give the command back to the original routine. */
        g_ram[kMusicCommand] = 0x01;
        msu1_write(kMsuVolume, 0x00);
        g_ram[kMsuResumeTrack] = 0;
        s_track = -1;
        fprintf(stderr, "[MSU-1] song $%02X: no track in the pack, SPC plays it\n", song);
        return true;
    }
    fprintf(stderr, "[MSU-1] song $%02X: track %u\n", song, song);
    msu1_set_track_gain(TrackGain(song));
    msu1_write(kMsuControl, TrackControl(song));
    msu1_write(kMsuVolume, kFullVolume);
    g_ram[kFadeVolume + 1] = kFullVolume;
    g_ram[kPreviousSong] = song;
    g_ram[kPreviousSong + 1] = variant;
    g_ram[kPreviousSong + 2] = g_ram[0x1E03];
    g_ram[kMsuResumeTrack] = (uint8_t)(song + 1);
    s_track = song;
    return false;
}

/* MSU_Fade: $1E01 = frames (high nibble, x16) and target volume (low
 * nibble, x$11). The 4202/4204 multiply and divides, done here directly; the
 * 16-bit step carries an 8.8 fixed-point volume delta every other frame. */
static void MsuFade(void) {
    const uint8_t request = g_ram[kRequestedSong];
    const uint8_t count = request & 0xF0;
    const uint8_t target = (uint8_t)((request & 0x0F) * 0x11);
    g_ram[kFadeCount] = count;
    if (count == 0) {
        g_ram[kFadeStep] = 0;    /* `sta FadeStep` with an 8-bit A of 0 */
        return;
    }
    const uint8_t current = g_ram[kFadeVolume + 1];
    const bool rising = target >= current;     /* the carry out of the sbc */
    const uint8_t diff = rising ? (uint8_t)(target - current) : (uint8_t)(current - target);
    const uint8_t whole = (uint8_t)(diff / count);
    const uint8_t fraction = (uint8_t)(((unsigned)(diff % count) << 8) / count);
    uint16_t step = (uint16_t)(whole << 8 | fraction);
    if (!rising) step = (uint16_t)(~step + 1);
    SetRam16(kFadeTemp, step);
    SetRam16(kFadeStep, step);
    g_ram[kFadeVolume] = 0;
    g_ram[kFadeState] = 1;
}

/* MSU_Hijack's `rtl` when MSU_Main returns carry clear: pop the caller's JSL
 * frame the way every recompiled RTL does (bankc3_v2.c), so this path stays in
 * compiled code. The usual case is a direct call from compiled code (hrv 3)
 * returning to the address it pushed; anything else is dispatched by PC. */
static RecompReturn NativeRtl(CpuState *cpu) {
    uint16 entry_s = cpu->S;
    uint8 hrv = cpu->host_return_valid;
    if (cpu_take_tailcall_return_context(&entry_s, &hrv))
        cpu->host_return_valid = hrv;
    uint32 host_return_pc24 = 0xFFFFFFFFu;
    if (hrv == 2 || hrv == 3) {
        const uint16 lo = cpu_read8(cpu, 0x00, (uint16)(entry_s + 1u));
        const uint16 hi = cpu_read8(cpu, 0x00, (uint16)(entry_s + 2u));
        const uint8 bank = hrv == 3 ? cpu_read8(cpu, 0x00, (uint16)(entry_s + 3u)) : cpu->PB;
        host_return_pc24 = (uint32)bank << 16 | (uint16)(((hi << 8) | lo) + 1u);
    }
    const uint16 ret_s = cpu->S;
    const uint16 lo = cpu_read8(cpu, 0x00, (uint16)(ret_s + 1u));
    const uint16 hi = cpu_read8(cpu, 0x00, (uint16)(ret_s + 2u));
    const uint8 bank = cpu_read8(cpu, 0x00, (uint16)(ret_s + 3u));
    cpu->S = (uint16)(ret_s + 3u);
    const uint32 rpc24 = (uint32)bank << 16 | (uint16)(((hi << 8) | lo) + 1u);
    if (hrv == 3 && ret_s == entry_s && rpc24 == host_return_pc24)
        return RECOMP_RETURN_NORMAL;
    return cpu_dispatch_pc_from(cpu, rpc24, (uint16)(entry_s + 3u), SOM_RTL_PC24);
}

/* MSU_Main + MSU_Hijack, linked in place of bank_C3_0004_M1X0. */
RecompReturn som_msu_sound_entry(CpuState *cpu) {
    bool original = true;
    if (MsuPresent()) {
        const uint8_t command = g_ram[kMusicCommand];
        if (command == 0x00) {
            original = false;                         /* DoNothing */
        } else if (command == 0x01) {
            g_ram[kMusicCommand] = 0;
            original = MsuPlayMusic(cpu);
        } else if (command == 0x80) {
            g_ram[kMusicCommand] = 0;
            MsuFade();
        } else if (command == 0xF1) {
            g_ram[kMusicCommand] = 0;
            msu1_write(kMsuControl, 0x00);            /* MSU_Stop */
            g_ram[kMsuResumeTrack] = 0;
            s_track = -1;
        }
    }
    cpu->_flag_C = original ? 1 : 0;                  /* sec / clc */
    cpu_mirrors_to_p(cpu);
    if (original) return bank_C3_0004_M1X0(cpu);       /* jmp $0160 */
    return NativeRtl(cpu);                             /* bcc ReturnToCode: rtl */
}

/* NMI_Update: one step of the fade every other frame. */
static void SomMsu1Frame(void) {
    if (!MsuPresent()) return;
    const uint8_t frame = ++g_ram[kFrameCount];
    if (!g_ram[kFadeState] || (frame & 1)) return;
    SetRam16(kFadeVolume, (uint16_t)(Ram16(kFadeVolume) + Ram16(kFadeStep)));
    msu1_write(kMsuVolume, g_ram[kFadeVolume + 1]);
    const uint8_t count = (uint8_t)(g_ram[kFadeCount] - 1);
    if (count == 0) g_ram[kFadeState] = 0;
    g_ram[kFadeCount] = count;
}

/* Reset_Hijack's variable setup; the NMI trampoline it installs at $0122 is
 * SomMsu1Frame's registration. */
static void SomMsu1Activate(void) {
    s_active = true;
    s_track = -1;
    SetRam16(kFadeVolume, 0xFFFF);
    g_ram[kFadeState] = 0;
    snes_mod_register_frame_callback(SomMsu1Frame);
}

void SomMsu1PatchRegister(void) {
    snes_mod_register_activation_plugin(SOM_MSU1_PLUGIN, SomMsu1Activate);
}

void SomMsu1PatchTimelineJumped(void) {
    if (!MsuPresent()) return;
    const uint8_t resume = g_ram[kMsuResumeTrack];
    if (resume == 0) {
        if (s_track >= 0) msu1_write(kMsuControl, 0x00);
        s_track = -1;
        return;
    }
    const uint8_t song = (uint8_t)(resume - 1);
    if (s_track == song) return;
    if (!MsuSelect(song)) {
        s_track = -1;
        return;
    }
    msu1_set_track_gain(TrackGain(song));
    msu1_write(kMsuControl, TrackControl(song));
    msu1_write(kMsuVolume, g_ram[kFadeVolume + 1]);
    s_track = song;
}

int SomMsu1PatchPrepare(char *error, size_t error_cap) {
    if (!snes_mod_runtime_feature_enabled_c(SOM_MSU1_PACKAGE, SOM_MSU1_FEATURE))
        return 1;
    const char *configured = getenv("SNESRECOMP_MSU1");
    if (configured && configured[0]) return 1;  /* an explicit pack wins */
    char folder[1024];
    if (!snes_mod_runtime_resource_path_c(SOM_MSU1_PACKAGE, SOM_MSU1_FEATURE,
                                          SOM_MSU1_RESOURCE, folder, sizeof(folder)) ||
        !folder[0]) {
        snprintf(error, error_cap, "MSU-1 Music: choose the music pack folder on the Mods page");
        return 0;
    }
#ifdef _WIN32
    (void)_putenv_s("SNESRECOMP_MSU1", folder);
#else
    (void)setenv("SNESRECOMP_MSU1", folder, 1);
#endif
    fprintf(stderr, "som: MSU-1 music pack %s\n", folder);
    return 1;
}
