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

/* ── Language ──────────────────────────────────────────────────────────────
 *
 * The player brings the original US ROM: that is the game, in English, and
 * the code in this executable was generated from it. Settings -> Localization
 * offers Italiano once the player has chosen the Mumble Translation patch
 * (v2.01, "Secret of Mana (USA).ips", from mumble.romhacking.it/som.html; it
 * is not distributed here). The patch is applied to the ROM in memory before
 * SnesInit and the result must hash as the translated image; the file on
 * disk is never touched.
 *
 * One program serves both images: the translation changes 10 bytes of the
 * recompiled code, the text pointers of C0:5989-5BB9 (LDX #ptr / JSR $5C2A),
 * and config/bankc0.cfg declares them live_operand, so compiled code reads
 * them from whichever image is loaded. */
static const char kSomUsRomSha256[] =
    "4c15013131351e694e05f22e38bb1b3e4031dedac77ec75abecebe8520d82d5f";
/* The US ROM with the v2.01 patch applied. */
static const char kSomItalianImageSha256[] =
    "0a8019cada89a39dda3320b99bcee6e65a7ca3149818e3e860dd6d197a8bf1bf";
/* "Secret of Mana (USA).ips" and "Secret of Mana (Europe) (Rev 1).ips" from
 * itptch_snes_secret-of-mana_v201-rev2.zip. */
static const char kSomItalianPatchSha256[] =
    "e5207bc3d79f12ba5d381ac905532736a5fb3ba3759bf1feeeb70e6ea0d13928";
static const char kSomEuropePatchSha256[] =
    "681b42b57aa743b768728f2a8035a567b57ba858f117e8c12083567d0fa3bc84";

enum { kSomLanguageEnglish = 0, kSomLanguageItalian = 1 };
static const char *const kSomLanguageLabels[] = {"English", "Italiano"};
static const char *const kSomLanguageUiCodes[] = {"en", "it"};

static int s_som_italian;   /* the loaded image is the Italian one */

int SomLanguageItalian(void) { return s_som_italian; }

static void HexDigest(const uint8_t *data, size_t size, char hex[65]) {
    uint8_t digest[32];
    sha256_compute(data, size, digest);
    for (unsigned i = 0; i < 32; ++i) snprintf(hex + 2 * i, 3, "%02x", digest[i]);
}

static uint8_t *SomReadFile(const char *path, size_t *size) {
    FILE *f = path && path[0] ? fopen(path, "rb") : NULL;
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *data = n > 0 && n < 16 * 1024 * 1024 ? (uint8_t *)malloc((size_t)n) : NULL;
    if (data && fread(data, 1, (size_t)n, f) != (size_t)n) { free(data); data = NULL; }
    fclose(f);
    if (data) *size = (size_t)n;
    return data;
}

/* The launcher asks every frame: remember the last file's verdict. */
static int SomLanguageAvailable(int index, const char *file, char *reason, size_t reason_cap) {
    static char cached_path[512];
    static long long cached_size = -1;
    static int cached_ok;
    static char cached_reason[160];
    if (index != kSomLanguageItalian) return 1;
    if (!file || !file[0]) {
        if (reason && reason_cap)
            snprintf(reason, reason_cap,
                     "Italiano needs the Mumble Translation patch v2.01 for the US ROM "
                     "(mumble.romhacking.it/som.html): choose \"Secret of Mana (USA).ips\".");
        return 0;
    }
    FILE *f = fopen(file, "rb");
    long long size = -1;
    if (f) { fseek(f, 0, SEEK_END); size = ftell(f); fclose(f); }
    if (strcmp(cached_path, file) != 0 || cached_size != size) {
        snprintf(cached_path, sizeof(cached_path), "%s", file);
        cached_size = size;
        size_t n = 0;
        uint8_t *data = SomReadFile(file, &n);
        char hex[65] = "";
        if (data) HexDigest(data, n, hex);
        free(data);
        cached_ok = data && strcmp(hex, kSomItalianPatchSha256) == 0;
        if (cached_ok) cached_reason[0] = '\0';
        else if (!data)
            snprintf(cached_reason, sizeof(cached_reason), "The translation patch cannot be read.");
        else if (strcmp(hex, kSomEuropePatchSha256) == 0)
            snprintf(cached_reason, sizeof(cached_reason),
                     "This is the patch for the European release: choose \"Secret of Mana (USA).ips\".");
        else
            snprintf(cached_reason, sizeof(cached_reason),
                     "Not the Mumble Translation patch v2.01 for Secret of Mana (USA).");
    }
    if (!cached_ok && reason && reason_cap) snprintf(reason, reason_cap, "%s", cached_reason);
    return cached_ok;
}

