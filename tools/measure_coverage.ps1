$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RomSha = ((Select-String -Path (Join-Path $Root 'src\som_main.c') -Pattern '"([0-9a-f]{64})"').Matches | Select-Object -First 1).Groups[1].Value
if (-not $RomSha) { throw 'Expected ROM SHA-256 not found in src/som_main.c' }
$Sources = Join-Path (Split-Path -Parent $Root) 'sources'
$Rom = Get-ChildItem -LiteralPath $Sources -File | Where-Object { $_.Extension -in '.sfc','.smc' -and (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -eq $RomSha } | Select-Object -First 1
if (-not $Rom) { throw "No local ROM in $Sources matches expected SHA-256 $RomSha" }
$Exe = Join-Path $Root 'build\som_recomp.exe'
if (-not (Test-Path -LiteralPath $Exe)) { throw "Build first; executable not found: $Exe" }
$Framework = if ($env:SNESRECOMP_ROOT) { $env:SNESRECOMP_ROOT } else { Join-Path (Split-Path -Parent $Root) 'snesrecomp' }
$Ingest = Join-Path $Framework 'tools\tier2_ingest.py'
if (-not (Test-Path -LiteralPath $Ingest)) { throw "tier2_ingest.py not found at $Ingest" }
$Run = Join-Path $Root (Join-Path 'coverage\runs' (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path (Join-Path $Run 'dumps') -Force | Out-Null
$RunExe = Join-Path $Run 'som_recomp.exe'
Copy-Item -LiteralPath $Exe -Destination $RunExe
$Manifest = Join-Path $Run 'tier2-manifest.json'; $Journal = Join-Path $Run 'tier2-journal.jsonl'
$Dump = Join-Path $Run 'dumps'; $Stdout = Join-Path $Run 'runner.stdout.log'; $Stderr = Join-Path $Run 'runner.stderr.log'
$Names = 'SNESRECOMP_TIER2_CAPTURE','SNESRECOMP_TIER2_MANIFEST','SNESRECOMP_TIER2_JOURNAL','SNESRECOMP_DUMP_DIR','RUN_FRAMES','SDL_VIDEODRIVER','SDL_AUDIODRIVER'
$Old = @{}; foreach ($Name in $Names) { $Old[$Name] = [Environment]::GetEnvironmentVariable($Name,'Process') }
try {
  $env:SNESRECOMP_TIER2_CAPTURE='on'; $env:SNESRECOMP_TIER2_MANIFEST=$Manifest; $env:SNESRECOMP_TIER2_JOURNAL=$Journal
  $env:SNESRECOMP_DUMP_DIR=$Dump; $env:RUN_FRAMES='1250'; $env:SDL_VIDEODRIVER='dummy'; $env:SDL_AUDIODRIVER='dummy'
  $Route = Join-Path $Root 'tools\coverage_route.txt'
  $Args = @('--no-launcher','--rom',('"' + $Rom.FullName + '"'),'--coverage-capture=on','--script',('"' + $Route + '"'))
  $Process = Start-Process -FilePath $RunExe -ArgumentList $Args -WorkingDirectory $Run -Wait -PassThru -NoNewWindow -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr
  $RunnerCode = $Process.ExitCode
} finally { foreach ($Name in $Names) { [Environment]::SetEnvironmentVariable($Name,$Old[$Name],'Process') } }
if ($RunnerCode -ne 0) { throw "Runner exited with code $RunnerCode; see $Stderr" }
if (-not (Test-Path $Manifest) -and -not (Test-Path $Journal)) { throw "No tier-2 capture produced; see $Stderr" }
$Py = Get-Command py -ErrorAction SilentlyContinue
if ($Py) { $PyArgs = @('-3',$Ingest) } else { $Py = Get-Command python -ErrorAction Stop; $PyArgs = @($Ingest) }
$Audit = Join-Path $Run 'coverage-audit.json'; $IngestLog = Join-Path $Run 'ingest.log'
$More = @($Manifest,$Journal,'--cfg-dir',(Join-Path $Root 'config'),'--program-manifest',(Join-Path $Root 'generated\program_manifest.json'),'--rom-sha256',$RomSha,'--json')
& $Py.Source @($PyArgs + $More) 1> $IngestLog 2>&1
if ($LASTEXITCODE -ne 0) { throw "Coverage ingest failed; see $IngestLog" }
Copy-Item -LiteralPath $IngestLog -Destination $Audit -Force
$AuditData = Get-Content -LiteralPath $Audit -Raw | ConvertFrom-Json
$UniqueVariants = @($AuditData.discoveries | ForEach-Object { $_.variant } | Sort-Object -Unique).Count
$FrameLine = Select-String -Path $Stderr -Pattern 'simulations=(\d+)' | Select-Object -Last 1
$Frames = if ($FrameLine -and $FrameLine.Matches[0].Groups[1].Value) { $FrameLine.Matches[0].Groups[1].Value } else { 'n/a' }
$HotRows = @($AuditData.hot_instructions | Select-Object -First 5 | ForEach-Object { "| $($_.target_pc24) | $($_.entry_mx) | $($_.interpreted_instructions) | $($_.guest_cycles) |" })
$Report = @(
  '# Secret of Mana recompilation coverage', '',
  "- Session folder: $(Split-Path -Leaf $Run)", ("- ROM: {0} (SHA-256 {1})" -f $Rom.Name,$RomSha),
  '- Route: `tools/coverage_route.txt` (intro + Start + post-Start gameplay)',
  "- Simulated frames: $Frames", "- Interpreted: $($AuditData.interpreted_instructions) instructions; $($AuditData.interpreted_guest_cycles) guest cycles",
  "- Transfer discoveries: $($AuditData.discoveries.Count) rows / $UniqueVariants unique PC+M/X variants",
  ("- Capture warnings: {0} — {1}" -f $AuditData.warnings.Count,($AuditData.warnings -join '; ')),
  '- Scope limitation: the current tier-2 ingest reports interpreted work and discoveries, not a total AOT/recompiled instruction denominator, so this run cannot be expressed as a recompiled-work percentage.',
  '- Capture files: `tier2-manifest.json`, `tier2-journal.jsonl`, `coverage-audit.json`',
  '- Frame/state snapshot: `dumps/intro.fb.bmp` and `dumps/after_start.fb.bmp` plus WRAM, VRAM, registers and audio traces.', '',
  '## Hottest interpreted instruction sites', '',
  '| PC | Entry M/X | Instructions | Guest cycles |', '|---|---:|---:|---:|'
) + $HotRows + @('', 'The executable runs from this session folder so its config and save files stay isolated from the normal `build/` directory. Review `runner.stderr.log` for diagnostics and capture warnings.')
$Report | Set-Content -LiteralPath (Join-Path $Run 'REPORT.md') -Encoding utf8
Write-Host "Coverage artifacts: $Run"




