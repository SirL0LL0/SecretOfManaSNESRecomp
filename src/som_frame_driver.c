#include "som_frame_driver.h"

#include <stdlib.h>
#include <string.h>

#include "beam_frame_driver.h"
#include "common_rtl.h"
#include "snes/saveload.h"
#include "generic_frame_driver.h"
#include "snes/interp_bridge.h"
#include "snes/ppu.h"

extern Ppu *g_ppu;

typedef struct SomPpuRenderRestore {
    uint8_t registers[PPU_SAVESTATE_REGS_SIZE];
    uint8_t scrollPrev;
    uint8_t scrollPrev2;
    uint8_t m7prev;
    uint8_t oamAdr;
    bool oamInHigh;
    bool oamSecondWrite;
    uint8_t oamBuffer;
} SomPpuRenderRestore;

static void som_draw_ppu_frame(void) {
    SomPpuRenderRestore state;

    if (!g_ppu) {
        snes_generic_frame_driver_draw_ppu_frame();
        return;
    }

    /* The generic frame model executes raster IRQs while drawing the field.
     * Keep their per-scanline PPU register writes from becoming the CPU's
     * starting register state for the following frame. */
    memcpy(state.registers, &g_ppu->inidisp, sizeof(state.registers));
    state.scrollPrev = g_ppu->scrollPrev;
    state.scrollPrev2 = g_ppu->scrollPrev2;
    state.m7prev = g_ppu->m7prev;
    state.oamAdr = g_ppu->oamAdr;
    state.oamInHigh = g_ppu->oamInHigh;
    state.oamSecondWrite = g_ppu->oamSecondWrite;
    state.oamBuffer = g_ppu->oamBuffer;

    snes_generic_frame_driver_draw_ppu_frame();

    memcpy(&g_ppu->inidisp, state.registers, sizeof(state.registers));
    g_ppu->scrollPrev = state.scrollPrev;
    g_ppu->scrollPrev2 = state.scrollPrev2;
    g_ppu->m7prev = state.m7prev;
    g_ppu->oamAdr = state.oamAdr;
    g_ppu->oamInHigh = state.oamInHigh;
    g_ppu->oamSecondWrite = state.oamSecondWrite;
    g_ppu->oamBuffer = state.oamBuffer;
}

/* SoM runs on the beam-aligned driver: one host frame is one PPU field, cut
 * at V=225, with the raster IRQ taken where it latches and the field drawn
 * from the raster journal.
 *
 * The generic driver got the intro wrong in two ways. By default it re-ran
 * the IRQ handler during the draw walk, and that handler advances the intro's
 * script and background decompression, so the whole attract sequence played
 * at twice the speed and the tree scene streamed in with black holes. With
 * the raster journal instead, the guest's early WAI left the beam mid-field
 * and the next NMI's force-blank was journaled at line ~150, cutting a black
 * band through every prologue scene. Measured against Mesen2, this driver
 * matches the intro, the name-entry screen (portrait and cursor included) and
 * the prologue.
 *
 * SOM_FRAME_DRIVER=generic restores the old driver for comparison. */
/* Save states. The guest blob (WRAM, VRAM, APU...) does not hold the
 * recompiled CPU's own state -- registers, stack pointer, the interpreter
 * bridge's resume point -- nor the driver's resume PC. Without them a load
 * resumed the restored machine at the PC and stack of the session it
 * replaced: loading from the intro into a field scene happened to work (both
 * idle in the same main loop), but a state saved in a dialogue froze, and one
 * loaded from the name-entry screen drew garbage. This chunk carries both;
 * states written before it load as they always did. */
#define SOM_EXEC_MAGIC   0x58454D53u   /* "SMEX" */
#define SOM_EXEC_VERSION 1u

typedef struct SomExecHeader {
    uint32_t magic;
    uint32_t version;
    uint32_t resume_pc;
    uint8_t wai_halted;
    uint8_t pad[3];
} SomExecHeader;

static bool s_exec_loaded;
static SomExecHeader s_exec_header;

static void som_state_save_extra(SaveLoadInfo *sli) {
    SomExecHeader h;
    bool wai = false;
    memset(&h, 0, sizeof(h));
    h.magic = SOM_EXEC_MAGIC;
    h.version = SOM_EXEC_VERSION;
    snes_beam_frame_driver_get_resume(&h.resume_pc, &wai);
    h.wai_halted = wai ? 1 : 0;
    sli->func(sli, &h, sizeof(h));
    RtlSaveExecutionState(sli);
}

static void som_state_load_extra(SaveLoadInfo *sli, uint32_t version) {
    (void)version;
    s_exec_loaded = false;
    memset(&s_exec_header, 0, sizeof(s_exec_header));
    sli->func(sli, &s_exec_header, sizeof(s_exec_header));
    if (s_exec_header.magic != SOM_EXEC_MAGIC || s_exec_header.version != SOM_EXEC_VERSION)
        return;
    s_exec_loaded = RtlLoadExecutionState(sli);
}

/* Put the saved CPU back before the driver picks its resume point. */
static bool som_apply_exec_state(void) {
    const bool loaded = s_exec_loaded;
    s_exec_loaded = false;
    if (loaded) RtlApplyExecutionState();
    return loaded;
}

static void som_generic_state_loaded(uint32_t version) {
    (void)version;
    som_apply_exec_state();
    snes_generic_frame_driver_state_loaded();
}

static void som_beam_state_loaded(uint32_t version) {
    (void)version;
    const bool exact = som_apply_exec_state();
    snes_beam_frame_driver_state_loaded();
    if (exact)
        snes_beam_frame_driver_set_resume(s_exec_header.resume_pc,
                                          s_exec_header.wai_halted != 0);
}

/* Console reset (the menu's Reset, Ctrl+R). RtlReset resets the hardware but
 * only this hook reaches the driver: without it the driver kept its resume PC
 * and ran the old main loop against cleared RAM, a black screen that never
 * recovered. Boot from the reset vector again, with no resume PC left over in
 * the bridge for the first frame to pick up, and no journal from the field
 * that was cut short. */
static void som_beam_hardware_reset(void) {
    snes_beam_frame_driver_reset();
    interp_bridge_clear_lle_resume_pc();
    ppu_rasterReset();
}

static void som_generic_hardware_reset(void) {
    snes_generic_frame_driver_reset();
    interp_bridge_clear_lle_resume_pc();
}

const RtlGameInfo *som_frame_driver_game_info(const char *title) {
    static RtlGameInfo game_info;
    const char *driver = getenv("SOM_FRAME_DRIVER");
    memset(&game_info, 0, sizeof(game_info));
    game_info.title = title && title[0] ? title : "secret-of-mana";
    game_info.save_name_prefix = "save";
    game_info.state_save_extra = som_state_save_extra;
    game_info.state_load_extra = som_state_load_extra;
    if (driver && strcmp(driver, "generic") == 0) {
        game_info.run_frame = snes_generic_frame_driver_run_frame;
        game_info.draw_ppu_frame = som_draw_ppu_frame;
        game_info.session_reset = snes_generic_frame_driver_reset;
        game_info.hardware_reset = som_generic_hardware_reset;
        game_info.on_state_loaded = som_generic_state_loaded;
        return &game_info;
    }
    game_info.run_frame = snes_beam_frame_driver_run_frame;
    game_info.draw_ppu_frame = snes_beam_frame_driver_draw_ppu_frame;
    game_info.session_reset = snes_beam_frame_driver_reset;
    game_info.hardware_reset = som_beam_hardware_reset;
    game_info.on_state_loaded = som_beam_state_loaded;
    return &game_info;
}
