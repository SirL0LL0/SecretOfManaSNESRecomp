/*
 * som_headless_main.c — Secret of Mana headless test entry point.
 * Skips the launcher entirely for automated testing.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

#include "common_cpu_infra.h"
#include "common_rtl.h"
#include "program_module.h"
#include "cpu_state.h"
#include "som_frame_driver.h"
#include "snes/snes.h"
#include "snes/ppu.h"

/* som_cheats.c asks which image it patches; the headless runner never
 * applies the translation. */
int SomLanguageItalian(void) { return 0; }

static uint8_t *g_rom_data = NULL;
static int g_rom_size = 0;
static const char *g_rom_path = NULL;

static bool load_rom_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return false;
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size < 32 * 1024) { fclose(f); return false; }
    uint8_t *buf = (uint8_t *)malloc((size_t)size);
    if (!buf) { fclose(f); return false; }
    if (fread(buf, 1, (size_t)size, f) != (size_t)size) { free(buf); fclose(f); return false; }
    fclose(f);
    g_rom_data = buf;
    g_rom_size = (int)size;
    return true;
}

static void free_rom(void) {
    if (g_rom_data) { free(g_rom_data); g_rom_data = NULL; g_rom_size = 0; }
}

static bool som_init_snes(void) {
    if (!g_rom_data) return false;
    /* SnesInit already performs the cold boot: game initialize hook,
     * snes_reset(hard), native-mode CPU state. A second RtlReset(0) here
     * resets the machine a second time, which is what used to send the
     * guest off the rails into the $00:FFFF BRK vector after ~80 frames.
     * Match the desktop host: SnesInit, then read battery SRAM. */
    Snes *snes = SnesInit(g_rom_data, g_rom_size);
    if (!snes) return false;
    RtlReadSram();
    return true;
}

int main(int argc, char **argv) {
    const char *rom_path = NULL;
    int frames = -1;
    int save_state_slot = -1;
    int load_state_slot = -1;
    const char *state_dir = NULL;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--rom") == 0 && i + 1 < argc) {
            g_rom_path = argv[++i];
        } else if (strcmp(argv[i], "--frames") == 0 && i + 1 < argc) {
            frames = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--save-state") == 0 && i + 1 < argc) {
            save_state_slot = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--load-state") == 0 && i + 1 < argc) {
            load_state_slot = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--save-state-dir") == 0 && i + 1 < argc) {
            state_dir = argv[++i];
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            printf("Usage: %s [--rom <path.sfc>] [--frames N] [--save-state N] [--load-state N] [--save-state-dir DIR]\n", argv[0]);
            printf("  --rom PATH          ROM file (required)\n");
            printf("  --frames N          Number of frames to run (default: infinite, max 3600)\n");
            printf("  --save-state N      Save state to slot N (0-9) after running\n");
            printf("  --load-state N      Load state from slot N (0-9) before running\n");
            printf("  --save-state-dir D  Directory for save states (default: saves/)\n");
            printf("  --help, -h          Show this help\n");
            return 0;
        }
    }

    if (!g_rom_path) {
        fprintf(stderr, "som: --rom is required\n");
        return 1;
    }

    if (!load_rom_file(g_rom_path)) {
        return 1;
    }

    if (state_dir) {
        RtlSetSaveRoot(state_dir);
    }

    RtlRegisterGame(som_frame_driver_game_info("secret-of-mana"));
    if (!som_init_snes()) {
        fprintf(stderr, "Failed to initialize SNES runtime\n");
        return 1;
    }

    const RtlGameInfo *game_info = som_frame_driver_game_info("secret-of-mana");
    if (!game_info || !game_info->run_frame) {
        fprintf(stderr, "Generic frame driver unavailable\n");
        return 1;
    }

    if (load_state_slot >= 0 && load_state_slot <= 9) {
        fprintf(stderr, "[som] Loading save state from slot %d...\n", load_state_slot);
        RtlSaveLoad(2, load_state_slot);  // kSaveLoad_Load = 2
    }

    /* The desktop host arms this before its main loop. Without it the APU
     * guest clock clamps at one frame's worth of master cycles, so an SPC
     * upload/ack that runs past the budget (the title-screen NMI handler)
     * can never advance the SPC to the echo the guest is polling for. */
    RtlEnableExtendedFrameTiming();

    fprintf(stderr, "[som] Starting headless frame loop...\n");
    /* The desktop presenter arms the PPU with a field buffer before the first
     * frame; ppu_runLine() draws into that buffer and dereferences NULL
     * without it. 256x4 ARGB, 224 visible lines (+ overscan). */
    static uint8_t s_ppu_pixels[256 * 4 * 240];
    if (game_info->draw_ppu_frame)
        PpuBeginDrawing(g_ppu, s_ppu_pixels, 256 * 4, kPpuRenderFlags_NewRenderer);
    int frame = 0;
    while (frames < 0 || frame < frames) {
        RtlRunFrame(0);
        /* The desktop host rasterises the field after every simulated frame;
         * that is also what advances the PPU (vPos/vTimer, raster IRQ latch)
         * and services mid-frame IRQs. A headless loop that skips it leaves
         * the PPU frozen, so a guest routine that polls the raster or waits
         * on a PPU-latched flag spins until the 5 s watchdog. */
        if (game_info->draw_ppu_frame) game_info->draw_ppu_frame();
        frame++;
        if (frame % 60 == 0) {
            fprintf(stderr, "Frame %d\n", frame);
        }
        if (frame >= 3600) break;
    }

    fprintf(stderr, "[som] finished %d frames\n", frame);

    if (save_state_slot >= 0 && save_state_slot <= 9) {
        fprintf(stderr, "[som] Saving state to slot %d...\n", save_state_slot);
        RtlSaveLoad(1, save_state_slot);  // kSaveLoad_Save = 1
    }

    fprintf(stderr, "[som] Writing SRAM... (g_sram=%p, g_sram_size=%d)\n", g_sram, g_sram_size);
    int result = RtlWriteSram();
    fprintf(stderr, "[som] RtlWriteSram returned: %d\n", result);
    return 0;
}

/* ── Stubs ────────────────────────────────────────── */

void RtlApuLock(void) {}
void RtlApuUnlock(void) {}

#include <stdarg.h>
void host_report_breadcrumb(const char *fmt, ...) { (void)fmt; }

#include "spc_player.h"
SpcPlayer *g_spc_player = NULL;

void debug_on_wram_write_byte(uint32_t addr, uint8_t old_val, uint8_t new_val) { (void)addr; (void)old_val; (void)new_val; }
void debug_on_wram_write_word(uint32_t addr, uint16_t old_val, uint16_t new_val) { (void)addr; (void)old_val; (void)new_val; }
void Die(const char *msg) { (void)msg; abort(); }
void debug_on_block_enter(uint32_t pc24) { (void)pc24; }
