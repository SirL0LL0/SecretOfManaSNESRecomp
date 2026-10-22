# Secret of Mana recompilation project

This project builds a desktop runner and a headless runner around generated SNESRecomp code.

## Reproducible build

Requirements: CMake 3.20+, Ninja, Git, Python 3, and a C compiler. `dependencies.lock.json` pins the framework and UI Git commits, the SHA-256 hashes of the Secret of Mana IRQ task-switch and Mode 5 renderer patches, and the pinned SDL3 version and archive SHA-256. Checkout paths default to sibling folders `../snesrecomp` and `../snesrecomp/recomp-ui`.

Windows: `.\build.ps1`  
macOS/Linux: `sh build.sh`

Both scripts verify the dependency origins and exact revisions, apply the checked-in framework patches when needed, and verify their SHA-256 hashes before building. To use other checkout paths, set `SNESRECOMP_ROOT` and optionally `RECOMP_UI_ROOT`; the checkouts must still match the lock file. Outputs are `build/som_recomp` and `build/som_headless` (with `.exe` on Windows). SDL3 is fetched at the pinned version if no package is installed.

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

## Mods

**Mods → Music → Restore Unused Fanfares** (off by default) plays the two unused fanfares, for the Sea Hare's Tail and the Moogle Belt. It is Kethinov's patch, version 1.2, with its three records moved to where the Italian translation keeps them. The package is in `mods/preloaded/packages/som.restore-unused-fanfares/`. When the mod is enabled, `src/som_main.c` applies its IPS to the in-memory image before `SnesInit` and checks the result against the SHA-256 in the manifest. The ROM file on disk is never modified. The change takes effect at the next launch.

**Mods → Music → MSU-1 Music** (off by default) plays CD-quality music from DarkShock's Secret of Mana MSU-1 hack v1.0. Choose the music pack folder, the one holding `som_msu1-0.pcm` through `som_msu1-58.pcm`, on the mod's row. The hack's assembly patches recompiled code: the music routine at C3:0004, the reset path, and the NMI vector. It also puts its code at CB:3400, where the Italian translation keeps its credits text. So its bytes are not applied. `src/som_msu1_patch.c` is the same logic in C, routine for routine. The build links it in place of the recompiled `bank_C3_0004_M1X0` at that routine's call sites, and when the hack would fall through, the recompiled original runs. Nothing goes through the interpreter. A track missing from the pack falls back to the SPC, as in the hack. After a save-state load, the track the game was playing is restarted.

**Mods → Cheats → Cheats** (off by default; turn on the feature, then each cheat) offers the codes from Almar's Guides (Pro Action Replay) and RPGClassics (its RAM map, and Galoob's official Game Genie list), with duplicates merged. Only codes that work on recompiled code, with no interpreter, are offered. RAM codes are rewritten after every frame, as a PAR does. Codes that change game data (price tables, the level-16 stat row, two event-script operands) patch the image in memory before `SnesInit`. The event-script operands moved with the translated script, so they are applied at their Italian offsets, found by the bytes around them. Codes that change instructions are not offered: the recompiled code carries its instructions in the binary, so they would only work in the interpreter. The table and the reason for each choice are in `src/som_cheats.c`.

Gold, Max Money and the Mana Sword write the game block at $7ECC40, and orbs and Mana powers write $7ECF90. Until a game is running, the game keeps routines at those addresses and runs them from WRAM, so those writes wait until each routine is gone. Writing every frame from power-on had broken that routine and left a black screen before the title menu. Unlimited Gold holds 999,999, the game's maximum, rather than the listed $FFFFFF.

**Mods → Translation → Italian translation fixes** (on by default) corrects bytes of the translated event script in memory. So far it fixes one byte. On the waterfall bridge in the prologue, Timothy's "Dev'essere una specie di tesoro!" was printed outside the text box and then in a borderless box. The translation ended the previous two-line box with `28 00 51`, which closes the box, instead of `28 00 52`, which clears it and continues. With the fix the scene matches the US release, checked in Mesen. A scan of the script for the same pattern found no other case.

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
