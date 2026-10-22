/*
 * som_main.c — Secret of Mana desktop entry point.
 *
 * Thin shim over the framework's desktop host (desktop/host_main.c).
 * The host owns: ROM resolution + digest check, launcher, config.ini,
 * keybinds, SDL window/renderer, audio device, gamepads, SRAM, save
 * states, rewind, OSD and the pacing loop. It also defines Die,
 * RtlApuLock/RtlApuUnlock, g_spc_player and the PPU/widescreen globals,
 * so this file must not define those.
 *
 * The frame driver is assembled in som_frame_driver.c so desktop and
 * headless sessions use the same beam-aligned raster model.
 */

#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <unistd.h>
#endif

#include "desktop/host_main.h"
#include "mod_runtime.h"
#include "rom_patch.h"
#include "sha256.h"
#include "som_frame_driver.h"
#include "som_cheats.h"
#include "som_msu1_patch.h"
#include "som_music.h"
#include "som_spc_player.h"

/* Trace-build hooks the framework leaves to the port. */
void debug_on_wram_write_byte(uint32_t addr, uint8_t old_val, uint8_t new_val) {
    (void)addr; (void)old_val; (void)new_val;
}
void debug_on_wram_write_word(uint32_t addr, uint16_t old_val, uint16_t new_val) {
    (void)addr; (void)old_val; (void)new_val;
}
void debug_on_block_enter(uint32_t pc24) { (void)pc24; }

/* Keep captures beside the project instead of in a per-user app-data folder.
 * The build scripts place the executable in <project>/build, so walking up
 * twice from its real path gives a stable project-local output directory. */
static void SomConfigureCoverageDirectory(void) {
#if SNESRECOMP_EXPOSE_COVERAGE_MOD
    const char *configured = getenv("SNESRECOMP_COVERAGE_DIR");
    if (configured && configured[0]) return;

    char executable[2048];
    size_t length = 0;
#ifdef _WIN32
    DWORD count = GetModuleFileNameA(NULL, executable, (DWORD)sizeof(executable));
    if (!count || count >= sizeof(executable)) return;
    length = (size_t)count;
#else
    ssize_t count = readlink("/proc/self/exe", executable, sizeof(executable) - 1);
    if (count <= 0 || (size_t)count >= sizeof(executable) - 1) return;
    length = (size_t)count;
#endif
    executable[length] = '\0';

    char *separator = strrchr(executable, '/');
#ifdef _WIN32
    char *backslash = strrchr(executable, '\\');
    if (!separator || (backslash && backslash > separator)) separator = backslash;
#endif
    if (!separator) return;
    *separator = '\0'; /* executable directory (build) */

    separator = strrchr(executable, '/');
#ifdef _WIN32
    backslash = strrchr(executable, '\\');
    if (!separator || (backslash && backslash > separator)) separator = backslash;
#endif
    if (!separator) return;
    *separator = '\0'; /* project root */

    char coverage_dir[2304];
    if (snprintf(coverage_dir, sizeof(coverage_dir), "%s/coverage/runs", executable) >=
        (int)sizeof(coverage_dir)) return;
#ifdef _WIN32
    (void)_putenv_s("SNESRECOMP_COVERAGE_DIR", coverage_dir);
#else
    (void)setenv("SNESRECOMP_COVERAGE_DIR", coverage_dir, 0);
#endif
#endif
}

/* Mods page → Music → Restore Unused Fanfares (mods/preloaded/packages/
 * som.restore-unused-fanfares). The package carries the IPS and the digest
 * of the patched image; it is applied here, in memory, only when the feature
 * is enabled in the committed plan. A patch that does not reproduce the
 * declared image refuses the launch rather than run a half-patched ROM. */
#define SOM_FANFARES_PACKAGE "som.restore-unused-fanfares"
#define SOM_FANFARES_FEATURE "restore"
#define SOM_FANFARES_IPS     "restore-unused-fanfares-it.ips"
static const char kSomFanfaresSha256[] =
    "96b0d01ea873595bc5343a0cb7786c9abfe53febb2e1b495b34d7cc84eb9ce40";

