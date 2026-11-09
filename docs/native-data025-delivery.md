# 静档 0.2.5 原生数据测试包

2026-11-03。版本 0.2.5+7，原生入口 `lib/main.dart`，使用新加坡 Free 联调环境。此次修复了备份导出期间锁定或切换账号时的竞态，并让正式与测试构建显示对应的环境标识。加密和备份格式沿用 0.2.4。

## 联调服务复查

2026-11-03 从当前电脑向已编入双端包的 `https://eeeeisvdrcvjgmjtobgp.supabase.co` 发起 HTTPS 检查。Auth 健康接口和 Storage 状态接口均返回 200，匿名档案查询返回 401（42501）。现有托管测试服务当前可达，电脑无需启动本地服务，安卓使用可访问该 HTTPS 地址的网络即可。若 Free 项目暂停，由项目所有者在 Supabase 控制台恢复项目后再检查。两份安装包 SHA-256 复核与下列记录一致。

本轮尚待使用隔离测试身份验证登录、密文读写、两个账号相互隔离与附件下载。HTTP 健康结果仅覆盖服务可达性及匿名档案读取被拒绝。

Chrome 打开上述测试项目控制台后转到 Supabase 登录页。机器侧真实服务验收需要项目所有者登录控制台，随后可在测试项目内准备两个仅含虚构资料的独立身份。邮箱验证码和开发者控制台登录由本人在对应界面操作。现有测试包仍可先安装，手机到手后按下方步骤验收。

注册与商店材料统一见[发行办理清单](native-store-submission-draft.md)。

机器侧云端检查入口为 `node tool/check-hosted-test.mjs`。运行前在测试控制台准备两个全新的、已确认且可使用密码登录的 `quiet-qa-…@example.com` 虚构账号。通过当前终端会话的 `QUIET_QA_EMAIL_A/B` 和 `QUIET_QA_PASSWORD_A/B` 环境变量提供账号，不写入仓库或聊天。脚本限定现有测试项目，确认两个账号均无档案后才写入一条合成密文和一个合成附件。每次使用新账号，产生的测试数据保留供核对。密码登录仅用于机器测试，应用的邮件验证码路径另行验收。当前已通过脚本语法检查并确认缺少凭据时在登录阶段停止，真实服务上的写入与恢复尚未运行。

- Windows x64 [完整 ZIP](../build/desktop/QuietCampus-Windows-DataTest-0.2.5.zip)。构建耗时 62.6 秒，EXE 的 ProductVersion 和 FileVersion 均为 0.2.5+7。ZIP 含 53 个文件，36,028,469 字节，SHA-256 `e607535b141d06636cbacbfc83e2be28d5b3ed1198e0b4f5f45a37169aa069cf`。
- Windows ZIP 内 53 个文件已逐项与原构建目录比较 SHA-256，全部一致。当前桌面仍有 0.2.4 窗口，待关闭旧窗口后再启动 0.2.5，避免两个进程同时使用同一个本机档案。
- Windows 编译产物和 Android APK 内的 Flutter kernel 均已核对原生入口及 Free 联调配置。两端编入相同的服务地址和客户端公开密钥。Windows 另已核对测试版标识。
- Android ARM64 [APK](../build/mobile/QuietCampus-Android-DataTest-0.2.5.apk) / [传输 ZIP](../build/mobile/QuietCampus-Android-DataTest-0.2.5.zip)。构建耗时 480.1 秒，包名 `cn.quietcampus.quiet_campus`，versionCode 7，最低 Android 7.0，targetSdk 36。签名校验通过，证书与 0.2.4 相同。Flutter 引擎和 libsodium 均包含 ARM64 版本，未声明广泛媒体读取权限。APK SHA-256 `3d499e944d409ef03eebb36419f4bde8200a25636b032dd6470bda40ae677210`，ZIP SHA-256 `90037b2dcb592701ba14dfd4499ac74bae850af9200029d8704d3e8eaf13c700`，解包后 APK 哈希一致。
- Mac / iOS [源码交接 ZIP](../build/handoff/QuietCampus-Mac-Source-0.2.5.zip)。117 个文件，15,696,516 字节，SHA-256 `f40763d695399e1dd445cf168d6ae226a252bdad373d352672ef7338f369bad2`。含当前原生源码、锁定依赖、示例配置、iOS 命令和正式构建预检。Mac 编译和签名仍待验收。
- 已在 Windows 将 Mac ZIP 解压至隔离目录并执行包内 iOS 预检。缺少正式配置或传入占位示例时均返回退出码 1。原生入口、控制器、依赖清单与锁定文件、Xcode 工程及预检脚本的哈希与工作区一致。
- Android 0.2.5 与 0.2.4 的原生 `.so` 和 `META-INF/*.version` 文件共 72 项，逐项比较 SHA-256 均一致。[0.2.4 原生许可证据](release/android024-native-license-evidence.json)可用于这些相同条目的对照。
- Android debug 运行依赖图已解析出 107 个外部模块。本机 POM 中，101 个声明 Apache 2.0，1 个声明 BSD-3-Clause，5 个未填许可字段（Flutter 的 4 个模块及 Guava ListenableFuture）。[逐项 POM 记录](release/android025-runtime-pom-licenses.json)用于核对依赖声明。正式构建的依赖图与随包许可仍需按正式产物核验。
- 五个空字段的补充证据。ListenableFuture 1.0 的 POM 引用 `guava-parent:26.0-android`，该父 POM 声明 Apache 2.0。四个 Flutter 模块的版本均对应本机 SDK 的引擎修订 `deb287481e3ce9468f3434937ced4240a70539ca`。本机引擎源码附 BSD 许可，APK 内 Flutter 汇编许可 `NOTICES.Z` 已核对与 0.2.4 字节一致。引擎自身许可和汇编许可分别留作证据，正式包仍需复核。
- 备份恢复原生回归 8 项、Node 检查 8 项通过。界面回归分别覆盖正式标记和默认测试标记，每组 4 项。Windows 0.2.5 运行、手机覆盖更新、双向同步和正式签名另行验收。
- 云端检查脚本已使用本地 HTTP 响应替身跑完全部步骤，验证生成的合成密文和附件能用口令及恢复密钥解开。真实服务的登录、权限和写入仍待测试账号。

## 双端验收（约 10 分钟）

1. Windows 完整解压至独立目录，运行同目录下的 `quiet_campus.exe`。将 APK 传到安卓后正常覆盖更新。两端核对版本为 0.2.5，并用同一个测试邮箱登录。遇到签名冲突时保留旧应用及资料。
2. 在 Windows 保存一条带独特标题的虚构记录，重启后确认仍可打开，再在安卓核对同一标题和正文。
3. 在安卓给该记录追加一句虚构文字，等同步完成后在 Windows 核对。以两端都能读到这次修改为通过标志。