/* Before SnesInit: Italiano applies the player's patch to the US ROM. */
static int SomApplyLanguage(uint8_t **rom, size_t *size, char *error, size_t error_cap) {
    s_som_italian = 0;
    if (snesrecomp_desktop_language() != kSomLanguageItalian) return 1;
    const char *path = snesrecomp_desktop_language_file();
    char reason[160] = "";
    if (!SomLanguageAvailable(kSomLanguageItalian, path, reason, sizeof(reason))) {
        snprintf(error, error_cap, "Italiano: %s", reason);
        return 0;
    }
    size_t ips_size = 0;
    uint8_t *ips = SomReadFile(path, &ips_size);
    if (!ips) {
        snprintf(error, error_cap, "Italiano: cannot read %s", path);
        return 0;
    }
    uint8_t *patched = NULL;
    size_t patched_size = 0;
    RomPatchStatus status = snes_rom_patch_apply(*rom, *size, ips, ips_size,
                                                 16u * 1024u * 1024u, &patched, &patched_size);
    free(ips);
    char hex[65] = "";
    if (status == kRomPatch_Ok && patched) HexDigest(patched, patched_size, hex);
    if (status != kRomPatch_Ok || strcmp(hex, kSomItalianImageSha256) != 0) {
        free(patched);
        snprintf(error, error_cap, "Italiano: the patched ROM is not the expected image (%s)",
                 status != kRomPatch_Ok ? snes_rom_patch_status_text(status) : hex);
        return 0;
    }
    *rom = patched;
    *size = patched_size;
    s_som_italian = 1;
    fprintf(stderr, "som: Italian translation (Mumble v2.01) applied in memory\n");
    return 1;
}

/* Mods page → Graphics → Title Screen Restoration (som.title-restoration):
 * Queue's restoration of the Japanese title image, as shipped in Secret of
 * Mana Plus 2.1 (not distributed here: the player chooses one of its .ips
 * files). Only two ranges of that hack are used. C1:4CF6 is the intro's
 * JML $7EAF0B into the routine it copied to WRAM; the restoration points it
 * at EF:F800, which patches that WRAM code to read the full image from
 * EF:C000 and then makes the same jump. Neither C1:4CE5 nor the WRAM intro
 * is recompiled (both already run as LLE), so no compiled code changes: the
 * image grows to 3 MB and the ranges are copied in. The ranges are identical
 * in all six SoMPlus 2.1 patches, so any of them is accepted. */
#define SOM_TITLE_PACKAGE "som.title-restoration"
#define SOM_TITLE_FEATURE "restore"
#define SOM_TITLE_RESOURCE "somplus"
static const struct { uint32_t from, to; } kSomTitleRanges[] = {
    {0x014CF7, 0x014CFA},   /* JML operand: 7E:AF0B -> EF:F800 */
    {0x2FC000, 0x2FF8A0},   /* EF:C000 compressed image, EF:F800 its routine */
};
static const size_t kSomTitleImageSize = 0x300000;
/* SHA-256 of the two ranges, in order, of the US ROM with any SoMPlus 2.1 patch. */
static const char kSomTitleRangesSha256[] =
    "84dd9f0ddfef1176331709117f6b768cb43a69007766e8e671ade27bebbbd9a2";

