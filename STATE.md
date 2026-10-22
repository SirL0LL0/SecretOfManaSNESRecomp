# Secret of Mana recomp — stato compatto (context trim)

Aggiornato: 2026-10-22. Repo: `C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp`
(git pulito, unico commit `72aa0b6` — tutto il lavoro di intro/name-entry è **committato**).

## 1. Cosa è già risolto (bug chiusi)

| Sintomo | Causa | Fix (dove) |
|---|---|---|
| Intro accelerata (albero e testo basso comparivano ~troppo presto) | L'IRQ raster veniva eseguito **due volte** (metà CPU + loop di disegno) | `SNESRECOMP_RASTER_JOURNAL=1`: il PPU registra le scritture ai registri display durante la metà CPU e le **riproduce riga per riga**; l'handler guest gira **una sola volta** |
| Freeze su Start alla schermata dell'albero | Il draw-loop re-eseguiva l'handler IRQ e ne duplicava gli effetti | Idem (journal mode) + `run_interrupt()` ora usa `interp_bridge_lle_resume_pc()` **prima** di `last_interrupt_return_pc`/`last_exit_pc` (il task-switch JML fuori da WRAM non torna mai: era questo il freeze) |
| Sprite "spezzati" a metà campo | Il modello a frame esegue tutta la metà CPU prima di disegnare: l'OAM era già quello "late" | Split OAM start/late in `generic_frame_driver.c` (`gfd_capture_oam`/`gfd_restore_oam`) |
| Stallo nella decompressione HDMA dell'intro | Il framework consumava le tabelle HDMA dal beam **prima** del draw-loop | `snes_set_hdma_beam_enabled(false)` + `dma_initHdma`/`dma_primeHdmaFirstLine`/`dma_doHdma` nel draw-loop |
| Rewind/save-state sembrava un hang | `s_resume_pc` è host-state, non faceva parte del blob | `snes_generic_frame_driver_state_loaded()` prende il resume PC dall'interp |

Risultato misurato: **un solo IRQ CPU per frame** (f19–f2099), f1500 identico al riferimento Mesen,
f2100/f2500/f3000/f3500 visivamente identici a `isolate2`.

## 2. Configurazione attuale (default ancora "vecchio")

In `snesrecomp/runner/src/generic_frame_driver.c`:
- `SNESRECOMP_IRQ_REPLAY` → default **1** (replay nel draw-loop, legacy)
- `SNESRECOMP_RASTER_JOURNAL` → default **0** (journal **spento**)
- `SNESRECOMP_TRACE_IRQ` → 0, `SNESRECOMP_IRQ_LOG` → 0
- Diagnostica OAM: `SNESRECOMP_OAM_DUMP_FROM` / `SNESRECOMP_OAM_DUMP_TO` → dump `oam_{start,late,live}_f*.bin`
- Build di produzione: `SNESRECOMP_TRACE=0` → **il debug server e i suoi ring OAM non esistono**; per OAM/ring usare i dump env-gated.

> **Da fare**: quando il fix scelto è definitivo, invertire i default (journal=1) e rimuovere/gateare le diagnostiche.

## 3. Divergenze ancora aperte (verificate adesso)

1. **Name-entry senza ritratto del personaggio e senza cursore blu sulla "A"** (confermato da immagini):
   - riferimento: `work/mesen/tree/ref_name_3410.png` → mostra personaggio + "A" blu
   - recomp: `secret-of-mana-recomp/work/tree/name_shots2/p3410.png` → mancano entrambi
   - ipotesi già esclusa: **non sono sprite OBJ** — le tabelle OAM (start/late/live) sono **vuote** in
     `work/tree/oam_dump/oam_*_f3400-3420.bin`. ⇒ sono grafica BG (tilemap/tile) oppure il trasferimento
     DMA verso `$2102/$2104` non arriva.
   - stato PPU di riferimento a f3410 (`work/mesen/tree/ref_name_layers_3410.txt`):
     `bgMode=5, mainScreenLayers=19, BG1 tm=0x4800 chr=0x4000 h/vscroll=199, BG2 tm=0x5800 chr=0x6000 vscroll=1023,
      oamAddressOffset=4096, oamBaseAddress=16384, hiRes=false, screenInterlace=false`
   - stato PPU recomp a f3410: `bgmode=5, obsel=2, tm=19, bgsc=[72,88], hscroll[0]=199, vscroll[0]=199, vscroll[1]=1023, setini=0, hdmaen_last=0`
     → **BG scroller e vscroll combaciano**: il problema è nei **dati** (tilemap/tile), non nei registri.

   ### Diagnosi 2026-10-22 (confronti byte-per-byte rif/ref a f3410, Start f2500+f3105)
   - **OAM: IDENTICO** al riferimento (128 sprite). Il "reference OAM vuoto" era un falso binario:
     i dump del recomp erano stati presi sulla schermata sbagliata. Gli sprite 0-3 (x=19/33, y=96/104,
     tile 33) = **cursore blu "A"**; gli sprite 4-11 (x=144/152, y=16..40, tile 48-55) = **ritratto**.
     ⇒ il cursore e il ritratto **sono OBJ**, non BG.
   - **Tilemap BG1 (0x4800) e BG2 (0x5800): IDENTICI** al riferimento.
   - **CGRAM: identico** (le 2 differenze sono solo il bit 15 di trasparenza, artefatto di dump Mesen).
   - **VRAM: identico tranne word 0x7000-0x7FFF (byte 0xE000-0xFFFF)**: nel recomp è **tutto ZERO**,
     nel riferimento ci sono ~5 KB di dati. Quella zona = **metà alta del CHR di BG2** (base 0x6000,
     tile 64..191) ⇒ al recomp manca il blocco di grafica caricato per la schermata.
   - **WRAM: mancano interi blocchi** rispetto al riferimento:
     `$E700-$FFFF` → 6379 byte non-nulli nel riferimento, **1 nel recomp** (buffer del decompressore!);
     `$4A00-$7FFF` → 18715 byte diversi (stato di gioco/buffer diversi);
     `$D600+` → **codice 6502 identico** (è il decompressore, già copiato in WRAM).
   - Conclusione: **il recomp non esegue il caricamento della grafica della name-entry**
     (decompressione → WRAM $E700 → DMA a VRAM 0x7000). Non è un problema di renderer/registri:
     OAM, tilemap, CGRAM e registri PPU coincidono.
   - Prossimo passo: trovare **chi invoca** il decompressore (routine a $7E:D600: `LDA #$7F/PHA/PLB`
     → DB=$7F, sorgente $00:xxxx, destinazione $7F:E700) e perché nel recomp non viene chiamata
     (candidato: job/flag in WRAM, budget di cicli per frame, o un IRQ/HDMA che nel reference
     scatta e nel recomp no).
