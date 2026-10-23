/*
 * som_cheats.c — Mods → Cheats → Cheats (mods/preloaded/packages/som.cheats).
 *
 * Codes from Almar's Guides (Pro Action Replay) and RPGClassics (its RAM map
 * and Galoob's official Game Genie list), duplicates merged. Only codes the
 * recompiled game honours without the interpreter are here:
 *
 *   - WRAM codes, written again after every frame as the PAR does;
 *   - ROM codes that change DATA the game reads at run time (price tables,
 *     the level-up stat table, event-script operands), applied to the
 *     in-memory image before SnesInit.
 *
 * ROM codes that change instructions are left out (starting gold, starting at
 * level 16, free inns and shops by branch, "protection from most hits", the
 * level-up and treasure codes): recompiled code carries its instructions in
 * the binary, so a changed opcode or operand would only take effect in the
 * interpreter. The codes target the US game. The price and stat tables sit at
 * the same offsets in the Italian translation; the event-script operands
 * moved with the translated script and are given at their Italian offsets,
 * found by the bytes that surround them.
 *
 * Each cheat is a boolean option of the "cheats" feature; the option ids
 * below are the manifest's.
 */

#include "som_cheats.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "common_rtl.h"
#include "mod_runtime.h"

#define SOM_CHEATS_PACKAGE "som.cheats"
#define SOM_CHEATS_FEATURE "cheats"
#define SOM_CHEATS_PLUGIN  "som.cheats"

typedef struct SomPoke {
    uint32_t addr;   /* WRAM offset ($7E0000-based), or ROM file offset */
    uint8_t value;
    uint32_t it;     /* ROM offset in the Italian image when it moved (0 = same) */
} SomPoke;

/* WRAM a game uses for something else until a game is running: see
 * RegionLive. */
typedef enum SomGuard {
    kGuardNone,
    kGuardCC,        /* $7ECC40-$7ECC7F: inventory, sword, gold */
    kGuardCF,        /* $7ECF90-$7ECFBF: mana powers, weapon orbs */
} SomGuard;

typedef enum SomKind {
    kKindWram,       /* poke WRAM after every frame */
    kKindRom,        /* poke the ROM image before SnesInit */
    kKindFullHp,     /* current HP := max HP for the party, every frame */
} SomKind;

typedef struct SomCheat {
    const char *option;
    SomKind kind;
    SomGuard guard;
    size_t count;
    SomPoke pokes[16];
} SomCheat;

