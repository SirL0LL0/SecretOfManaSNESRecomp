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

## 3. Lo stato verificato oggi (confronti byte-per-byte rif/ref a f3410, Start f2500 + f3105)

**La name-entry è corretta**: presentata a 512×224 (hires nativo), il confronto con
`work/mesen/tree/ref_name_3410.png` (512×448, righe pari) dà **0.00 % di pixel diversi**:
ritratto del personaggio, cursore blu sulla "A", riquadri, testo e sfondo combaciano.

> Il "ritratto e cursore mancanti" era un **falso binario**: due cause, nessuna legata al PPU.
> 1. La presentazione a **256** (percorso widescreen / frame-blend: `g_ws_active`, `native_widescreen`,
>    `frame_blend` → `present_w = g_snes_width`) **declassa il campo hires** e perde gli sprite.
> 2. I test colore sbagliati: il framebuffer è **BGRX8888** (`info.json`), il PPM è RGB → R/B scambiati.
> Il dump OAM "vuoto" era un terzo falso binario (dump presi sulla schermata sbagliata).

Differenze **reali** che restano (non incidono sulla name-entry):
- **VRAM**: il riferimento scrive ~5 KB in `0xEC80-0xFFFF` (word `0x7640-0x7FFF`, parte alta del CHR di BG2)
  durante le transizioni (f2600 dopo il primo Start, f3150 dopo il secondo); il **recomp non ci scrive mai**.
  I dati non sono nel ROM e non compaiono da nessun'altra parte nella memoria del recomp.
  Verificato fino a f5010: non è un ritardo. **Effetto visivo: nessuno** (la name-entry è 0,00% diversa).
- **WRAM (mirror valido $0000-$1FFF)**: dove il gioco scrive, i due coincidono, tranne:
  - `$0110`/`$0112` — vettori nativi BRK/ABORT: rif `14 00 / 02 00`, recomp `13 00 / F8 FF`;
  - `$02B3` — rif `B8`, recomp `8A`;
  - `$04C3`/`$04D6`/`$04DE` — differenze di bit (`05/01`, `24/20`, `88/80`);
  - `$0566-$05A0` — un blocco di codice copiato in WRAM **shiftato di 1 byte** e con contenuto leggermente diverso:
    ⇒ il "system code" del gioco (handler NMI + decompressore) viene copiato in WRAM **1 byte più in basso** nel recomp.
  I ~5000 byte "differenti" che sembravano un blocco mancante sono **spazzatura**: Mesen riempie la memoria non
  inizializzata con rumore, il recomp la mette a zero (5030 dei 6118 byte diversi sono "rif≠0 e recomp=0").

### Strumentazione (errori da non ripetere)
- `emu.memType.*` sono **costanti**: l'accesso è `emu.read(addr, memType)`, non `memType(addr)`.
- `emu.getState()` dentro il callback `endFrame` **uccide** il run di Mesen (exit -1, nessun file scritto).
- `emu.read(addr, snesWorkRam)` è **indirizzato per CPU**: solo `$0000-$1FFF` è il mirror WRAM reale
  (HiROM); oltre è ROM. I vecchi dump "WRAM 128 KB" erano spazzatura.
- Il piano dei mod del recomp **non apre** il ROM con `[` `]` nel percorso → usare `sources\rom_test.sfc`
  (SHA-256 identico a quello originale).
- Il recomp ha **due** frame driver: default = `snes_beam_frame_driver` (allineato al fascio, disegna dal
  raster journal), legacy = `snes_generic_frame_driver` (`SOM_FRAME_DRIVER=generic`).
  **Tutte le misure di questa sessione erano sul driver generic+journal**: con il driver default (beam)
  le differenze VRAM/WRAM sono **identiche** ⇒ le divergenze sono nel *guest*, non nel driver.

OAM (128 sprite), tilemap BG1 (`0x4800`) e BG2 (`0x5800`), CGRAM e registri PPU: **identici** al riferimento.

## 4. Lead residuo: **non esiste** (misurato 2026-10-22)

Con il driver **di default** (beam) le due timeline combaciano *esattamente*:

| evento | riferimento (Mesen) | recomp |
|---|---|---|
| l'albero compare (scroll 63) | f2075 | f2075 |
| scroll 62 / 59 / 56 / 53 / 50 | f2400 / 2425 / 2450 / 2475 / 2500 | **stessi frame** |
| dopo il primo Start (mode 5) | scroll 5 a f2625, 12 a f2650, … | scroll 6 a f2630, 13 a f2655, … ⇒ **~1-2 frame indietro** |

⇒ il vecchio "3% di anticipo / 71 frame" era un artefatto: misurato sul driver *generic*+journal
e/o con una soglia sui pixel. **Oggi il recomp è sincrono col riferimento** (name-entry 0,00% diverso).

Resta solo da capire il **ritardo di 1-2 frame** dopo il primo Start (irrilevante per la resa).

## 4b. Caveat d'ambiente (NON sono bug del progetto)