2. **Lead residuo ~3%** (~70 frame): il riferimento mostra i primi pixel verdi dell'albero a f2070, il recomp a f1999.
   Non è l'IRQ duplicato (il journal mode è visivamente identico a isolate2). Rimane da indagare
   il budget cicli/frame del guest o lo stall accounting DMA/HDMA — **oppure accettarlo**.
3. **Freeze su Start** al tempo dell'albero: non riprodotto con Start a f2500 + f3105 (il recomp arriva a
   file-select e name-entry). Manca però il test con pressioni ripetute/alle reali soglie f2100–f2400.
4. **Script di test obsoleti**: `prologue*.script` premano Start a f900 (prima della correzione della timeline).

## 4. Comandi utili

Build:
```
cmd /c 'call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && cd /d "C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp" && cmake --build build --target som_recomp'
```

Run headless (script + env):
```
$env:SDL_VIDEODRIVER="dummy"; $env:SDL_AUDIODRIVER="dummy"; $env:SNESRECOMP_DEBUG_HUD="0"
$env:SNESRECOMP_DUMP_DIR="C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp\work\tree\<out>"
$env:SNESRECOMP_RASTER_JOURNAL="1"     # 0 = legacy replay
build\som_recomp.exe --no-launcher --script build\<file>.script "<rom>"
```
ROM: `C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA) [T-It by Mumble Translation v2.0].sfc`

Mesen (riferimento):
```
Mesen.exe --testRunner --timeout=120 --debug.scriptwindow.allowioosaccess=true "<lua>" "<rom>"
```

## 5. Semantica degli script (trappola ricorrente)

`press X N` = N frame di pressione **+ 1 frame idle** ⇒ i tag dei dump arrivano ~10 frame dopo
il frame nominale. Esempio: `wait 2500 / press start 4 / wait 600 / press start 4 / wait 700`
⇒ secondo Start a f3105, ultimo dump a f3410. Il campo `frame` di `*.regs.json` è il riferimento
autorevole (il tag del file è nominale).

## 6. Prossimi passi (in ordine)

1. Diff BG name-entry: confronto `ref_name_vram.bin` (byte-addressed) vs `s3400.vram.bin` (word LE),
   basi tilemap `0x4800/0x5800` (offset byte `0x9000/0xB000`), basi CHR `0x4000/0x6000`
   (offset byte `0x8000/0xC000`); poi diff CGRAM.
2. Se il diff è nei tile: capire chi deve scriverli (DMA del job "name"?) e perché nel recomp non
   arrivano. Logging DMA verso `$2102/$2104` env-gated se serve.
3. Test pressioni Start a f2100/f2200/f2300/f2400 e Start ripetuti vs `work/mesen/tree/start_ref2`.
4. Verifica banda del prologo sotto journal mode vs `work/prologue/u1.png`, `u3.png`; riverificare
   HDMA ch4-7 e `vscroll` di BG1.
5. Lead residuo ~3%: confrontare budget cicli/frame guest e stall DMA/HDMA.
6. Fissare i default (journal=1), ripulire diagnostiche, rebuild, ri-eseguire i check
   coverage/debug.log (`bsnes_usage_to_tier2.py` / `auto_extend_coverage.py`), sincronizzare la copia
   esterna dei sorgenti.

## 7. Percorsi chiave

- Driver: `secret-of-mana-recomp/snesrecomp/runner/src/generic_frame_driver.c`
- PPU/journal: `secret-of-mana-recomp/snesrecomp/runner/src/snes/ppu.c`, `ppu.h`
- Build: `secret-of-mana-recomp/build/som_recomp.exe`
- Script: `secret-of-mana-recomp/build/*.script`
- Dump recomp: `secret-of-mana-recomp/work/tree/**`  ·  Riferimento Mesen: `SOM/work/mesen/tree/**`
- Riferimento name-entry: `SOM/work/mesen/tree/ref_name_{oam,vram,cgram}.bin`, `ref_name_layers_3410.txt`, `ref_name_3410.png`
- Riferimento doppio Start: `SOM/work/mesen/tree/start_ref2/ref_{2800,3100,3400,3700}.png`
- Baseline prologo: `secret-of-mana-recomp/work/prologue/u1.png`, `u3.png`
