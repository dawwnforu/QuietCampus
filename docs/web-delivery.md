# 静档 / Quiet Campus：本地验收交付包

**验收候选，尚未公开开售。** 基于原项目 `0.2.1+3` 的 `lib/browser.dart`；网页候选标识 `web-local-20261026.1`。不是新的Android安装包，也不要求使用者安装Flutter、Node、Skill或Codex。

## Windows用户：三个动作

1. 把整个ZIP解压到自己的普通文件夹，保留`site`、`runtime`和启动文件的相对位置。
2. 双击`Start-QuietCampus.cmd`，保持控制台窗口打开；浏览器应打开`http://127.0.0.1:7360/welcome.html`。如未自动打开，复制该地址。它只在这台电脑有效。
3. 先逛逛合成示例，再按说明打开本地档案。示例刷新重置；自己的资料需要口令解锁并主动备份。首次建立档案时，请另外保存恢复密钥。

已安装过同源档案的用户仍使用原`http://127.0.0.1:7360/`档案入口，欢迎页与它同源，不迁移或清空资料。不要随意改端口、换浏览器配置或清站点数据。端口已被占用时，启动器不会结束别的进程；如果静档已经运行，继续使用原窗口，否则查清占用程序后再试。直接双击`site/index.html`的`file://`方式不在支持范围内。

关闭控制台停止本机服务，不会主动删除已保存的浏览器数据；下次使用时重新启动。资料不保存在解压文件夹中，复制交付包不等于备份档案。电脑需要兼容的Windows x64和现代浏览器；当前在本机Windows/Chrome验证，其他系统及手机实机仍须另行验收。

## 手机上如何使用

本机包不能直接在手机打开。手机需要批准后把`site`目录发布到稳定的HTTPS来源；实际域名、运营者、托管地区、费用、隐私说明和适用义务仍待确认。不得用本机地址代替公开入口。

## 包里有什么

- `site/`：原Flutter浏览器构建、同源欢迎页、中文/英文说明、数据说明草案、许可及`release.json`；可交给合适的静态HTTPS托管服务。
- `runtime/`：未经修改的官方Node.js 24.22.1 Windows x64运行文件和完整上游LICENSE，仅用于本机静态服务，不安装全局环境或额外服务。
- `serve.mjs`和`Start-QuietCampus.cmd`：只绑定127.0.0.1，不提供账号、支付或日记上传接口；不是生产互联网服务器。
- `docs/`：原始说明、第三方声明与Flutter依赖锁定清单。

网页字体子集约230KB，源为随项目原有的Noto Sans SC与LXGW WenKai Lite；为固定页面制作WOFF2并改名Quiet Portal Sans / Display，保留OFL原始声明。原Flutter编辑器的完整字体没有替换。

## 升级与回退

先导出完整加密备份，在隔离浏览器环境验证它能解锁；退出旧服务后把新包解压到另一个文件夹，保留旧包。重新启动时继续相同浏览器配置与7360来源。没有授权的真实数据迁移不会在启动器中自动执行。

遇到错误先保留现状、记录错误文字；不上传私人日记、口令、恢复密钥或生产凭据。当前版本的数据格式没有因欢迎页而改变，但未来版本仍需单独校验兼容性。旧客户端不认识新数据时应拒绝，不通过清库“回滚”；必要时用已验证的备份在隔离环境中检查。

作者署名已确认为DAwwN；使用权、支持联系方式、服务期限和价格仍待本人确认。本包不含永久云空间、自动备份、在线AI、永久人工服务或已完成的正式发行承诺。

---

## English: three steps on Windows

1. Extract the entire ZIP, keeping `site`, `runtime` and the launcher together.
2. Double-click `Start-QuietCampus.cmd` and keep its console open. It opens `http://127.0.0.1:7360/welcome.html`; copy that address if your browser does not open automatically. It works on this computer only.
3. Explore the fictional samples, then open your local archive. Samples reset on refresh. Your own archive needs a passphrase, a separately saved recovery key and regular encrypted backups.

The original archive address stays `http://127.0.0.1:7360/`. Do not change its port, browser profile or site data casually. If the port is busy, no other process is terminated. Reuse an already-running Quiet Campus window or identify the conflicting program first. Opening `site/index.html` directly as `file://` is not supported.

Closing the console stops the local server but does not erase saved browser data. Restart the launcher next time. Your archive is not stored in the extracted folder; copying this package is not an archive backup. The package targets compatible Windows x64 systems and modern browsers. Current evidence is from the local Windows/Chrome environment, not all computers or physical phones.

Phones require a separately approved, stable HTTPS deployment of `site/`. No public domain, paid hosting, recruitment or payment is configured. The package includes an original Flutter build, a landing page, bilingual guides, draft data notes, version metadata and third-party notices. Node is bundled for the loopback-only static server, with its complete upstream license. No global installation, account backend or online AI is added.

Before upgrading, export and verify a full encrypted backup in isolation. Keep the previous package, stop its server and extract the new one into a separate folder. Continue using the same origin and browser profile. Future data-format changes require their own compatibility checks; do not clear stored data to force an older client to work. Keep private writing, passwords, recovery keys and production credentials out of support messages.

This is a review candidate, not an approved sales release. Author attribution is confirmed as DAwwN. The product license, operator details, support contact, support term and price still need confirmation. No lifetime storage, automatic backup or permanent human support is promised.

## Developer reproducibility / 开发者复现

构建：`pwsh -NoProfile -File tool/build-web-product.ps1`。

仅更新固定页面：`pwsh -NoProfile -File tool/prepare-web-product.ps1`；不重新编译或替换Flutter数据层。

交付包：`pwsh -NoProfile -File tool/package-web-product.ps1`；Flutter源码未变化时可显式用`-UseExistingBuild`。脚本检测晚于构建的Dart修改，拒绝把旧构建当作新源码。

Node运行文件来源为[官方24.22.1发布目录](https://nodejs.org/download/release/v24.22.1/)，核对日期2026-10-26。[官方发布状态](https://nodejs.org/en/about/previous-releases)将24列为LTS；[完整许可](https://raw.githubusercontent.com/nodejs/node/v24.22.1/LICENSE)须随包保留。下载`node-v24.22.1-win-x64.zip`并与官方`SHASUMS256.txt`核对后，解压到`.tooling/web-delivery/`。已核对ZIP SHA256：`d2046d28c2c3dcd211ac5145c0bf30e2047ef9dfb306693c8c6e2eccd8b95fa5`；`node.exe`与官方`win-x64/node.exe`校验一致：`d702daa815eabbff763c7d3808e235cf031cf2ca70211b56847bc72f51e240e5`。不复用系统较旧的24.18.0来冒充该交付版本。

网页字体生成使用局部安装的fontTools4.67.0、brotli1.2.1、zopfli0.4.3：设置`PYTHONPATH`指向局部依赖后执行`python tool/subset-web-fonts.py`。仅构建时需要，用户交付包不携带这些开发工具。增加固定文案时重跑子集，并检查缺字和原许可。
