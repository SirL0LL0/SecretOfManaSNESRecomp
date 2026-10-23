# Project status: suspended (2026-10-23)

The project is suspended as it stands. The owner plays the game in an emulator with IPS patches
instead. This page collects what is needed to pick it up again.

## Where it stands

- Builds from a clean clone: `tools/generate.ps1 -Rom "<Secret of Mana (USA).sfc>"`, then `build.ps1`
  (see README). Pinned dependencies in `dependencies.lock.json`: snesrecomp on the fork
  `SirL0LL0/snesrecomp`, branch `som-upstream-2026-10-23` (upstream mstan 86c80cb + SoM changes),
  recomp-ui upstream 7c635c6 + `patches/recomp-ui-som-language.patch`.
- Code generated from the US ROM; Italian (Mumble v2.01, player-supplied IPS) selectable in the
  launcher; the 10 code bytes the translation moves are `live_operand` in `config/bankc0.cfg`.
- Title screen: Queue's Japanese image restoration, always on (`src/som_title_data.c`).
- Mods: Restore Unused Fanfares, Cheats. MSU-1 support was removed (2026-10-23).
- Only ~330 functions are compiled AOT (`config/symbols.toml` roots); most of the game, including
  the field engine and the NMI handler (C0:Cxxx), runs in the interpreter (LLE).

## Open issue when suspended: waterfalls (Potos falls, after the prologue fall)

Symptom: the three waterfalls stop short; the foam where they meet the water and the translucent
lower part are missing, and the scene looks static. Mesen shows the waterfall translucent down to
the water, the boy half submerged.

Checked, and identical between the recomp and Mesen 2 at that scene (script inputs in
`tools/mesen/wf*.lua`, recomp frame ~10320-10420 = Mesen ~10800):

- PPU state: mode 1 with BG3 priority, TM=$17, TS=$11, CGWSEL=$02, CGADSUB=$42 (BG2, add, halve),
  no windows, no HDMA, same tilemap/CHR bases, same scroll.
- BG1/BG2/BG3 tilemaps are byte-identical; the BG2 tiles differ only by the animation phase.
- The animated-tile system works: table at 7F:8200 (16-byte entries, byte 8 a countdown, byte 0 the
  transfer flag, `$9A` = $80 | count), NMI C0:C14B -> ... -> C0:C337 walks it and DMAs 7F -> VRAM
  (C0:C3CD / C0:C3A2) every 8 frames per entry, as in Mesen.

So the remaining suspect is the PPU renderer (the legacy one is the default): with the same registers
and VRAM it composes BG2-over-BG1 colour math differently. Next step: render the recomp's
`zh*.vram/cgram/oam/regs` dump with `[Graphics] NewRenderer = 1` and compare against Mesen; then
look at the mode 1 colour-math / priority path in `snesrecomp/runner/src/snes/ppu_legacy.c`.

## Tools kept in the repo

`tools/analysis/` (Python 3, run with `python -I`; HiROM, file offset = bank-C0 address):

| Script | Use |
|---|---|
| `ipsdump.py patch.ips [rom]` | list IPS records (also the reader the others import) |
| `patched.py rom patch.ips out` | apply an IPS (test copies only) |
| `ipsbanks.py rom patch.ips [minlen]` | changed bytes per bank, changed regions |
| `ipsinter.py rom a.ips b.ips` | bytes two patches change identically |
| `bothchanged.py rom imgA imgB [skipbanks]` | regions both images change (values may differ) |
| `variantdiff.py rom a.ips b.ips` | where two patches (e.g. difficulty variants) differ |
| `variants.py`, `variants2.py` | build test ROMs with one patch's bytes limited to banks/ranges (bisecting) |
| `cmpblock.py`, `hexat.py` | compare/inspect blocks across ROMs |
| `dis65.py rom BB:AAAA [n] [m=0] [x=0]` | 65816 disassembler |
| `findst.py rom ADDR`, `findcall.py rom BBAAAA` | stores to a register, callers of a routine |
| `vramcmp.py`, `vramdiff2.py` | compare VRAM dumps (regions, tilemaps, tiles) |
| `titlehash.py`, `titlemin.py`, `mktitlec.py` | title restoration extraction (see `src/som_title_data.c`) |
| `packlevels.py`, `pcmpeak.py`, `rawpeak.py`, `limitsim.py` | audio level analysis (MSU-1 work) |

`tools/mesen/`: Lua scripts for Mesen 2's test runner (`Mesen.exe --testRunner --timeout=N
--debug.scriptWindow.allowIoOsAccess=true script.lua rom.sfc`). Paths inside are absolute to the
old workspace; the IO flag is required for them to write files. Notes: name entry refuses an empty
name (press B once), and dialogs need a button press.

Bisecting a patch to find which bytes do what worked well: US ROM + one patch's bytes limited to a
bank or range (`variants2.py`), screenshot each variant in Mesen at the same frame (`shot.lua`).

## What a later session should know

- Never overwrite the original ROMs; test runs rewrite `build/saves/save.srm` on exit, so back it up
  and restore it.
- `generated/` and anything derived from ROM data stay out of git (except `src/som_title_data.c`,
  taken from Secret of Mana Plus 2.1, credited in the README).
- The owner wants recompiled code, not interpreter-only fixes.