static const SomCheat kCheats[] = {
    /* RPGClassics' map: current HP $E182, max HP $E184 (16-bit) for the Hero,
     * Girl and Sprite at $E000/$E200/$E400. Replaces Almar's 7EE18271, which
     * pinned only the low byte, at 113 -- above a starting max of 59. */
    {"unlimited_hp", kKindFullHp, kGuardNone, 0, {{0}}},
    /* 7EE38663 (also listed as "Girl's MP 99 and Unlimited") */
    {"girl_mp", kKindWram, kGuardNone, 1, {{0xE386, 0x63}}},
    /* 7EE58663 */
    {"sprite_mp", kKindWram, kGuardNone, 1, {{0xE586, 0x63}}},
    /* 7EE19100 */
    {"no_status", kKindWram, kGuardNone, 1, {{0xE191, 0x00}}},
    /* 7EE00BFF 7EE20BFF 7EE40BFF */
    {"walk_through_walls", kKindWram, kGuardNone, 3,
     {{0xE00B, 0xFF}, {0xE20B, 0xFF}, {0xE40B, 0xFF}}},
    /* 7EE3C488 7EE3C588 7EE3C688 7EE3C708 */
    {"girl_elementals", kKindWram, kGuardNone, 4,
     {{0xE3C4, 0x88}, {0xE3C5, 0x88}, {0xE3C6, 0x88}, {0xE3C7, 0x08}}},
    /* 7EE5C488 7EE5C588 7EE5C688 7EE5C780 */
    {"sprite_elementals", kKindWram, kGuardNone, 4,
     {{0xE5C4, 0x88}, {0xE5C5, 0x88}, {0xE5C6, 0x88}, {0xE5C7, 0x80}}},
    /* 7EE1ED00 7EE3ED00 7EE5ED00 (Almar lists the Hero's alone as "Always
     * strike enemies at full power") */
    {"full_power", kKindWram, kGuardNone, 3,
     {{0xE1ED, 0x00}, {0xE3ED, 0x00}, {0xE5ED, 0x00}}},
    /* 7EE01A2C */
    {"instant_charge", kKindWram, kGuardNone, 1, {{0xE01A, 0x2C}}},
    /* 7EE198FF 7EE398FF 7EE598FF */
    {"max_attacks", kKindWram, kGuardNone, 3,
     {{0xE198, 0xFF}, {0xE398, 0xFF}, {0xE598, 0xFF}}},
    /* 7EE98200 7EE98300 7EEB8200 7EEB8300 7EE78200 7EE78300 */
    {"one_shot", kKindWram, kGuardNone, 6,
     {{0xE982, 0x00}, {0xE983, 0x00}, {0xEB82, 0x00}, {0xEB83, 0x00},
      {0xE782, 0x00}, {0xE783, 0x00}}},
    /* 7EE77BE7 7E00F46E */
    {"sword_strength", kKindWram, kGuardNone, 2, {{0xE77B, 0xE7}, {0x00F4, 0x6E}}},
    /* 7EE1D163: the Hero's sword experience at 99 */
    {"sword_level", kKindWram, kGuardNone, 1, {{0xE1D1, 0x63}}},
    /* 7EE1C0-C3, 7EE3C0-C3, 7EE5C0-C3 = 88: two weapons per byte, level 8 */
    {"weapon_levels", kKindWram, kGuardNone, 12,
     {{0xE1C0, 0x88}, {0xE1C1, 0x88}, {0xE1C2, 0x88}, {0xE1C3, 0x88},
      {0xE3C0, 0x88}, {0xE3C1, 0x88}, {0xE3C2, 0x88}, {0xE3C3, 0x88},
      {0xE5C0, 0x88}, {0xE5C1, 0x88}, {0xE5C2, 0x88}, {0xE5C3, 0x88}}},
    /* 7ECFB0-B7 (orbs forged) and 7ECFB8-BF (orbs held) = 08: nine each */
    {"all_orbs", kKindWram, kGuardCF, 16,
     {{0xCFB0, 0x08}, {0xCFB1, 0x08}, {0xCFB2, 0x08}, {0xCFB3, 0x08},
      {0xCFB4, 0x08}, {0xCFB5, 0x08}, {0xCFB6, 0x08}, {0xCFB7, 0x08},
      {0xCFB8, 0x08}, {0xCFB9, 0x08}, {0xCFBA, 0x08}, {0xCFBB, 0x08},
      {0xCFBC, 0x08}, {0xCFBD, 0x08}, {0xCFBE, 0x08}, {0xCFBF, 0x08}}},
    /* 7ECF9001 ... 7ECF9701 */
    {"mana_powers", kKindWram, kGuardCF, 8,
     {{0xCF90, 0x01}, {0xCF91, 0x01}, {0xCF92, 0x01}, {0xCF93, 0x01},
      {0xCF94, 0x01}, {0xCF95, 0x01}, {0xCF96, 0x01}, {0xCF97, 0x01}}},
    /* 7ECC5548 */
    {"mana_sword", kKindWram, kGuardCC, 1, {{0xCC55, 0x48}}},
    /* 7ECC6CBF */
    {"max_money", kKindWram, kGuardCC, 1, {{0xCC6C, 0xBF}}},
    /* 7ECC6AFF 7ECC6BFF 7ECC6CFF would be 16,777,215 GP, past the six-digit
     * counter; this holds the game's own maximum, 999,999 ($0F423F). */
    {"unlimited_gold", kKindWram, kGuardCC, 3,
     {{0xCC6A, 0x3F}, {0xCC6B, 0x42}, {0xCC6C, 0x0F}}},
    /* PAR D8FB9C00 D8FB9E00 D8FBA000 D8FBA200 D8FBA300 D8FBA400 D8FBA600 =
     * Game Genie DDEB-E544 DDEB-E5C4 DDEC-E044 DDEC-E0C4 DDEC-E034
     * DDEC-E944 DDEC-E9C4: the 16-bit prices at D8:FB9C (Candy 10,
     * Chocolate 30, Royal Jam 100, Faerie Walnut 500, Medical Herb 10, Cup
     * of Wishes 150). */
    {"free_consumables", kKindRom, kGuardNone, 7,
     {{0x18FB9C, 0x00}, {0x18FB9E, 0x00}, {0x18FBA0, 0x00}, {0x18FBA2, 0x00},
      {0x18FBA3, 0x00}, {0x18FBA4, 0x00}, {0x18FBA6, 0x00}}},
    /* Game Genie DDE3-E044 DDE8-E9C4 DDE8-E144 DDE8-E1C4 DDE7-7047: Overalls,
     * Bandanna, Hair Ribbon, Rabite Cap, Wristband (prices under 256) */
    {"free_starter_gear", kKindRom, kGuardNone, 5,
     {{0x18FBE0, 0x00}, {0x18FBB6, 0x00}, {0x18FBB8, 0x00}, {0x18FBBA, 0x00},
      {0x18FC30, 0x00}}},
    /* Game Genie DDAB-E715 (C9:CF9D): the inn price operand 30 in the event
     * script, at 09BBBF in the translation (Mumble v2.01). */
    {"neko_inn_free", kKindRom, kGuardNone, 1, {{0x09CF9D, 0x00, 0x09BBBF}}},
    /* Game Genie 9C06-81AD 9C06-85DD 9C06-850D 9C06-856D 9C06-85AD: the
     * level-16 row of the stat table at D0:428B */
    {"level16_stats", kKindRom, kGuardNone, 5,
     {{0x10428B, 0x5A}, {0x10428C, 0x5A}, {0x10428D, 0x5A}, {0x10428E, 0x5A},
      {0x10428F, 0x5A}}},
    /* Game Genie EE6B-8738 = PAR CA8E9FFF (0A8E9F): the chest's gold
     * operand, at 0A85E1 in the translation. */
    {"elder_chest_gold", kKindRom, kGuardNone, 1, {{0x0A8E9F, 0xFF, 0x0A85E1}}},
    /* PAR CA8EAFFE (0A8EAF), at 0A85F1 in the translation */
    {"elder_chest_repeat", kKindRom, kGuardNone, 1, {{0x0A8EAF, 0xFE, 0x0A85F1}}},
};

