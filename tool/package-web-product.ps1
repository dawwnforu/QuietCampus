param([switch]$UseExistingBuild)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Set-Location $taskRoot
if (!$UseExistingBuild) {
    & (Join-Path $PSScriptRoot 'build-web-product.ps1')
} else {
    $taskMain = Get-Item -LiteralPath 'build/web-product/main.dart.js'
    $taskChanged = Get-ChildItem -LiteralPath 'lib' -File -Recurse | Where-Object { $_.LastWriteTimeUtc -gt $taskMain.LastWriteTimeUtc }
    if ($taskChanged) { throw 'Flutter source changed after this build. Rebuild before packaging.' }
    & (Join-Path $PSScriptRoot 'prepare-web-product.ps1')
}
$taskRuntime = Join-Path $taskRoot '.tooling/web-delivery/node-v24.22.1-win-x64'
if (!(Test-Path -LiteralPath (Join-Path $taskRuntime 'node.exe'))) { throw 'Prepare the official Node v24.22.1 Windows x64 runtime first; see docs/web-delivery.md.' }
$taskRuntimeHash = (Get-FileHash -LiteralPath (Join-Path $taskRuntime 'node.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
if ($taskRuntimeHash -ne 'd702daa815eabbff763c7d3808e235cf031cf2ca70211b56847bc72f51e240e5') { throw 'Node runtime does not match the official release checksum.' }
$taskStamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$taskName = "QuietCampus-Web-Candidate-$taskStamp"
$taskDestination = Join-Path $taskRoot "build/delivery/$taskName"
if (Test-Path -LiteralPath $taskDestination) { throw 'Delivery folder already exists. Keep it; retry with a new timestamp.' }
New-Item -ItemType Directory -Path $taskDestination, (Join-Path $taskDestination 'runtime'), (Join-Path $taskDestination 'docs') -Force | Out-Null
Copy-Item -LiteralPath 'build/web-product' -Destination (Join-Path $taskDestination 'site') -Recurse
Copy-Item -LiteralPath (Join-Path $taskRuntime 'node.exe'), (Join-Path $taskRuntime 'LICENSE') -Destination (Join-Path $taskDestination 'runtime')
Copy-Item -LiteralPath 'tool/demo-server.mjs' -Destination (Join-Path $taskDestination 'serve.mjs')
# A batch file needs CRLF even when source files are checked out with LF.
$taskLauncher = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'web-product/Start-QuietCampus.cmd')).Replace("`r`n", "`n").Replace("`n", "`r`n")
[IO.File]::WriteAllText((Join-Path $taskDestination 'Start-QuietCampus.cmd'), $taskLauncher, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath 'docs/web-delivery.md' -Destination (Join-Path $taskDestination 'START-HERE.md')
Copy-Item -LiteralPath 'docs/web-user-guide.zh-CN.md', 'docs/web-user-guide.en.md', 'docs/web-privacy-draft.md', 'THIRD_PARTY_NOTICES.md' -Destination (Join-Path $taskDestination 'docs')
Copy-Item -LiteralPath 'pubspec.lock', 'pubspec.yaml' -Destination (Join-Path $taskDestination 'docs')
$taskZip = "$taskDestination.zip"
Compress-Archive -LiteralPath $taskDestination -DestinationPath $taskZip -CompressionLevel Optimal
Write-Output "DELIVERY_FOLDER=$taskDestination"
Write-Output "DELIVERY_ZIP=$taskZip"
Write-Output "RUNTIME_NODE_SHA256=$taskRuntimeHash"