Il sandbox interrompe in modo **intermittente** l'apertura dei file da parte dei processi lanciati:
- il recomp fallisce con `mods: plan rejected: cannot open <rom>` (il piano dei mod legge il ROM per lo SHA-256);
- Mesen muore subito con exit -1 e output vuoto.
Workaround: copiare il ROM in `C:\Users\lollo\AppData\Local\Temp\opencode` e riprovare; spesso il tentativo
successivo va a buon fine. Le cartelle `sources/` sono intatte (i file ci sono).

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

0. **Lingue** (2026-10-23, aggiornato): codice generato dal ROM **USA** (framework upstream 86c80cb +
   modifiche SoM, fork `som-upstream-2026-10-23`). Solo il ROM ⇒ inglese. L'italiano (Mumble v2.01,
   `Secret of Mana (USA).ips`, fornito dall'utente) si attiva da **Impostazioni → Localizzazione**: il
   selettore è abilitato solo dopo che il file è stato verificato (SHA-256). La patch è applicata in
   memoria in `patch_rom_ex` (`SomApplyLanguage`); gli unici 10 byte di codice che cambiano (9 operandi
   `LDX #ptr; JSR $5C2A` in C0) sono `live_operand` in `config/bankc0.cfg`. Launcher e menu in inglese
   per default, in italiano solo con Italiano selezionato. Il pacchetto `som.language` e le
   "translation fixes" sono stati rimossi (la v2.01 corregge già il ponte).
   **Title screen** (2026-10-23): sempre attivo il ripristino dell'immagine giapponese di Queue (da
   Secret of Mana Plus 2.1 di Tomm): `src/som_title_data.c` + `SomApplyTitle`; C1:4CF7 -> EF:F800,
   immagine a 3 MB, nessun codice compilato cambia (C1:4CE5 e l'intro in WRAM sono LLE).
1. **Ritardo di 1-2 frame dopo il primo Start**: piccolo, ma da spiegare (budget cicli del frame? costo
   dei polling in vblank?). La chiave di allineamento è lo scroll BG1 (le due timeline coincidono
   esattamente fino a f2550).
2. Le differenze residue di variabili (`$00F4`, `$02B1`, `$04C3`, `$04D6`, `$04DE`) sono **piccole
   differenze di contatori/indici**: coerenti con il ritardo di 1-2 frame, non con un bug.
3. Il supporto MSU-1 (mod e vecchio player msu1.cfg) è stato rimosso il 2026-10-23 su richiesta dell'utente;
   l'immagine in memoria differisce dal ROM puro solo per il ripristino del titolo (sempre attivo) e i mod scelti.
4. I 5 KB "mancanti" in VRAM `0xEC80-0xFFFF` sono **spazzatura non inizializzata di Mesen** (il gioco li
   azzera in entrambi; nel recomp erano già zero). Nessun upload manca: confermato dal log PPU
   (nessuna scrittura a `$2118/$2119/$2120` in quelle frame).
5. Test Start ripetuti e alle soglie f2100-f2400 (freeze non riprodotto con Start f2500+f3105).
6. Script di test obsoleti: `prologue*.script` premano Start a f900 (prima della correzione della timeline).
7. **Default**: il driver di default è già quello *beam*; valutare se `SNESRECOMP_RASTER_JOURNAL` serve
   ancora (con il beam driver il journal è interno), rimuovere/gateare le diagnostiche, rebuild,
   ri-eseguire i check coverage/`debug.log` (`bsnes_usage_to_tier2.py`, `auto_extend_coverage.py`),
   sincronizzare la copia esterna dei sorgenti (`SOM\snesrecomp`).
8. Push su GitHub: `git push origin main` (vedi §7).

## 7. Percorsi chiavi

- Driver: `secret-of-mana-recomp/snesrecomp/runner/src/generic_frame_driver.c`
- PPU/journal: `secret-of-mana-recomp/snesrecomp/runner/src/snes/ppu.c`, `ppu.h`
- Presentazione (larghezza 256 vs 512): `secret-of-mana-recomp/snesrecomp/runner/src/desktop/host_main.c` (~L1409)
- Build: `secret-of-mana-recomp/build/som_recomp.exe` · Script: `secret-of-mana-recomp/build/*.script`
- Framework: fork SirL0LL0/snesrecomp, branch `som-upstream-2026-10-23` (pin in `dependencies.lock.json`);
  recomp-ui upstream + `patches/recomp-ui-som-language.patch` (applicato da `build.ps1`/`build.sh`)
- Codice generato: `tools/generate.ps1 -Rom <ROM USA>` (non va nel repository)
- Dump recomp: `secret-of-mana-recomp/work/tree/**` · Riferimento Mesen: `SOM/work/mesen/tree/**`
- Riferimento name-entry: `SOM/work/mesen/tree/ref_name_{oam,vram,cgram}.bin`, `ref_name_layers_3410.txt`, `ref_name_3410.png`
- Riferimento doppio Start: `SOM/work/mesen/tree/start_ref2/ref_{2800,3100,3400,3700}.png`
- Script di confronto usati: `SOM/work/tree/cmp_img.py` (PNG vs BMP), `SOM/work/tree/cmp_name.py`,
  `SOM/work/tree/sprite_probe.py`, `SOM/work/tree/check_late.py`
- Baseline prologo: `secret-of-mana-recomp/work/prologue/u1.png`, `u3.png`
