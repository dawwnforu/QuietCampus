$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localSdk = Join-Path $projectRoot '.tooling\flutter'
$portablePowerShell = Join-Path $projectRoot '.tooling\powershell'
if (Test-Path -LiteralPath (Join-Path $portablePowerShell 'pwsh.exe')) {
    $env:PATH = $portablePowerShell + [IO.Path]::PathSeparator + $env:PATH
}
$androidSdk = Join-Path $projectRoot '.tooling\android-sdk'
if (Test-Path -LiteralPath (Join-Path $androidSdk 'cmdline-tools\latest')) {
    $env:ANDROID_HOME = $androidSdk
    $env:ANDROID_SDK_ROOT = $androidSdk
    $env:ANDROID_USER_HOME = Join-Path $projectRoot '.tooling\android-user'
    $env:GRADLE_USER_HOME = Join-Path $projectRoot '.tooling\gradle'
    New-Item -ItemType Directory -Path $env:ANDROID_USER_HOME, $env:GRADLE_USER_HOME -Force | Out-Null
    $javaRoot = Join-Path $projectRoot '.tooling\java'
    if (!$env:JAVA_HOME -and (Test-Path -LiteralPath $javaRoot)) {
        $jdk = Get-ChildItem -LiteralPath $javaRoot -Directory | Where-Object {
            Test-Path -LiteralPath (Join-Path $_.FullName 'bin\java.exe')
        } | Select-Object -First 1
        if ($jdk) { $env:JAVA_HOME = $jdk.FullName }
    }
    # libsodium's Android build uses bash and the make shipped with the NDK.
    $gitBin = Join-Path $env:ProgramFiles 'Git\bin'
    if (Test-Path -LiteralPath (Join-Path $gitBin 'bash.exe')) {
        $env:PATH = $gitBin + [IO.Path]::PathSeparator + $env:PATH
    }
    $ndkMake = Join-Path $androidSdk 'ndk\28.2.13676358\prebuilt\windows-x86_64\bin'
    if (Test-Path -LiteralPath (Join-Path $ndkMake 'make.exe')) {
        $env:PATH = $ndkMake + [IO.Path]::PathSeparator + $env:PATH
    }
}
if (Test-Path -LiteralPath (Join-Path $localSdk 'bin\cache\flutter_tools.snapshot')) {
    $env:PUB_CACHE = Join-Path $projectRoot '.tooling\pub-cache'
    $env:APPDATA = Join-Path $projectRoot '.tooling\tool-state'
    $env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
    $env:CI = 'true'
    $taskTemp = Join-Path $projectRoot '.tooling\tmp'
    New-Item -ItemType Directory -Path $taskTemp -Force | Out-Null
    $env:TEMP = $taskTemp
    $env:TMP = $taskTemp
    & (Join-Path $localSdk 'bin\cache\dart-sdk\bin\dart.exe') (Join-Path $localSdk 'bin\cache\flutter_tools.snapshot') --suppress-analytics @args
} else {
    & flutter --suppress-analytics @args
}
exit $LASTEXITCODE