static int SomApplyTitle(uint8_t **rom, size_t *size, char *error, size_t error_cap) {
#if SNESRECOMP_ENABLE_MODS
    if (!snes_mod_runtime_feature_enabled_c(SOM_TITLE_PACKAGE, SOM_TITLE_FEATURE)) return 1;
    static const uint8_t kOriginalJump[3] = {0x0B, 0xAF, 0x7E};
    if (*size < 0x014CFA || memcmp(*rom + 0x014CF7, kOriginalJump, 3) != 0) {
        fprintf(stderr, "som: Title Screen Restoration: unexpected bytes at C1:4CF7, skipped\n");
        return 1;
    }
    char path[1024];
    if (!snes_mod_runtime_resource_path_c(SOM_TITLE_PACKAGE, SOM_TITLE_FEATURE,
                                          SOM_TITLE_RESOURCE, path, sizeof(path)) || !path[0]) {
        snprintf(error, error_cap,
                 "Title Screen Restoration: choose the Secret of Mana Plus 2.1 patch on the Mods page");
        return 0;
    }
    size_t ips_size = 0;
    uint8_t *ips = SomReadFile(path, &ips_size);
    if (!ips) {
        snprintf(error, error_cap, "Title Screen Restoration: cannot read %s", path);
        return 0;
    }
    uint8_t *donor = NULL;
    size_t donor_size = 0;
    RomPatchStatus status = snes_rom_patch_apply(*rom, *size, ips, ips_size,
                                                 16u * 1024u * 1024u, &donor, &donor_size);
    free(ips);
    int ok = status == kRomPatch_Ok && donor && donor_size >= kSomTitleImageSize;
    if (ok) {
        size_t total = 0;
        for (size_t i = 0; i < sizeof(kSomTitleRanges) / sizeof(kSomTitleRanges[0]); ++i)
            total += kSomTitleRanges[i].to - kSomTitleRanges[i].from;
        uint8_t *joined = (uint8_t *)malloc(total);
        char hex[65] = "";
        if (joined) {
            size_t at = 0;
            for (size_t i = 0; i < sizeof(kSomTitleRanges) / sizeof(kSomTitleRanges[0]); ++i) {
                const size_t n = kSomTitleRanges[i].to - kSomTitleRanges[i].from;
                memcpy(joined + at, donor + kSomTitleRanges[i].from, n);
                at += n;
            }
            HexDigest(joined, total, hex);
            free(joined);
        }
        ok = strcmp(hex, kSomTitleRangesSha256) == 0;
    }
    uint8_t *grown = ok ? (uint8_t *)malloc(kSomTitleImageSize) : NULL;
    if (!grown) {
        free(donor);
        snprintf(error, error_cap,
                 "Title Screen Restoration: not a Secret of Mana Plus 2.1 patch (%s)",
                 status != kRomPatch_Ok ? snes_rom_patch_status_text(status) : "title data differs");
        return 0;
    }
    memcpy(grown, *rom, *size);
    memset(grown + *size, 0, kSomTitleImageSize - *size);
    for (size_t i = 0; i < sizeof(kSomTitleRanges) / sizeof(kSomTitleRanges[0]); ++i)
        memcpy(grown + kSomTitleRanges[i].from, donor + kSomTitleRanges[i].from,
               kSomTitleRanges[i].to - kSomTitleRanges[i].from);
    grown[0xFFD7] = donor[0xFFD7];            /* header ROM size: 4 MB class */
    free(donor);
    *rom = grown;
    *size = kSomTitleImageSize;
    fprintf(stderr, "som: Title Screen Restoration applied in memory\n");
#else
    (void)rom; (void)size; (void)error; (void)error_cap;
#endif
    return 1;
}

/* patch_rom_ex: the steps that may replace the image. The host frees the
 * buffer it read; an intermediate one made here is freed here. */
