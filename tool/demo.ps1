param(
    [string]$Target = 'lib/demo.dart',
    [string]$Output = 'build/web',
    [switch]$NoServe
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$taskSdk = Join-Path (Get-Location) '.tooling/flutter'
$taskOriginals = @{}
try {
    if (Test-Path -LiteralPath $taskSdk) {
        # Work around impellerc's Unicode include-path bug in this portable SDK.
        $taskHeader = [IO.File]::ReadAllText((Join-Path $taskSdk 'bin/cache/artifacts/engine/windows-x64/shader_lib/flutter/runtime_effect.glsl'))
        foreach ($taskRelative in @('material/shaders/ink_sparkle.frag', 'widgets/shaders/stretch_effect.frag')) {
            $taskShader = Join-Path $taskSdk ('packages/flutter/lib/src/' + $taskRelative)
            $taskOriginals[$taskShader] = [IO.File]::ReadAllBytes($taskShader)
            $taskSource = [IO.File]::ReadAllText($taskShader).Replace('#include <flutter/runtime_effect.glsl>', $taskHeader)
            [IO.File]::WriteAllText($taskShader, $taskSource)
        }
        foreach ($taskShaderFile in Get-ChildItem -Path (Join-Path (Get-Location) '.tooling/pub-cache/hosted/pub.dev/material_ui-*/lib/shaders/*.frag')) {
            $taskOriginals[$taskShaderFile.FullName] = [IO.File]::ReadAllBytes($taskShaderFile.FullName)
            [IO.File]::WriteAllText($taskShaderFile.FullName, [IO.File]::ReadAllText($taskShaderFile.FullName).Replace('#include <flutter/runtime_effect.glsl>', $taskHeader))
        }
    }
    $env:NIX_SKIP_SODIUM_BUILD_HOOKS = '1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'flutter.ps1') build web -t $Target --output $Output --no-pub --no-web-resources-cdn --no-wasm-dry-run
    if ($LASTEXITCODE -ne 0) { throw '演示构建失败' }
} finally {
    foreach ($taskShader in $taskOriginals.Keys) {
        [IO.File]::WriteAllBytes($taskShader, $taskOriginals[$taskShader])
    }
}
if ($NoServe) { exit 0 }
& node (Join-Path $PSScriptRoot 'demo-server.mjs')
exit $LASTEXITCODE
