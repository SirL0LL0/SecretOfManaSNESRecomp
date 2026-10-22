$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Lock = Get-Content -LiteralPath (Join-Path $Root 'dependencies.lock.json') -Raw | ConvertFrom-Json
$Snes = if ($env:SNESRECOMP_ROOT) { (Resolve-Path -LiteralPath $env:SNESRECOMP_ROOT).Path } else { (Resolve-Path -LiteralPath (Join-Path $Root '..\snesrecomp')).Path }
$Ui = if ($env:RECOMP_UI_ROOT) { (Resolve-Path -LiteralPath $env:RECOMP_UI_ROOT).Path } else { (Resolve-Path -LiteralPath (Join-Path $Snes 'recomp-ui')).Path }
function Assert-Pin($Name, $Path, $Pin) {
  $GitDir = Join-Path $Path '.git'
  if (-not (Test-Path -LiteralPath $GitDir)) { throw "$Name has no .git metadata at $GitDir" }
  $Meta = $GitDir
  $HeadText = (Get-Content -LiteralPath (Join-Path $Meta 'HEAD') -Raw).Trim()
  if ($HeadText.StartsWith('ref: ')) {
    $Ref = $HeadText.Substring(5); $RefFile = Join-Path $Meta ($Ref -replace '/', '\')
    if (Test-Path -LiteralPath $RefFile) { $Head = (Get-Content -LiteralPath $RefFile -Raw).Trim() }
    else {
      $Packed = Get-Content -LiteralPath (Join-Path $Meta 'packed-refs') -ErrorAction SilentlyContinue
      $Match = $Packed | Where-Object { $_ -match ('^([0-9a-f]{40}) ' + [regex]::Escape($Ref) + '$') } | Select-Object -First 1
      if (-not $Match) { throw "$Name ref $Ref not found" }; $Head = $Match.Split(' ')[0]
    }
  } else { $Head = $HeadText }
  if ($Head -ne $Pin.revision) { throw "$Name revision mismatch: expected $($Pin.revision), found $Head at $Path" }
  $Lines = Get-Content -LiteralPath (Join-Path $Meta 'config'); $InOrigin = $false; $Origin = $null
  foreach ($Line in $Lines) {
    if ($Line -match '^\s*\[remote "([^"]+)"\]') { $InOrigin = $Matches[1] -eq 'origin'; continue }
    if ($InOrigin -and $Line -match '^\s*url\s*=\s*(.+?)\s*$') { $Origin = $Matches[1]; break }
  }
  if ($Origin -ne $Pin.repository) { throw "$Name origin mismatch: expected $($Pin.repository), found $Origin at $Path" }
  Write-Host "$Name $Head verified"
}
Assert-Pin 'snesrecomp' $Snes $Lock.dependencies.snesrecomp
Assert-Pin 'recomp-ui' $Ui $Lock.dependencies.'recomp-ui'
$Patch = Join-Path $Root $Lock.framework_patch.file
if (-not (Test-Path -LiteralPath $Patch)) { throw "Framework patch not found: $Patch" }
$PatchSha = (Get-FileHash -LiteralPath $Patch -Algorithm SHA256).Hash.ToLowerInvariant()
if ($PatchSha -ne $Lock.framework_patch.sha256) { throw "Framework patch SHA-256 mismatch: expected $($Lock.framework_patch.sha256), found $PatchSha" }
$FrameDriver = Join-Path $Snes 'runner\src\generic_frame_driver.c'
$FrameSource = Get-Content -LiteralPath $FrameDriver -Raw
if ($FrameSource -notmatch 'interp_bridge_last_interrupt_return_pc') {
  & git -C $Snes apply --check $Patch
  if ($LASTEXITCODE -ne 0) { throw 'Framework patch does not apply cleanly to the pinned SNESRecomp checkout.' }
  & git -C $Snes apply $Patch
  if ($LASTEXITCODE -ne 0) { throw 'Could not apply the SNESRecomp IRQ task-switch patch.' }
  $FrameSource = Get-Content -LiteralPath $FrameDriver -Raw
}
if ($FrameSource -notmatch 'interp_bridge_last_interrupt_return_pc') { throw 'SNESRecomp IRQ task-switch patch is not active.' }
Write-Host "SNESRecomp patch $PatchSha verified and active"
$RendererPatch = Join-Path $Root $Lock.renderer_patch.file
$RendererPatchSha = (Get-FileHash -LiteralPath $RendererPatch -Algorithm SHA256).Hash.ToLowerInvariant()
if ($RendererPatchSha -ne $Lock.renderer_patch.sha256) { throw "Renderer patch SHA-256 mismatch: expected $($Lock.renderer_patch.sha256), found $RendererPatchSha" }
$PpuSourcePath = Join-Path $Snes 'runner\src\snes\ppu.c'
$PpuSource = Get-Content -LiteralPath $PpuSourcePath -Raw
if ($PpuSource -notmatch 'new_renderer_supports_mode') {
  & git -C $Snes apply --check $RendererPatch
  if ($LASTEXITCODE -ne 0) { throw 'Renderer patch does not apply cleanly to the pinned SNESRecomp checkout.' }
  & git -C $Snes apply $RendererPatch
  if ($LASTEXITCODE -ne 0) { throw 'Could not apply the SNESRecomp mode 5 renderer patch.' }
  $PpuSource = Get-Content -LiteralPath $PpuSourcePath -Raw
}
if ($PpuSource -notmatch 'new_renderer_supports_mode') { throw 'SNESRecomp mode 5 renderer fallback is not active.' }
Write-Host "SNESRecomp mode 5 renderer patch $RendererPatchSha verified and active"
$OutputPatch = Join-Path $Root $Lock.mode5_output_patch.file
$OutputPatchSha = (Get-FileHash -LiteralPath $OutputPatch -Algorithm SHA256).Hash.ToLowerInvariant()
if ($OutputPatchSha -ne $Lock.mode5_output_patch.sha256) { throw "Mode 5 output patch SHA-256 mismatch: expected $($Lock.mode5_output_patch.sha256), found $OutputPatchSha" }
$HostSourcePath = Join-Path $Snes 'runner\src\desktop\host_main.c'
$HostSource = Get-Content -LiteralPath $HostSourcePath -Raw
if ($HostSource -notmatch 'g_ppu_render_width') {
  & git -C $Snes apply --check $OutputPatch
  if ($LASTEXITCODE -ne 0) { throw 'Mode 5 output patch does not apply cleanly to the pinned renderer.' }
  & git -C $Snes apply $OutputPatch
  if ($LASTEXITCODE -ne 0) { throw 'Could not apply the Mode 5 logical-output patch.' }
  $HostSource = Get-Content -LiteralPath $HostSourcePath -Raw
}
if ($HostSource -notmatch 'g_ppu_render_width') { throw 'SNES hires rendering does not preserve the logical output width.' }
Write-Host "SNESRecomp Mode 5 logical output patch $OutputPatchSha verified and active"
if (-not $env:INCLUDE -and $env:OS -eq 'Windows_NT') {
  $VsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
  if (Test-Path -LiteralPath $VsWhere) {
    $VsInstall = & $VsWhere -latest -products '*' -property installationPath
    $VsDevCmd = Join-Path $VsInstall 'Common7\Tools\VsDevCmd.bat'
    if (Test-Path -LiteralPath $VsDevCmd) {
      $EnvLines = & cmd.exe /d /c "call `"$VsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
      foreach ($Line in $EnvLines) {
        if ($Line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1],$Matches[2],'Process') }
      }
      if (-not $env:INCLUDE) { throw 'Visual Studio developer environment could not be initialized.' }
    }
  }
}
$Build = Join-Path $Root 'build'
cmake -S $Root -B $Build -G Ninja -DCMAKE_BUILD_TYPE=Release "-DSNESRECOMP_ROOT=$Snes" "-DRECOMP_UI_ROOT=$Ui"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build $Build --config Release --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Built $(Join-Path $Build 'som_recomp.exe') and $(Join-Path $Build 'som_headless.exe')"






