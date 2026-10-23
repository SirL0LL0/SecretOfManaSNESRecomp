param(
  [Parameter(Mandatory = $true)][string]$Rom,
  [string]$OutDir
)
# Generates generated/ from your own Secret of Mana (USA) ROM. The generated
# C is derived from the ROM, so it is not in the repository. Run once before
# build.ps1, and again after changing config/.
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Snes = if ($env:SNESRECOMP_ROOT) { (Resolve-Path -LiteralPath $env:SNESRECOMP_ROOT).Path } else { (Resolve-Path -LiteralPath (Join-Path $Root '..\snesrecomp')).Path }
if (-not $OutDir) { $OutDir = Join-Path $Root 'generated' }
$UsSha256 = '4c15013131351e694e05f22e38bb1b3e4031dedac77ec75abecebe8520d82d5f'
$Sha = (Get-FileHash -LiteralPath $Rom -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Sha -ne $UsSha256) { throw "Not the Secret of Mana (USA) ROM: SHA-256 $Sha, expected $UsSha256" }
# The generator reports progress on stderr, which Windows PowerShell would
# otherwise turn into a terminating error.
$ErrorActionPreference = 'Continue'
& python (Join-Path $Snes 'snesrecomp_cli.py') generate --rom $Rom --cfg-dir (Join-Path $Root 'config') --out-dir $OutDir --no-host-root-scan --expected-sha256 $UsSha256
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Generated $OutDir"
