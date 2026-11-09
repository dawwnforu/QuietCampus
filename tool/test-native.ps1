$ErrorActionPreference = 'Stop'
$taskRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$taskTestRoot = [System.IO.Path]::GetFullPath((Join-Path $taskRoot 'test')) + '\'
$taskTests = @($args)
if ($taskTests.Count -eq 0) { throw 'Pass explicit project test/*.dart paths.' }
foreach ($taskTest in $taskTests) {
    $taskTestPath = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $taskTest))
    if (-not $taskTestPath.StartsWith($taskTestRoot, [System.StringComparison]::OrdinalIgnoreCase) -or [System.IO.Path]::GetExtension($taskTestPath) -ne '.dart' -or -not (Test-Path -LiteralPath $taskTestPath -PathType Leaf)) {
        throw 'Only existing project test/*.dart files are accepted.'
    }
}
if (Test-Path -LiteralPath 'Q:\') { throw 'Q: is occupied; do not replace it.' }
$taskOriginalLocation = (Get-Location).Path
$taskSnapshots = @{}
foreach ($taskRelative in @('.dart_tool/package_config.json', '.dart_tool/package_graph.json', '.flutter-plugins-dependencies', 'android/local.properties')) {
    $taskPath = Join-Path $taskRoot $taskRelative
    if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) { throw 'Resolve project dependencies before using this local Windows runner.' }
    $taskSnapshots[$taskPath] = [System.IO.File]::ReadAllBytes($taskPath)
}
$taskPlugins = [System.Text.Encoding]::UTF8.GetString($taskSnapshots[(Join-Path $taskRoot '.flutter-plugins-dependencies')]) | ConvertFrom-Json
$taskAliasRoot = Join-Path $taskRoot '.tooling/windows-workspace'
$taskAppLink = [System.IO.Path]::GetFullPath((Join-Path $taskAliasRoot 'app'))
$taskAliasOwned = $false
$taskAppOwned = $false
$taskExit = 1
try {
    New-Item -ItemType Directory -Path $taskAliasRoot -Force | Out-Null
    if (Test-Path -LiteralPath $taskAppLink) {
        $taskExistingLink = Get-Item -LiteralPath $taskAppLink
        if ($taskExistingLink.LinkType -ne 'Junction' -or $taskExistingLink.Target[0] -ne $taskRoot) { throw 'Do not overwrite an existing app alias.' }
    } else {
        New-Item -ItemType Junction -Path $taskAppLink -Target $taskRoot | Out-Null
        $taskAppOwned = $true
    }
    & subst.exe Q: $taskAliasRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not create temporary project alias.' }
    $taskAliasOwned = $true
    Set-Location Q:/app
    $taskPubLog = Join-Path $taskRoot '.tooling/tmp/native-test-pubget.log'
    New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($taskPubLog)) -Force | Out-Null
    $ErrorActionPreference = 'Continue'
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -File Q:/app/tool/flutter.ps1 pub get --offline *> $taskPubLog
        $taskPubExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = 'Stop' }
    if ($taskPubExit -ne 0 -and -not ([System.IO.File]::ReadAllText($taskPubLog).Contains('Building with plugins requires symlink support'))) { throw 'Dependency preparation failed; see local native-test-pubget.log.' }
    foreach ($taskPlugin in $taskPlugins.plugins.windows) {
        $taskTarget = [System.IO.Path]::GetFullPath($taskPlugin.path)
        if ($taskPlugin.name -notmatch '^[a-z0-9_]+$' -or -not $taskTarget.StartsWith($taskRoot + '\.tooling\pub-cache\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected plugin cache target.' }
        $taskLink = Join-Path $taskRoot ('windows/flutter/ephemeral/.plugin_symlinks/' + $taskPlugin.name)
        if (-not (Test-Path -LiteralPath $taskLink)) { New-Item -ItemType Junction -Path $taskLink -Target $taskTarget | Out-Null }
    }
    & powershell -NoProfile -ExecutionPolicy Bypass -File Q:/app/tool/flutter.ps1 test @taskTests --no-pub --no-test-assets --reporter expanded --concurrency=1
    $taskExit = $LASTEXITCODE
} finally {
    Set-Location -LiteralPath $taskOriginalLocation
    try {
        foreach ($taskPair in $taskSnapshots.GetEnumerator()) { [System.IO.File]::WriteAllBytes($taskPair.Key, $taskPair.Value) }
    } finally {
        if ($taskAliasOwned) { & subst.exe Q: /D }
        if ($taskAppOwned -and $taskAppLink.StartsWith($taskRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            $taskLinkInfo = Get-Item -LiteralPath $taskAppLink -Force
            if ($taskLinkInfo.LinkType -ne 'Junction' -or $taskLinkInfo.Target[0] -ne $taskRoot) { throw 'App alias changed; do not remove it.' }
            [System.IO.Directory]::Delete($taskAppLink, $false)
        }
    }
    Write-Output 'Generated config restored; owned test aliases removed.'
}
exit $taskExit