static int SomPrepareImage(uint8_t **rom, size_t *size, char *error, size_t error_cap) {
    uint8_t *const loaded = *rom;
    if (!SomApplyLanguage(rom, size, error, error_cap)) return 0;
    uint8_t *const translated = *rom;
    if (!SomApplyTitle(rom, size, error, error_cap)) return 0;
    if (translated != loaded && translated != *rom) free(translated);
    return 1;
}

/* Mods page → Music → Restore Unused Fanfares (som.restore-unused-fanfares):
 * Kethinov's patch 1.2, three records, at their offsets in each image. Every
 * byte is checked before it changes, so a ROM that is not the expected one is
 * left alone rather than half-patched. */
typedef struct SomRomEdit { uint32_t us, it; uint8_t len; uint8_t from[6], to[6]; } SomRomEdit;
static const SomRomEdit kSomFanfares[] = {
    {0x09B923, 0x09A6CA, 1, {0x2F}, {0x30}},                     /* Sea Hare's Tail */
    {0x09CA6E, 0x09B6DF, 2, {0x27, 0xC0}, {0x24, 0x01}},         /* Moogle Belt */
    {0x0A0E44, 0x0A0DE2, 6, {0, 0, 0, 0, 0, 0}, {0x40, 0x01, 0x21, 0x0A, 0xFF, 0x02}},
};

static int SomApplyFanfares(uint8_t *rom, size_t size, char *error, size_t error_cap) {
    (void)error; (void)error_cap;
#if SNESRECOMP_ENABLE_MODS
    if (!snes_mod_runtime_feature_enabled_c("som.restore-unused-fanfares", "restore"))
        return 1;
    const size_t n = sizeof(kSomFanfares) / sizeof(kSomFanfares[0]);
    for (size_t i = 0; i < n; ++i) {
        const SomRomEdit *e = &kSomFanfares[i];
        const uint32_t at = s_som_italian ? e->it : e->us;
        if (at + e->len > size || memcmp(rom + at, e->from, e->len) != 0) {
            fprintf(stderr, "som: Restore Unused Fanfares: unexpected bytes at %06X, skipped\n", at);
            return 1;
        }
    }
    for (size_t i = 0; i < n; ++i) {
        const SomRomEdit *e = &kSomFanfares[i];
        memcpy(rom + (s_som_italian ? e->it : e->us), e->to, e->len);
    }
    fprintf(stderr, "som: Restore Unused Fanfares applied in memory\n");
#else
    (void)rom; (void)size;
#endif
    return 1;
}

/* The mods that act before SnesInit: the fanfares IPS (checked against its
 * digest, so first), the ROM-data cheats, and the MSU-1 pack. */
static int SomPrepareRom(uint8_t *rom, size_t size, char *error, size_t error_cap) {
    if (!SomApplyFanfares(rom, size, error, error_cap)) return 0;
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
    /* The original US release: the code was generated from it. */
    game.expected_sha256_hex = kSomUsRomSha256;
    game.known_sha256_hex = NULL;
    game.num_known_sha256 = 0;
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
    game.patch_rom = SomPrepareRom;           /* mods: fanfares, cheats, MSU-1 pack */
    game.patch_rom_ex = SomPrepareImage;      /* Italiano, then the title restoration */
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
    /* Settings -> Localization: English, or Italiano with the player's
     * translation patch; the launcher and in-game menu follow the choice. */
    game.language_labels = kSomLanguageLabels;
    game.language_ui_codes = kSomLanguageUiCodes;
    game.num_languages = 2;
    game.language_file_label = "Translation patch";
    game.language_file_pattern = "*.ips";
    game.language_available = SomLanguageAvailable;
    game.configure_launcher = NULL;
    game.prepare_netplay = NULL;
    game.netplay_ready = NULL;
    game.on_shutdown = NULL;                  /* host writes SRAM itself */

    return snesrecomp_desktop_main(&game, argc, argv);
}