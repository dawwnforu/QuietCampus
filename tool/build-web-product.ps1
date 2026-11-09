$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
if (!(Test-Path -LiteralPath 'web/sodium.js')) {
    throw '缺少已校验的 sodium.js。先运行 dart run sodium:update_web --sumo --no-edit-index --target-directory web'
}
& (Join-Path $PSScriptRoot 'demo.ps1') -Target 'lib/browser.dart' -Output 'build/web-product' -NoServe
if ($LASTEXITCODE -ne 0) { throw '浏览器本地版构建失败' }
$taskIndex = Join-Path (Get-Location) 'build/web-product/index.html'
$taskHtml = [IO.File]::ReadAllText($taskIndex)
$taskHtml = $taskHtml.Replace('静档 · 可操作演示', '静档 · 浏览器本地版').Replace('静档：大学生私人档案交互演示', '静档：浏览器本地记录与完整加密备份；不含云同步')
$taskHtml = $taskHtml.Replace('<script src="flutter_bootstrap.js" async></script>', '<script src="sodium.js"></script><script src="flutter_bootstrap.js" async></script>')
[IO.File]::WriteAllText($taskIndex, $taskHtml, [Text.UTF8Encoding]::new($false))
& (Join-Path $PSScriptRoot 'prepare-web-product.ps1')
Write-Output '已生成 build/web-product。可运行：node tool/demo-server.mjs build/web-product 7360'
