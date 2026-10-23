$ErrorActionPreference = 'Stop'
$appId = 'wordcraft'
$expectedRepository = "ElliottHitch/$appId"
foreach ($name in 'LOCAL_RELEASE_VERSION', 'LOCAL_RELEASE_SOURCE_SHA', 'LOCAL_RELEASE_REPOSITORY') {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) { throw "$name is required." }
}
if ($env:LOCAL_RELEASE_SOURCE_SHA -notmatch '^[0-9a-f]{40}$') { throw 'LOCAL_RELEASE_SOURCE_SHA must be a full commit SHA.' }
if ($env:LOCAL_RELEASE_REPOSITORY -cne $expectedRepository) { throw 'LOCAL_RELEASE_REPOSITORY does not match this app.' }
if ($env:LOCAL_RELEASE_VERSION -notmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw 'LOCAL_RELEASE_VERSION must be numeric X.Y.Z.' }

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$helperCommit = '0334a2d36ad67340f8e9d1ffe6d79c33059ca84e'
$helperSha256 = '4B01A3FA6742A47E26AE35434C35CEDFAE7203887676977C4652E53B530B2483'
$helperName = "local-build-$helperCommit.ps1"
$helperDirectory = Join-Path $sourceRoot 'target\local-release'
$helperPath = Join-Path $helperDirectory $helperName
$temporaryPath = $helperPath + '.download'
& git -C $sourceRoot check-ignore --quiet "target/local-release/$helperName"
if ($LASTEXITCODE -ne 0) { throw 'The helper download path must stay under the ignored target directory.' }
New-Item -ItemType Directory -Force -Path $helperDirectory | Out-Null
$existingHash = if (Test-Path -LiteralPath $helperPath) { (Get-FileHash -Algorithm SHA256 -LiteralPath $helperPath).Hash } else { $null }
if ($existingHash -cne $helperSha256) {
  $helperUrl = "https://raw.githubusercontent.com/ElliottHitch/craft-launcher/$helperCommit/packaging/windows/local-build.ps1"
  Invoke-WebRequest -Uri $helperUrl -OutFile $temporaryPath -Headers @{ 'User-Agent' = "ArtCraft-Launcher/$env:LOCAL_RELEASE_VERSION" }
  $downloadHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $temporaryPath).Hash
  if ($downloadHash -cne $helperSha256) {
    Remove-Item -LiteralPath $temporaryPath -Force
    throw 'The downloaded ArtCraft Launcher build helper failed SHA256 verification.'
  }
  Move-Item -LiteralPath $temporaryPath -Destination $helperPath -Force
}
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $helperPath).Hash
if ($actualHash -cne $helperSha256) { throw 'The cached ArtCraft Launcher build helper failed SHA256 verification.' }
& $helperPath -SourceRoot $sourceRoot -AppId $appId
if (-not $?) { throw 'The local Windows package recipe failed.' }