static int SomApplyFanfares(uint8_t *rom, size_t size, char *error, size_t error_cap) {
#if SNESRECOMP_ENABLE_MODS
    if (!snes_mod_runtime_feature_enabled_c(SOM_FANFARES_PACKAGE, SOM_FANFARES_FEATURE))
        return 1;
    char root[1024], path[1200];
    if (!snes_mod_runtime_package_root_c(SOM_FANFARES_PACKAGE, NULL, root, sizeof(root)) ||
        snprintf(path, sizeof(path), "%s/%s", root, SOM_FANFARES_IPS) >= (int)sizeof(path)) {
        snprintf(error, error_cap, "Restore Unused Fanfares: package folder not found");
        return 0;
    }
    FILE *f = fopen(path, "rb");
    uint8_t ips[256];
    size_t ips_size = f ? fread(ips, 1, sizeof(ips), f) : 0;
    if (f) fclose(f);
    uint8_t *patched = NULL;
    size_t patched_size = 0;
    RomPatchStatus status = ips_size
        ? snes_rom_patch_apply(rom, size, ips, ips_size, size, &patched, &patched_size)
        : kRomPatch_Invalid;
    if (status != kRomPatch_Ok || patched_size != size) {
        free(patched);
        snprintf(error, error_cap, "Restore Unused Fanfares: %s (%s)",
                 ips_size ? snes_rom_patch_status_text(status) : "cannot read the patch", path);
        return 0;
    }
    uint8_t digest[32];
    char hex[65];
    sha256_compute(patched, patched_size, digest);
    for (unsigned i = 0; i < 32; ++i) snprintf(hex + 2 * i, 3, "%02x", digest[i]);
    if (strcmp(hex, kSomFanfaresSha256) != 0) {
        free(patched);
        snprintf(error, error_cap, "Restore Unused Fanfares: patched ROM digest %s does not match", hex);
        return 0;
    }
    memcpy(rom, patched, size);
    free(patched);
    fprintf(stderr, "som: Restore Unused Fanfares applied in memory\n");
#else
    (void)rom; (void)size; (void)error; (void)error_cap;
#endif
    return 1;
}

/* Mods → Translation → Italian translation fixes (som.translation-fixes, on
 * by default): event-script bytes the translation got wrong. Each entry
 * names the byte the translation has, and is skipped if the image holds
 * anything else.
 *
 * In the script a text block ends with 28 00 xx: wait for a key, then 7F (new
 * line; a full three-line box turns the page), 52 (clear the box and go on)
 * or 51 (close the box). The translation split Elliott's "But I heard
 * Grandma..." over two boxes, the second only two lines long, and ended it
 * with 51 -- so Timothy's next line was printed with the box closed: outside
 * it on the right, then in a borderless box. 52 is what it needs; the scene
 * then matches the US release. Checked against Mesen. */
typedef struct SomScriptFix { uint32_t offset; uint8_t from, to; } SomScriptFix;
static const SomScriptFix kSomTranslationFixes[] = {
    {0x0927F2, 0x51, 0x52},   /* C9:27F2 bridge, before "TIMOTHY: Dev'essere una" */
};

static void SomApplyTranslationFixes(uint8_t *rom, size_t size) {
#if SNESRECOMP_ENABLE_MODS
    if (!snes_mod_runtime_feature_enabled_c("som.translation-fixes", "fixes")) return;
    unsigned applied = 0;
    for (size_t i = 0; i < sizeof(kSomTranslationFixes) / sizeof(kSomTranslationFixes[0]); ++i) {
        const SomScriptFix *fix = &kSomTranslationFixes[i];
        if (fix->offset < size && rom[fix->offset] == fix->from) {
            rom[fix->offset] = fix->to;
            ++applied;
        }
    }
    fprintf(stderr, "som: Italian translation fixes applied in memory (%u)\n", applied);
#else
    (void)rom; (void)size;
#endif
}

