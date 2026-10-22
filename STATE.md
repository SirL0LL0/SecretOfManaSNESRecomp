# Secret of Mana recomp — stato compatto (context trim)

Aggiornato: 2026-10-22. Repo: `C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp`
(git pulito su `main`; tutto il lavoro è committato). Remoto: `https://github.com/SirL0LL0/SecretOfManaSNESRecomp`.

## 1. Bug chiusi

| Sintomo | Causa | Fix |
|---|---|---|
| Intro accelerata (albero/testo comparivano troppo presto) | L'IRQ raster girava **due volte** (metà CPU + draw-loop) | `SNESRECOMP_RASTER_JOURNAL=1`: il PPU **registra** le scritture ai registri display nella metà CPU e le **riproduce riga per riga**; l'handler guest gira una sola volta |
| Freeze su Start | Il draw-loop re-eseguiva l'handler IRQ; inoltre il resume-PC post-task-switch era sbagliato | Journal mode + `run_interrupt()` usa `interp_bridge_lle_resume_pc()` **prima** di `last_interrupt_return_pc`/`last_exit_pc` (il JML fuori da WRAM non ritorna mai: era il freeze) |
| Sprite "spezzati" a metà campo | Il modello a frame esegue tutta la metà CPU prima di disegnare | Split OAM start/late in `generic_frame_driver.c` |
| Stallo nella decompressione HDMA dell'intro | Il framework consumava le tabelle HDMA dal beam prima del draw-loop | `snes_set_hdma_beam_enabled(false)` + `dma_initHdma`/`dma_primeHdmaFirstLine`/`dma_doHdma` nel draw-loop |
| Rewind/save-state sembrava un hang | `s_resume_pc` è host-state, non nel blob | `snes_generic_frame_driver_state_loaded()` prende il resume PC dall'interp |

Misure: **un solo IRQ CPU per frame** (f19–f2099), f1500 identico al riferimento Mesen,
f2100/f2500/f3000/f3500 visivamente identici a `isolate2`.

## 2. Configurazione attuale (i default sono ancora "vecchio")

In `snesrecomp/runner/src/generic_frame_driver.c`:
- `SNESRECOMP_IRQ_REPLAY` → default **1** (replay nel draw-loop, legacy)
- `SNESRECOMP_RASTER_JOURNAL` → default **0** (journal **spento**) ← da invertire quando il fix è definitivo
- `SNESRECOMP_TRACE_IRQ` (1 = trace, 2 = per-slice), `SNESRECOMP_IRQ_LOG`
- Diagnostica: `SNESRECOMP_OAM_DUMP_FROM/_TO` (dump `oam_{start,late,live}_f*.bin`),
  `SNESRECOMP_TRACE_SPR=<frame>` (trace sprite: OAM risolto + word VRAM lette)
- Build di produzione: `SNESRECOMP_TRACE=0` → **il debug server non esiste**; per OAM/PC usare i dump env-gated.

## 3. Stato verificato oggi (confronti byte-per-byte rif/ref a f3410, Start f2500 + f3105)

**La name-entry è corretta**: presentata a 512×224 (hires nativo), il confronto con
`work/mesen/tree/ref_name_3410.png` (512×448, righe pari) dà **0.00 % di pixel diversi**:
ritratto del personaggio, cursore blu sulla "A", riquadri, testo e sfondo combaciano.

> Il "ritratto e cursore mancanti" era un **falso binario**: due cause, nessuna legata al PPU.
> 1. La presentazione a **256** (percorso widescreen / frame-blend: `g_ws_active`, `native_widescreen`,
>    `frame_blend` → `present_w = g_snes_width`) **declassa il campo hires** e perde gli sprite.
> 2. I test colore sbagliati: il framebuffer è **BGRX8888** (`info.json`), il PPM è RGB → R/B scambiati.
> Il dump OAM "vuoto" era un terzo falso binario (dump presi sulla schermata sbagliata).

Differenze **reali** che restano (non incidono sulla name-entry):
- **VRAM**: identica al riferimento tranne word `0x7000-0x7FFF` (byte `0xE000-0xFFFF`): nel recomp è
  **tutto zero**, nel riferimento ci sono ~5 KB. Zona = metà alta del CHR di BG2 (base `0x6000`).
- **WRAM**: `$E700-$FFFF` → 6379 byte non-nulli nel riferimento, **1 nel recomp** (buffer del loader);
  `$4A00-$7FFF` → 18715 byte diversi (stato di gioco/buffer); `$D600+` → **codice 6502 identico**
  (il decompressore è già copiato in WRAM).
- Verificato fino a f5010: nel recomp quei dati **non arrivano mai** (non è un ritardo, il loader non gira).
- ⇒ il riferimento carica un blocco di grafica che il recomp non carica. Candidati: flag di job in WRAM,
  budget di cicli del frame, o un IRQ/HDMA che nel reference scatta e nel recomp no.

