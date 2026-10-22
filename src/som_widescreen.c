/*
 * som_widescreen.c — Mods → Display → Widescreen (som.widescreen).
 *
 * Modelled on Mega Man X's adaptive renderer (github.com/mstan/
 * megamanxsnesrecomp, src/mmx_renderer.c): the PPU keeps rasterising the
 * authentic 256-pixel field, and a title-owned compositor widens it from the
 * game's own data. The view is Adaptive (the window's shape), 16:9 or 21:9;
 * Settings → Display Aspect still decides the pixel shape, exactly as in MMX.
 *
 * Why not the PPU's own widescreen: SoM keeps a 64x32-tile ring per layer in
 * VRAM but only refreshes the band next to the screen, so the columns past
 * the edge hold whatever was there before (the stale forest at the top right
 * of the bridge scene). The whole area is in WRAM instead:
 *
 *   layer  map (128x128 metatile bytes)  metatile table (256 x 4 tile words)
 *   BG1    $7F:0000                      $7F:C000
 *   BG2    $7F:4000                      $7F:C800
 *
 * Each frame the visible metatiles are read back from the VRAM ring, turned
 * into indices through the table, and located in the map; when enough of them
 * agree, the margins are drawn from the map with mode 1's layer order, the
 * frame's colour math and its brightness. A scene that does not match (title,
 * Mode 7, menus, a map being loaded) is pillarboxed instead, and Mode 5/6
 * screens keep their native 512-dot presentation, centred in the same view.
 *
 * Phase 1: backgrounds only. Sprites, BG3 and the HUD stay in the native
 * 256 pixels. Nothing here writes guest state.
 */

#include "som_widescreen.h"

#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "common_rtl.h"
#include "desktop/config.h"
#include "desktop/host_main.h"
#include "mod_runtime.h"
#include "snes/ppu.h"
#include "widescreen.h"

#define SOM_WS_PACKAGE "som.widescreen"
#define SOM_WS_FEATURE "widescreen"
#define SOM_WS_PLUGIN  "som.widescreen"

enum {
    kWsHeight = 224,
    kWsMaxWidth = 1024,           /* kSnesDesktopMaxFrameWidth, MMX's capacity */
    kMapSize = 128,               /* metatiles per map row and column */
    kCellsX = 17, kCellsY = 15,   /* metatiles touching the 256x224 screen */
};

typedef enum SomWsAspect { kAspectAdaptive, kAspect16x9, kAspect21x9 } SomWsAspect;

typedef struct SomWsLayerInfo {
    uint32_t map;                 /* WRAM offset of the 128x128 map */
    uint32_t table;               /* WRAM offset of the 256-entry table */
} SomWsLayerInfo;

static const SomWsLayerInfo kLayers[2] = {
    {0x10000, 0x1C000},           /* BG1 */
    {0x14000, 0x1C800},           /* BG2 */
};

extern Ppu *g_ppu;

static bool s_enabled;
static SomWsAspect s_aspect;
static SnesDisplayFrame s_view = {256, 0, 4.0 / 3.0};
static uint32_t s_out[kWsMaxWidth * kWsHeight];
static int s_out_width;
static bool s_out_wide;           /* the last composed frame had real margins */
static int s_align[2][2] = {{-1, -1}, {-1, -1}};   /* per layer: map cell of ring cell 0,0 */

/* ── Geometry (as MmxRendererViewport / MmxRendererDestination) ─────────── */

static SnesDisplayAspect PixelShape(void) {
    return SnesDisplayAspect_Clamp(g_config.display_aspect);
}

static SnesDisplayFrame ComputeView(int drawable_w, int drawable_h) {
    double aspect = s_aspect == kAspect16x9 ? 16.0 / 9.0 :
                    s_aspect == kAspect21x9 ? 21.0 / 9.0 :
                    drawable_w > 0 && drawable_h > 0 ? (double)drawable_w / drawable_h
                                                     : 16.0 / 9.0;
    return SnesDisplayAspect_ComputeAdaptiveFrame(256, kWsHeight, kWsMaxWidth,
                                                  aspect, PixelShape());
}

static bool HiresField(void) {
    return g_ppu && ((g_ppu->bgmode & 7) == 5 || (g_ppu->bgmode & 7) == 6);
}