/* The mods that act before SnesInit: the fanfares IPS (checked against its
 * digest, so first), the translation fixes, the ROM-data cheats, and the
 * MSU-1 pack. */
static int SomPrepareRom(uint8_t *rom, size_t size, char *error, size_t error_cap) {
    if (!SomApplyFanfares(rom, size, error, error_cap)) return 0;
    SomApplyTranslationFixes(rom, size);
    return
           SomCheatsPatchRom(rom, size, error, error_cap) &&
           SomMsu1PatchPrepare(error, error_cap);
}

int main(int argc, char **argv) {
    SomConfigureCoverageDirectory();
    SomMsu1PatchRegister();                   /* Mods → Music → MSU-1 Music */
    SomCheatsRegister();                      /* Mods → Cheats → Cheats */
    SnesDesktopHostGame game = {0};

    /* ── Identity ─────────────────────────────────────────────────────── */
    game.display_name = "Secret of Mana";
    game.window_title = NULL;                 /* "<name> (Recompiled)" */
    game.launcher_title = NULL;               /* "<name> — Launcher" */
    game.region = "USA";
    game.rom_file = NULL;
    game.expected_sha256_hex =
        "8622ebc30446c5a620a110f2fc2622aac82c6fa75f946b666b221592d57cc275";
    game.expected_crc32_hex = NULL;
    game.game_id = "secret-of-mana";          /* enables the launcher's diagnostic capture toggle */
    game.build_version = "dev";
    game.env_prefix = "SOM";
    game.sram_path = "saves/save.srm";
    game.default_config_ini = NULL;
    game.game_info = som_frame_driver_game_info("secret-of-mana");
    game.num_players = 1;
    game.debug_port = 0;                      /* 0 => 4377 */
    game.widescreen_supported = 1;
    game.msu1_supported = 0;                  /* SomMsu1 is driven by msu1.cfg */
    game.simulation_hz = 0;                   /* NTSC 60.0988 Hz */
    game.frame_width = 256;
    game.frame_height = 224;
    game.native_widescreen = 0;
    game.state_menu_hotkeys = 1;
    game.display_aspect_supported = 1;
    game.shader_supported = 1;

    /* ── Hooks ────────────────────────────────────────────────────────── */
    game.create_spc_player = SomSpcPlayer_Create;
    game.mods_provider = NULL;
    game.after_config = SomMusicInitialize;   /* read msu1.cfg before launch */
    game.on_rom_loaded = NULL;
    game.patch_rom = SomPrepareRom;           /* mods: fanfares IPS, MSU-1 pack */
    game.on_reset = SomMsu1PatchTimelineJumped; /* MSU-1 track after a state load */
    game.before_run_frame = NULL;
    game.after_run_frame = NULL;
    game.keep_pacing_debt = NULL;
    game.prepare_frame = NULL;
    game.begin_sim_frame = NULL;
    game.end_sim_frame = NULL;
    game.draw_frame = NULL;
    game.presentation_hz = NULL;
    game.window_base_width = NULL;
    game.window_base_height = NULL;
    game.compute_viewport = NULL;
    game.aspect_labels = NULL;
    game.num_aspect_labels = 0;
    game.aspect_setting_label = NULL;
    game.aspect_setting_help = NULL;
    game.known_sha1_hex = NULL;
    game.num_known_sha1 = 0;
    game.rewind_settings = 1;
    game.in_game_launcher = 1;
    game.in_game_menu = 1;                    /* Escape / Select+Start */
    game.configure_launcher = NULL;
    game.prepare_netplay = NULL;
    game.netplay_ready = NULL;
    game.on_shutdown = NULL;                  /* host writes SRAM itself */

    return snesrecomp_desktop_main(&game, argc, argv);
}