param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('android', 'windows')]
    [string]$Platform,
    [string]$Config = 'config.release.local.json'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = if ([IO.Path]::IsPathRooted($Config)) { $Config } else { Join-Path $projectRoot $Config }
& node (Join-Path $PSScriptRoot 'check-native-release.mjs') $Platform $configPath
if ($LASTEXITCODE -ne 0) { throw 'Release preflight failed; build was not started.' }
Push-Location $projectRoot
try {
    $buildTarget = if ($Platform -eq 'android') { 'apk' } else { 'windows' }
    & (Join-Path $PSScriptRoot 'flutter.ps1') build $buildTarget --release --target lib/main.dart "--dart-define-from-file=$configPath"
    if ($LASTEXITCODE -ne 0) { throw 'Candidate build failed; archived installers were not replaced.' }
    Write-Output 'Build finished. Signing, resources, devices and store admission still require verification.'
} finally {
    Pop-Location
}