void SomWidescreenPrepareFrame(int drawable_w, int drawable_h, int *frame_w, int *frame_h) {
    if (!s_enabled) return;
    s_view = ComputeView(drawable_w, drawable_h);
    /* Mode 5/6 (menus, name entry, the title's text) stays a 256-wide frame so
     * the host can present its 512 dots natively; the viewport below centres
     * it in the same view, pillarboxed. */
    *frame_w = HiresField() ? 256 : s_view.width;
    *frame_h = kWsHeight;
}

void SomWidescreenViewport(int frame_w, int frame_h, int drawable_w, int drawable_h,
                           SnesDisplayViewport *viewport) {
    (void)frame_h;
    if (!s_enabled) return;
    SnesDisplayViewport view = SnesDisplayAspect_FitViewport(s_view.aspect, drawable_w, drawable_h);
    if (view.width <= 0) return;
    /* The host passes the frame's logical width, at its render scale. A frame
     * as wide as the view fills it; anything else is the native 256 field. */
    const bool wide = s_view.width > 256 && frame_w % s_view.width == 0;
    if (!wide && s_view.width > 256) {
        const int w = (int)lround((double)view.width * 256.0 / s_view.width);
        view.x += (view.width - w) / 2;
        view.width = w;
    }
    *viewport = view;
}

static void LoadOptions(void);
static bool FeatureOn(void) {
    return snes_mod_runtime_feature_enabled_c(SOM_WS_PACKAGE, SOM_WS_FEATURE) != 0;
}

int SomWidescreenWindowWidth(int frame_w) {
    /* The window is created before plugins activate: ask the plan directly. */
    if (!s_enabled && !FeatureOn())
        return (frame_w * 5 + 2) / 4;          /* the host's default: 4:3 on 240 lines */
    if (!s_enabled) LoadOptions();
    /* Size the window for the fixed view; Adaptive opens at 16:9. */
    SnesDisplayFrame view = s_aspect == kAspectAdaptive ? ComputeView(16, 9) : ComputeView(0, 0);
    return (int)lround(240.0 * view.aspect);
}

/* ── Reading the scene back ────────────────────────────────────────────── */

static uint16_t VramWord(const uint16_t *vram, unsigned word) { return vram[word & 0x7fff]; }

/* Tile word at tile (tx, ty) of a layer's tilemap, any size. */
static uint16_t RingWord(const uint16_t *vram, int layer, int tx, int ty) {
    const uint8_t sc = g_ppu->bgXsc[layer];
    const bool wide = sc & 1, high = sc & 2;
    unsigned addr = (unsigned)(sc & 0xfc) << 8;
    tx &= wide ? 63 : 31;
    ty &= high ? 63 : 31;
    addr += (unsigned)(ty & 31) * 32 + (unsigned)(tx & 31);
    if (tx >= 32) addr += 0x400;
    if (ty >= 32) addr += wide ? 0x800 : 0x400;
    return VramWord(vram, addr);
}

static uint64_t CellKey(const uint16_t w[4]) {
    return (uint64_t)w[0] | (uint64_t)w[1] << 16 | (uint64_t)w[2] << 32 | (uint64_t)w[3] << 48;
}

/* Open-addressed reverse index of a metatile table: four tile words -> index. */
typedef struct SomWsReverse {
    uint64_t key[512];
    int16_t value[512];
} SomWsReverse;

static void BuildReverse(SomWsReverse *rev, uint32_t table) {
    memset(rev->value, 0xff, sizeof(rev->value));
    for (int i = 0; i < 256; ++i) {
        const uint8_t *e = &g_ram[table + i * 8];
        const uint16_t w[4] = {
            (uint16_t)(e[0] | e[1] << 8), (uint16_t)(e[2] | e[3] << 8),
            (uint16_t)(e[4] | e[5] << 8), (uint16_t)(e[6] | e[7] << 8),
        };
        const uint64_t key = CellKey(w);
        unsigned h = (unsigned)((key * 0x9E3779B97F4A7C15ull) >> 55);
        while (rev->value[h] >= 0 && rev->key[h] != key) h = (h + 1) & 511;
        if (rev->value[h] < 0) { rev->key[h] = key; rev->value[h] = (int16_t)i; }
    }
}

static int Lookup(const SomWsReverse *rev, uint64_t key) {
    unsigned h = (unsigned)((key * 0x9E3779B97F4A7C15ull) >> 55);
    while (rev->value[h] >= 0) {
        if (rev->key[h] == key) return rev->value[h];
        h = (h + 1) & 511;
    }
    return -1;
}

