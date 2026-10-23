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
# The Secret of Mana framework changes live on the pinned snesrecomp fork
# commit. recomp-ui is upstream plus one patch: the launcher's language
# selector, translation-file picker and Italian strings.
$Patch = Join-Path $Root $Lock.ui_patch.file
if (-not (Test-Path -LiteralPath $Patch)) { throw "recomp-ui patch not found: $Patch" }
$PatchSha = (Get-FileHash -LiteralPath $Patch -Algorithm SHA256).Hash.ToLowerInvariant()
if ($PatchSha -ne $Lock.ui_patch.sha256) { throw "recomp-ui patch SHA-256 mismatch: expected $($Lock.ui_patch.sha256), found $PatchSha" }
$UiHeader = Join-Path $Ui 'src\recomp_launcher.h'
if ((Get-Content -LiteralPath $UiHeader -Raw) -notmatch $Lock.ui_patch.marker) {
  & git -C $Ui apply --check $Patch
  if ($LASTEXITCODE -ne 0) { throw 'recomp-ui patch does not apply cleanly to the pinned recomp-ui checkout.' }
  & git -C $Ui apply $Patch
  if ($LASTEXITCODE -ne 0) { throw 'Could not apply the Secret of Mana recomp-ui patch.' }
}
if ((Get-Content -LiteralPath $UiHeader -Raw) -notmatch $Lock.ui_patch.marker) { throw 'Secret of Mana recomp-ui patch is not active.' }
Write-Host "recomp-ui patch $PatchSha verified and active"
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