enum { kCheatCount = sizeof(kCheats) / sizeof(kCheats[0]) };

static bool s_on[kCheatCount];

static bool OptionOn(const char *option) {
    char value[16];
    return snes_mod_runtime_feature_enabled_c(SOM_CHEATS_PACKAGE, SOM_CHEATS_FEATURE) &&
           snes_mod_runtime_feature_option_value_c(SOM_CHEATS_PACKAGE, SOM_CHEATS_FEATURE,
                                                   option, value, sizeof(value)) &&
           strcmp(value, "true") == 0;
}

/* $7ECC40-$7ECC7F and $7ECF90-$7ECFBF hold the game in progress only once a
 * game is running. Until then the game has routines copied there and runs
 * them from WRAM ($CC43 through the intro, $CF90 through the title menu too);
 * writing gold or the sword into the first changed its instructions
 * (PLD -> PHA, ORA -> SBC) and the game went black before the title menu.
 * Guarded writes wait until the routine is gone. */
static bool RegionLive(SomGuard guard) {
    static const uint8_t kRoutineCC[] = {
        0x0B, 0x08, 0xC2, 0x30, 0xE2, 0x20, 0x8B, 0xA9, 0x7F, 0x48, 0xAB,
    };
    static const uint8_t kRoutineCF[] = {
        0x07, 0x00, 0xA9, 0x03, 0x9D, 0x04, 0x00, 0xC2, 0x20, 0xA3, 0x01, 0x9D,
    };
    switch (guard) {
    case kGuardCC: return memcmp(&g_ram[0xCC43], kRoutineCC, sizeof(kRoutineCC)) != 0;
    case kGuardCF: return memcmp(&g_ram[0xCF90], kRoutineCF, sizeof(kRoutineCF)) != 0;
    default: return true;
    }
}

/* The PAR's per-frame write. */
static void SomCheatsFrame(void) {
    const bool live_cc = RegionLive(kGuardCC), live_cf = RegionLive(kGuardCF);
    for (size_t i = 0; i < kCheatCount; ++i) {
        const SomCheat *cheat = &kCheats[i];
        if (!s_on[i] || cheat->kind == kKindRom) continue;
        if ((cheat->guard == kGuardCC && !live_cc) || (cheat->guard == kGuardCF && !live_cf))
            continue;
        if (cheat->kind == kKindFullHp) {
            for (uint32_t base = 0xE000; base <= 0xE400; base += 0x200) {
                g_ram[base + 0x182] = g_ram[base + 0x184];
                g_ram[base + 0x183] = g_ram[base + 0x185];
            }
            continue;
        }
        for (size_t k = 0; k < cheat->count; ++k)
            g_ram[cheat->pokes[k].addr] = cheat->pokes[k].value;
    }
}

static void SomCheatsActivate(void) {
    bool any = false;
    for (size_t i = 0; i < kCheatCount; ++i) {
        s_on[i] = OptionOn(kCheats[i].option);
        if (s_on[i] && kCheats[i].kind != kKindRom) {
            any = true;
            fprintf(stderr, "som: cheat %s on\n", kCheats[i].option);
        }
    }
    if (any) snes_mod_register_frame_callback(SomCheatsFrame);
}

void SomCheatsRegister(void) {
    snes_mod_register_activation_plugin(SOM_CHEATS_PLUGIN, SomCheatsActivate);
}

int SomCheatsPatchRom(uint8_t *rom, size_t size, char *error, size_t error_cap) {
    (void)error; (void)error_cap;
    int italian = SomLanguageItalian();
    for (size_t i = 0; i < kCheatCount; ++i) {
        if (kCheats[i].kind != kKindRom || !OptionOn(kCheats[i].option)) continue;
        for (size_t k = 0; k < kCheats[i].count; ++k) {
            const SomPoke *p = &kCheats[i].pokes[k];
            uint32_t addr = (italian && p->it) ? p->it : p->addr;
            if (addr < size) rom[addr] = p->value;
        }
        fprintf(stderr, "som: cheat %s applied in memory\n", kCheats[i].option);
    }
    return 1;
}