static int FloorDiv16(int v) { return v >= 0 ? v / 16 : -((15 - v) / 16); }

/* Locate the visible metatiles of one layer in its WRAM map. Fills
 * align[0..1] with the map cell shown at the screen's first cell. */
static bool AlignLayer(int layer, int align[2]) {
    const uint16_t *vram = PpuRenderVram(g_ppu);
    const SomWsLayerInfo *info = &kLayers[layer];
    static SomWsReverse rev;
    BuildReverse(&rev, info->table);

    int idx[kCellsY][kCellsX];
    int known = 0, distinct = 0;
    bool seen[256] = {false};
    const int cx0 = g_ppu->hScroll[layer] >> 4, cy0 = g_ppu->vScroll[layer] >> 4;
    for (int j = 0; j < kCellsY; ++j)
        for (int i = 0; i < kCellsX; ++i) {
            const int tx = 2 * (cx0 + i), ty = 2 * (cy0 + j);
            const uint16_t w[4] = {
                RingWord(vram, layer, tx, ty), RingWord(vram, layer, tx + 1, ty),
                RingWord(vram, layer, tx, ty + 1), RingWord(vram, layer, tx + 1, ty + 1),
            };
            idx[j][i] = Lookup(&rev, CellKey(w));
            if (idx[j][i] >= 0) {
                ++known;
                if (!seen[idx[j][i]]) { seen[idx[j][i]] = true; ++distinct; }
            }
        }
    /* An empty or uniform screen proves nothing about where it sits. */
    if (known < 60 || distinct < 6) return false;

    const uint8_t *map = &g_ram[info->map];
    #define SCORE(ox, oy, limit, out) do { \
        int s_ = 0, miss_ = 0; \
        for (int j_ = 0; j_ < kCellsY && miss_ <= (limit); ++j_) { \
            const int y_ = (oy) + j_; \
            if (y_ < 0 || y_ >= kMapSize) { miss_ += kCellsX; continue; } \
            for (int i_ = 0; i_ < kCellsX; ++i_) { \
                const int x_ = (ox) + i_; \
                if (idx[j_][i_] < 0) continue; \
                if (x_ >= 0 && x_ < kMapSize && map[y_ * kMapSize + x_] == idx[j_][i_]) ++s_; \
                else ++miss_; \
            } \
        } \
        (out) = s_; \
    } while (0)

    const int allowed = known / 10;   /* 90% of the known cells must agree */
    int score;
    if (align[0] >= 0) {
        for (int dy = -2; dy <= 2; ++dy)
            for (int dx = -2; dx <= 2; ++dx) {
                SCORE(align[0] + dx, align[1] + dy, allowed, score);
                if (score >= known - allowed) {
                    align[0] += dx; align[1] += dy;
                    return true;
                }
            }
    }
    for (int oy = 0; oy <= kMapSize - kCellsY; ++oy)
        for (int ox = 0; ox <= kMapSize - kCellsX; ++ox) {
            SCORE(ox, oy, allowed, score);
            if (score >= known - allowed) {
                align[0] = ox; align[1] = oy;
                return true;
            }
        }
    #undef SCORE
    align[0] = align[1] = -1;
    return false;
}

/* ── Drawing the margins ───────────────────────────────────────────────── */

typedef struct SomWsLayerDraw {
    bool on;                      /* aligned and on the main or sub screen */
    int align[2];
    int hscroll, vscroll;
    unsigned chr;                 /* CHR base, in VRAM words */
} SomWsLayerDraw;

/* A layer's pixel at screen (sx, y): colour index (0 = transparent) and the
 * tile's priority bit. */
