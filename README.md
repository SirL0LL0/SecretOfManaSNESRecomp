# Secret of Mana recompilation project

> **Suspended (2026-10-23).** See [ARCHIVE.md](ARCHIVE.md) for the state, the open waterfall issue and the analysis tools.

This project builds a desktop runner and a headless runner around generated SNESRecomp code.

## Reproducible build

Requirements: CMake 3.20+, Ninja, Git, Python 3, Rust (cargo, for the framework's native analyzer), and a C compiler. `dependencies.lock.json` pins the framework and UI Git commits, the SHA-256 of the recomp-ui patch, and the SDL3 version and archive SHA-256. Checkout paths default to sibling folders `../snesrecomp` and `../snesrecomp/recomp-ui`.

- snesrecomp: [SirL0LL0/snesrecomp](https://github.com/SirL0LL0/snesrecomp), branch `som-upstream-2026-10-23`: upstream mstan/snesrecomp (86c80cb) plus the Secret of Mana framework changes and the launcher's language hooks.
- recomp-ui: upstream mstan/recomp-ui (7c635c6) plus `patches/recomp-ui-som-language.patch` (language selector, translation-file picker, Italian strings), applied by the build scripts.

You provide the ROM: **Secret of Mana (USA)**, SHA-256 `4c15013131351e694e05f22e38bb1b3e4031dedac77ec75abecebe8520d82d5f`. Generate the code from it once, then build:

Windows: `.\tools\generate.ps1 -Rom "path\to\Secret of Mana (USA).sfc"`, then `.\build.ps1`  
macOS/Linux: `python3 ../snesrecomp/snesrecomp_cli.py generate --rom <rom> --cfg-dir config --out-dir generated --no-host-root-scan`, then `sh build.sh`

The build scripts verify the dependency origins and exact revisions, check the recomp-ui patch's SHA-256 and apply it when needed. To use other checkout paths, set `SNESRECOMP_ROOT` and optionally `RECOMP_UI_ROOT`; the checkouts must still match the lock file. Outputs are `build/som_recomp` and `build/som_headless` (with `.exe` on Windows). SDL3 is fetched at the pinned version if no package is installed.

## Languages

The game starts in English with the US ROM alone. The launcher and its menus are in English by default too.

**Settings → Localization** offers Italian through the Mumble Translation (Mumble Team), version 2.01. **The patch is not distributed here**: download it from the official site, [mumble.romhacking.it/som.html](https://mumble.romhacking.it/som.html), and in the launcher choose `Secret of Mana (USA).ips` from the archive (`Translation patch → Browse`). The **Language** selector becomes usable only once that file has been checked (SHA-256 `e5207bc3d79f12ba5d381ac905532736a5fb3ba3759bf1feeeb70e6ea0d13928`). The patch for the European ROM, an older version or another file is refused, with the reason shown under the selector. Choosing **Italiano** also switches the launcher and the in-game menu to Italian.

The patch is applied to the image in memory before `SnesInit` (`src/som_main.c`, `SomApplyLanguage`), and the result is checked against the SHA-256 of the translated image. The ROM on disk is never modified. The choice is stored in config.ini (`[General] Language`, `LanguageFile`).

A single recompiled module serves both languages. The code is generated from the US ROM. Of all the bytes the translation changes, only 10 fall inside recompiled code: the operands of nine `LDX #ptr; JSR $5C2A` instructions in bank C0 that point to the moved text. `config/bankc0.cfg` declares them `live_operand`, so the recompiled code reads them from the image at run time. Everything else the translation moves (text, scripts, graphics, the decompressor) is data. Version 2.01 also corrects the waterfall bridge dialog (`28 00 52`), so the separate fixes package is no longer needed.

## Measure recompilation coverage

After building, run `.\tools\measure_coverage.ps1`. It locates the ROM by the SHA-256 in `src/som_main.c`, runs the deterministic route in `tools/coverage_route.txt`, captures the tier-2 manifest and event journal plus frame/state dumps, and ingests them into Markdown and JSON reports. Each run gets a unique folder under `coverage/runs/`; the ROM is not copied. The current tier-2 ingest reports interpreted instructions/cycles, transfer discoveries, and hot PCs; it does not expose a total AOT/recompiled-work denominator, so it cannot report a meaningful recompiled-work percentage. The checked-in route presses Start and captures the next frame. The IRQ task-switch fix prevents the BRK loop through frame 1165. The PPU changes the intro from Mode 3 at 256×224 to Mode 5 at 512×224 after Start; Mode 5/6 currently use the legacy renderer while the new renderer lacks those modes. The executable and its generated config/save files stay isolated in each run folder.

`generated/` is derived from copyrighted ROM data. Do not redistribute it unless authorized.



## Frame driver

SoM runs on the framework's beam-aligned driver (`snesrecomp/runner/src/beam_frame_driver.c`, wired in `src/som_frame_driver.c`): one host frame is one PPU field cut at V=225, the raster IRQ is taken where it latches, and the field is drawn from the raster journal. Compared against Mesen2 frame by frame, the attract intro, the name-entry screen (portrait and cursor) and the prologue match.

The previous generic driver re-ran the IRQ handler while drawing, which doubled the intro's speed and left black holes in the tree scene; with its raster journal enabled, the NMI's force-blank was recorded mid-field and drew a black band across the prologue. Set `SOM_FRAME_DRIVER=generic` to run the old driver for comparison.

The render walk steps HDMA in line 0's H-blank like hardware does; it used to write the first table entry without stepping the channel, which ran every HDMA table one line late and left a sliver of the next text line above the intro's fade. The CPU half also charges the HDMA stall the walk measured, line by line.

## Hi-res screens and in-game menu

Mode 5 screens (file select, name entry) are presented at their native 512-dot width, fitted to the same 256x224 viewport, so the hi-res font stays sharp; the 256-wide averaged copy is kept only for thumbnails, rewind and frame blending.

Escape, or Select+Start on the pad (`[Controller] MenuGesture` in config.ini), opens recomp-ui's in-game menu over the frozen game: display, filter, volume, save/load state (slots 1-10 = F1-F10), reset, launcher and quit. Changes apply live and are written to config.ini. `SNESRECOMP_MENU_SELFTEST=<frame>` with `SNESRECOMP_MENU_DUMP=<path>` opens it automatically and writes its pages as PPMs.

## Frame pacing and audio

The host clock catches up after short hitches (up to four frames, the size of the audio cushion) instead of dropping the lost time. Audio is produced in guest time, so the dropped time used to drain the cushion every 10-25 seconds and each underflow faded the music out and back in. A longer stall still re-anchors the clock.

## Title screen

The title screen always shows the Japanese image, the whole Mana Tree in the background, where the English release shows a cropped, enlarged and blurry one. This is **Queue**'s title screen image restoration, as shipped in **Tomm**'s Secret of Mana Plus 2.1 ([hackofmana.com](https://hackofmana.com/), romhacking.net hack 8491); the bytes are taken unchanged from that hack and are in `src/som_title_data.c`. `src/som_main.c` (`SomApplyTitle`) writes them into the image in memory before `SnesInit`, in English and in Italian: the operand of the intro's `JML $7EAF0B` at C1:4CF7 is redirected to EF:F800, Queue's routine, which points the intro's WRAM code at the compressed image at EF:C000 and then makes the same jump. The image grows to 3 MB. No compiled code changes: C1:4CE5 and the WRAM intro already run as LLE. The Mumble v2.01 translation does not include this restoration (v2.0 did).

## Mods

**Mods → Music → Restore Unused Fanfares** (off by default) plays the two unused fanfares, for the Sea Hare's Tail and the Moogle Belt. It is Kethinov's patch, version 1.2: `src/som_main.c` writes its three records to the in-memory image before `SnesInit`, at the US offsets or, in Italian, where the translation keeps them, after checking the bytes it replaces. The ROM file on disk is never modified. The change takes effect at the next launch.

**Mods → Cheats → Cheats** (off by default; turn on the feature, then each cheat) offers the codes from Almar's Guides (Pro Action Replay) and RPGClassics (its RAM map, and Galoob's official Game Genie list), with duplicates merged. Only codes that work on recompiled code, with no interpreter, are offered. RAM codes are rewritten after every frame, as a PAR does. Codes that change game data (price tables, the level-16 stat row, two event-script operands) patch the image in memory before `SnesInit`. The event-script operands move with the translated script, so in Italian they are applied at the translation's offsets (v2.01), found by the bytes around them. Codes that change instructions are not offered: the recompiled code carries its instructions in the binary, so they would only work in the interpreter. The table and the reason for each choice are in `src/som_cheats.c`.

Gold, Max Money and the Mana Sword write the game block at $7ECC40, and orbs and Mana powers write $7ECF90. Until a game is running, the game keeps routines at those addresses and runs them from WRAM, so those writes wait until each routine is gone. Writing every frame from power-on had broken that routine and left a black screen before the title menu. Unlimited Gold holds 999,999, the game's maximum, rather than the listed $FFFFFF.

## Save states and fast-forward

A save state now also holds the recompiled CPU's execution state: registers, stack pointer, the interpreter bridge's resume point, and the frame driver's resume PC. Before, a load restored the console's memory but resumed the CPU where the current session was. Loading into the same main loop worked; a state saved in a dialogue froze, and one loaded from the name-entry screen drew garbage. States written before this change still load the old way, so re-save them.

Fast-forward presents frames on a 60 Hz wall-clock cadence. Frames it does not present run their lines without drawing pixels, so the game advances exactly as at normal speed. From a prologue state it runs about 4.5x (271 fps, up from 156) instead of showing every 16th frame.

The input script (`--script`) also accepts `savestate N`.

## Reset

The console reset (Ctrl+R, or Reset in the in-game menu) also resets the frame driver through `RtlGameInfo.hardware_reset`. Before this, the driver kept its resume PC and ran the old main loop against cleared RAM, which left a black screen.

## Launcher debug mode and coverage logs

The desktop launcher exposes an optional, default-off capture switch under **Mods → Developer diagnostics → Coverage Capture**. Turn it on before launching to record interpreted instruction/cycle counts and dynamic transfer discoveries observed during play. Checkpoints are written during play and when the runner exits. The launcher selection is saved with the other mod selections.

Diagnostic builds also keep a bounded PPU/DMA history. The exit report records the video mode, enabled main/subscreen layers, VRAM/CGRAM occupancy, and graphics DMA activity per frame; this helps distinguish a missing renderer path from missing graphics uploads. Set `SOM_ENABLE_DEBUG_COVERAGE=OFF` at configure time to disable the developer diagnostics and this history together.

Each captured session writes a unique manifest (`.json`) and event journal (`.jsonl`) under `coverage/runs/secret-of-mana/` in the project folder. The launcher derives this path from the executable location, so it works when started from `build/`; an explicit `SNESRECOMP_COVERAGE_DIR` environment variable still overrides it. This capture is independent of the automated measurement script above.

## Credits

- SNESRecomp and recomp-ui: mstan and contributors.
- Italian translation: Mumble Translations (Clomax, Mog, _Ombra_), v2.01 — [mumble.romhacking.it](https://mumble.romhacking.it/som.html).
- Title screen image restoration: Queue; taken from Secret of Mana Plus 2.1 by Tomm.
- Restore Unused Fanfares 1.2: Kethinov.
- Cheat codes: Almar's Guides (Pro Action Replay), RPGClassics (RAM map, Galoob Game Genie list).