OAM (128 sprite), tilemap BG1 (`0x4800`) e BG2 (`0x5800`), CGRAM e registri PPU: **identici** al riferimento.

## 4. Lead residuo ~3% (ancora aperto)

Il riferimento mostra i primi pixel verdi dell'albero a f2070, il recomp a f1999 (~71 frame).
Non è l'IRQ duplicato (journal mode ≡ isolate2). Candidati rimasti: budget cicli/frame del guest,
stall accounting DMA/HDMA, o il costo dei polling in vblank.
Nota: il diff pixel-per-pixel sull'albero/file-select dà 33-40 % di differenze **anche a pochi frame
di scarto**, perché lo sfondo è una texture a piastrelle: serve un riferimento di allineamento
(scroll BG1/HDMA), non un diff grezzo.

## 5. Comandi

Build:
```
cmd /c 'call "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1 && cd /d "C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp" && cmake --build build --target som_recomp'
```
Run headless:
```
$env:SDL_VIDEODRIVER="dummy"; $env:SDL_AUDIODRIVER="dummy"; $env:SNESRECOMP_DEBUG_HUD="0"
$env:SNESRECOMP_RASTER_JOURNAL="1"     # 0 = legacy replay
$env:SNESRECOMP_DUMP_DIR="C:\Users\lollo\Downloads\SOM\secret-of-mana-recomp\work\tree\<out>"
$env:SNESRECOMP_SCREENSHOT_DIR="<out>"  # present_NNNNNN.ppm (512x224 in hires)
build\som_recomp.exe --no-launcher --script build\<file>.script "<rom>"
```
ROM: `C:\Users\lollo\Downloads\SOM\sources\Secret of Mana (USA) [T-It by Mumble Translation v2.0].sfc`

Mesen (riferimento): `C:\Users\lollo\Downloads\SOM\.tools\mesen\app\Mesen.exe`
```
Mesen.exe --testRunner --timeout=180 --debug.scriptwindow.allowioosaccess=true "<lua>" "<rom>"
```

Script: `press X N` = N frame di pressione **+ 1 idle**; i tag dei dump possono essere sfalsati di
~10-25 frame ⇒ il campo `frame` di `*.regs.json` è l'unico affidabile.

## 6. Prossimi passi

1. Capire perché il loader dei ~6 KB non gira nel recomp (WRAM `$E700` resta vuoto): tracciare il
   chiamante del decompressore (`$7E:C18B`, chiamato dalla catena di job nella NMI handler) e i
   suoi parametri (`$7F:00DB`, `$02D6`, `$02E2`).
2. Verificare che il blocco mancante serva dopo (campo di gioco) e non sia innocuo.
3. Lead residuo ~3%: allineamento con riferimento basato su scroll/HDMA, poi budget cicli/stall.
4. Test Start ripetuti e alle soglie f2100-f2400 (freeze non riprodotto con Start f2500+f3105).
5. Script di test obsoleti: `prologue*.script` premano Start a f900 (prima della correzione della timeline).
6. **Default**: invertire `SNESRECOMP_RASTER_JOURNAL` a 1, rimuovere/gateare le diagnostiche, rebuild,
   ri-eseguire i check coverage/`debug.log` (`bsnes_usage_to_tier2.py`, `auto_extend_coverage.py`),
   sincronizzare la copia esterna dei sorgenti (`SOM\snesrecomp`).
7. Push su GitHub: `git push origin main` (vedi §7).

## 7. Percorsi chiave

- Driver: `secret-of-mana-recomp/snesrecomp/runner/src/generic_frame_driver.c`
- PPU/journal: `secret-of-mana-recomp/snesrecomp/runner/src/snes/ppu.c`, `ppu.h`
- Presentazione (larghezza 256 vs 512): `secret-of-mana-recomp/snesrecomp/runner/src/desktop/host_main.c` (~L1409)
- Build: `secret-of-mana-recomp/build/som_recomp.exe` · Script: `secret-of-mana-recomp/build/*.script`
- Dump recomp: `secret-of-mana-recomp/work/tree/**` · Riferimento Mesen: `SOM/work/mesen/tree/**`
- Riferimento name-entry: `SOM/work/mesen/tree/ref_name_{oam,vram,cgram}.bin`, `ref_name_layers_3410.txt`, `ref_name_3410.png`
- Riferimento doppio Start: `SOM/work/mesen/tree/start_ref2/ref_{2800,3100,3400,3700}.png`
- Script di confronto usati: `SOM/work/tree/cmp_img.py` (PNG vs BMP), `SOM/work/tree/cmp_name.py`,
  `SOM/work/tree/sprite_probe.py`, `SOM/work/tree/check_late.py`
- Baseline prologo: `secret-of-mana-recomp/work/prologue/u1.png`, `u3.png`