static int LayerPixel(const SomWsLayerDraw *l, int layer, int sx, int y, int *prio) {
    const int wx = sx + (l->hscroll & 15), wy = y + (l->vscroll & 15);
    const int cx = l->align[0] + FloorDiv16(wx), cy = l->align[1] + FloorDiv16(wy);
    if (cx < 0 || cx >= kMapSize || cy < 0 || cy >= kMapSize) return 0;
    const unsigned m = g_ram[kLayers[layer].map + cy * kMapSize + cx];
    const int px16 = wx & 15, py16 = wy & 15;
    const unsigned q = (unsigned)((py16 >> 3) * 2 + (px16 >> 3));
    const uint8_t *e = &g_ram[kLayers[layer].table + m * 8 + q * 2];
    const unsigned t = e[0] | e[1] << 8;
    int px = px16 & 7, py = py16 & 7;
    if (t & 0x4000) px = 7 - px;
    if (t & 0x8000) py = 7 - py;
    const uint16_t *vram = PpuRenderVram(g_ppu);
    const unsigned base = l->chr + (t & 0x3ff) * 16;
    const unsigned p0 = VramWord(vram, base + py), p1 = VramWord(vram, base + 8 + py);
    const int bit = 7 - px;
    const int ci = ((p0 >> bit) & 1) | ((p0 >> (8 + bit)) & 1) << 1 |
                   ((p1 >> bit) & 1) << 2 | ((p1 >> (8 + bit)) & 1) << 3;
    if (!ci) return 0;
    *prio = (t >> 13) & 1;
    return (int)(((t >> 10) & 7) * 16 + ci);
}

/* Topmost BG1/BG2 pixel of a screen (mode 1: BG1 hi, BG2 hi, BG1 lo, BG2 lo).
 * Returns the layer (0/1) or 5 for the backdrop, and its BGR555 colour. */
static int TopPixel(const SomWsLayerDraw l[2], unsigned mask, const int ci[2],
                    const int pr[2], uint16_t *color) {
    static const int kOrder[4][2] = {{0, 1}, {1, 1}, {0, 0}, {1, 0}};
    for (int k = 0; k < 4; ++k) {
        const int layer = kOrder[k][0];
        if (!(mask >> layer & 1) || !l[layer].on || !ci[layer] || pr[layer] != kOrder[k][1])
            continue;
        *color = g_ppu->cgram[ci[layer]];
        return layer;
    }
    *color = g_ppu->cgram[0];
    return 5;
}

static uint16_t ColorMath(uint16_t main, int main_layer, uint16_t sub, int sub_layer) {
    const uint8_t cgadsub = g_ppu->cgadsub, cgwsel = g_ppu->cgwsel;
    if (!(cgadsub >> main_layer & 1)) return main;
    uint16_t other = g_ppu->fixedColor;
    bool half = (cgadsub & 0x40) != 0;
    if ((cgwsel & 2) && sub_layer != 5) other = sub;
    else if (cgwsel & 2) half = false;   /* transparent subscreen: fixed colour, no halving */
    int r = main & 31, g = main >> 5 & 31, b = main >> 10 & 31;
    const int r2 = other & 31, g2 = other >> 5 & 31, b2 = other >> 10 & 31;
    if (cgadsub & 0x80) { r -= r2; g -= g2; b -= b2; }
    else { r += r2; g += g2; b += b2; }
    if (half) { r >>= 1; g >>= 1; b >>= 1; }
    r = r < 0 ? 0 : r > 31 ? 31 : r;
    g = g < 0 ? 0 : g > 31 ? 31 : g;
    b = b < 0 ? 0 : b > 31 ? 31 : b;
    return (uint16_t)(r | g << 5 | b << 10);
}

static uint32_t ToArgb(uint16_t c, unsigned brightness) {
    const unsigned r = c & 31, g = c >> 5 & 31, b = c >> 10 & 31;
    const unsigned r8 = ((r << 3) | (r >> 2)) * brightness / 15;
    const unsigned g8 = ((g << 3) | (g >> 2)) * brightness / 15;
    const unsigned b8 = ((b << 3) | (b >> 2)) * brightness / 15;
    return r8 << 16 | g8 << 8 | b8;
}

