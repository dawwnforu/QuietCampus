param([string]$Output = 'build/web-product')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskOutput = [IO.Path]::GetFullPath((Join-Path $taskRoot $Output))
if (!(Test-Path -LiteralPath (Join-Path $taskOutput 'index.html'))) { throw 'Build the Flutter browser edition first.' }
foreach ($taskName in @('welcome.html', 'portal.css', 'portal.js', 'rabbit.svg', '_headers')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "web-product/$taskName") -Destination $taskOutput
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'web-product/fonts') -Destination $taskOutput -Recurse -Force
Copy-Item -LiteralPath (Join-Path $taskRoot 'assets/fonts/NotoSansSC-LICENSE.txt'), (Join-Path $taskRoot 'assets/fonts/LXGWWenKaiLite-LICENSE.txt') -Destination (Join-Path $taskOutput 'fonts')

function Write-Guide([string]$Source, [string]$Filename, [string]$Language, [string]$Title) {
    $taskBody = (ConvertFrom-Markdown -LiteralPath (Join-Path $taskRoot $Source)).Html
    $taskBody = $taskBody.Replace('web-user-guide.en.md', 'guide.en.html').Replace('web-user-guide.zh-CN.md', 'guide.zh-CN.html')
    $taskBack = if ($Language -eq 'en') { 'Back to welcome' } else { '返回体验首页' }
    $taskHtml = @"
<!doctype html><html lang="$Language"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>$Title</title><link rel="stylesheet" href="portal.css"></head><body><header class="nav wrap"><a class="brand" href="welcome.html"><img src="rabbit.svg" alt="" width="42" height="46">Quiet Campus</a><a href="welcome.html">$taskBack</a></header><main class="wrap"><article class="guide">$taskBody</article></main></body></html>
"@
    [IO.File]::WriteAllText((Join-Path $taskOutput $Filename), $taskHtml, [Text.UTF8Encoding]::new($false))
}
Write-Guide 'docs/web-user-guide.zh-CN.md' 'guide.zh-CN.html' 'zh-CN' '静档 · 使用说明'
Write-Guide 'docs/web-user-guide.en.md' 'guide.en.html' 'en' 'Quiet Campus · User guide'
Write-Guide 'docs/web-privacy-draft.md' 'privacy.html' 'zh-CN' '静档 · 本地数据说明草案 / Local data notes'
$taskRelease = [ordered]@{
    product = 'Quiet Campus'; edition = 'browser-local'; status = 'local-review-candidate';
    candidate = 'web-local-20261026.2'; sourceVersion = '0.2.1+3';
    author = 'DAwwN'; intendedOperatingRegion = 'Mainland China; exact entity and province pending';
    entry = 'welcome.html'; archiveEntry = 'index.html'; demoQuery = '?demo=1';
    storage = 'encrypted IndexedDB, bound to browser profile and origin';
    cloudSync = $false; onlineAI = $false; automaticBackup = $false;
    archiveLimitMiB = 64; attachmentLimitMiB = 20; recordEnvelopeLimitMiB = 2;
    source = 'Original Quiet Campus Flutter project, lib/browser.dart; worktree has no Git commit';
    ownerAndProductLicense = 'Author attribution confirmed as DAwwN; product license and operator details pending';
    builtUtc = [DateTime]::UtcNow.ToString('o')
}
$taskRelease | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskOutput 'release.json') -Encoding utf8NoBOM
$taskNotices = Get-Content -LiteralPath (Join-Path $taskRoot 'THIRD_PARTY_NOTICES.md') -Raw -Encoding UTF8
$taskNoticeHtml = (ConvertFrom-Markdown -InputObject $taskNotices).Html
$taskLicenseHtml = @"
<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>静档 · 许可与版本 / Licenses</title><link rel="stylesheet" href="portal.css"></head><body><header class="nav wrap"><a class="brand" href="welcome.html">Quiet Campus</a><a href="welcome.html">返回 / Back</a></header><main class="wrap"><article class="guide"><h1>许可与版本 / Licenses &amp; version</h1><p>浏览器本地验收候选 web-local-20261026.2，基于原项目0.2.1+3。作者署名：DAwwN。软件授权和运营主体详情仍待本人确认；尚未开售。 / Local review candidate. Author: DAwwN. Product license and operator details are not finalized. Not for sale yet.</p><p><a href="release.json">版本清单 / Release manifest</a> · <a href="assets/NOTICES">Flutter所带原始许可 / Bundled Flutter notices</a></p><p>欢迎页网页字体是原OFL字体的WOFF2子集，改名Quiet Portal Sans / Quiet Portal Display；仅用于网页，不替换应用完整输入字体。 / The landing-page WOFF2 subsets are renamed Quiet Portal Sans / Display. Full app fonts are unchanged.</p><p><a href="fonts/NotoSansSC-LICENSE.txt">Noto Sans SC license</a> · <a href="fonts/LXGWWenKaiLite-LICENSE.txt">LXGW WenKai Lite license</a></p>$taskNoticeHtml</article></main></body></html>
"@
[IO.File]::WriteAllText((Join-Path $taskOutput 'licenses.html'), $taskLicenseHtml, [Text.UTF8Encoding]::new($false))
Write-Output "Prepared landing, guides, data notes and release manifest in $Output"