static bool DrawMargins(int width, int extra) {
    if (!g_ppu || (g_ppu->inidisp & 0x80) || (g_ppu->bgmode & 7) != 1) return false;
    SomWsLayerDraw l[2];
    bool any = false;
    for (int layer = 0; layer < 2; ++layer) {
        l[layer].on = (g_ppu->screenEnabled[0] | g_ppu->screenEnabled[1]) >> layer & 1;
        l[layer].hscroll = g_ppu->hScroll[layer];
        l[layer].vscroll = g_ppu->vScroll[layer];
        l[layer].chr = (unsigned)((g_ppu->bgTileAdr >> (layer * 4)) & 15) << 12;
        if (l[layer].on) {
            l[layer].on = AlignLayer(layer, s_align[layer]);
            any |= l[layer].on;
        }
        memcpy(l[layer].align, s_align[layer], sizeof(l[layer].align));
    }
    /* BG1 carries the scene's structure; without it there is no frame of
     * reference for the margins. */
    if (!any || !l[0].on) return false;
    const unsigned main_mask = g_ppu->screenEnabled[0], sub_mask = g_ppu->screenEnabled[1];
    const unsigned brightness = g_ppu->inidisp & 15;
    for (int y = 0; y < kWsHeight; ++y) {
        uint32_t *row = s_out + (size_t)y * width;
        for (int x = 0; x < width; ++x) {
            if (x == extra) x = extra + 256;
            if (x >= width) break;
            const int sx = x - extra;
            int ci[2] = {0, 0}, pr[2] = {0, 0};
            for (int layer = 0; layer < 2; ++layer)
                if (l[layer].on) ci[layer] = LayerPixel(&l[layer], layer, sx, y, &pr[layer]);
            uint16_t main_c, sub_c;
            const int main_layer = TopPixel(l, main_mask, ci, pr, &main_c);
            const int sub_layer = TopPixel(l, sub_mask, ci, pr, &sub_c);
            row[x] = ToArgb(ColorMath(main_c, main_layer, sub_c, sub_layer), brightness);
        }
    }
    return true;
}

void SomWidescreenEndFrame(const uint8_t *field, unsigned number) {
    (void)number;
    s_out_width = 0;
    if (!s_enabled || !field) return;
    const int width = s_view.width;
    if (width <= 256 || width > kWsMaxWidth || HiresField()) return;
    /* A fast-forward frame nobody will see: no pixels were drawn either. */
    if (g_ppu_skip_pixels) return;
    /* The host rasterises the native 256 pixels into rows as long as the
     * frame it asked prepare_frame for: the field's stride is that width. */
    const int stride = snesrecomp_desktop_frame_width();
    if (stride != width) return;
    const int extra = (width - 256) / 2;
    s_out_wide = DrawMargins(width, extra);
    if (!s_out_wide)
        memset(s_out, 0, (size_t)width * kWsHeight * sizeof(uint32_t));
    for (int y = 0; y < kWsHeight; ++y)
        memcpy(s_out + (size_t)y * width + extra, field + (size_t)y * stride * 4, 256 * 4);
    s_out_width = width;
}

int SomWidescreenDrawFrame(uint8_t *dst, size_t pitch, const uint8_t *field,
                           int frame_w, int frame_h, double alpha) {
    (void)alpha;
    if (!s_enabled || frame_w <= 256 || frame_h != kWsHeight) return 0;
    if (s_out_width != frame_w) {
        /* The view changed after this frame was composed: pillarbox it. */
        const int extra = (frame_w - 256) / 2;
        memset(s_out, 0, (size_t)frame_w * kWsHeight * sizeof(uint32_t));
        for (int y = 0; y < kWsHeight; ++y)
            memcpy(s_out + (size_t)y * frame_w + extra, field + (size_t)y * frame_w * 4, 256 * 4);
        s_out_width = frame_w;
    }
    RtlWidescreenPresent(dst, pitch, (const uint8_t *)s_out, frame_w, frame_h);
    return 1;
}

/* ── The mod ───────────────────────────────────────────────────────────── */

static void SomWidescreenReset(void) {
    s_enabled = false;
    s_out_width = 0;
    s_align[0][0] = s_align[0][1] = s_align[1][0] = s_align[1][1] = -1;
}

static void LoadOptions(void) {
    char value[32] = "";
    s_aspect = kAspectAdaptive;
    if (snes_mod_runtime_feature_option_value_c(SOM_WS_PACKAGE, SOM_WS_FEATURE, "aspect",
                                                value, sizeof(value))) {
        if (!strcmp(value, "16:9")) s_aspect = kAspect16x9;
        else if (!strcmp(value, "21:9")) s_aspect = kAspect21x9;
    }
}

static void SomWidescreenActivate(void) {
    LoadOptions();
    s_enabled = true;
    fprintf(stderr, "som: widescreen on (%s)\n",
            s_aspect == kAspect16x9 ? "16:9" : s_aspect == kAspect21x9 ? "21:9" : "adaptive");
}

void SomWidescreenRegister(void) {
    snes_mod_register_reset_callback(SomWidescreenReset);
    /* It only draws: the executable vouches for that, so the manifest's
     * presentation_only claim holds. */
    snes_mod_register_presentation_plugin(SOM_WS_PLUGIN, SomWidescreenActivate);
}
