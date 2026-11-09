# 安卓与 iPhone 开发试跑

核对日期：2026-10-22。继续原 Flutter 工程，不部署服务器，不发布商店版本，不变更数据库。

## 两种入口的区别

| 入口 | 用途 | 数据与限制 |
|---|---|---|
| `lib/demo.dart` | 先在手机看界面、编辑、标签和导航 | 合成资料，内存保存，重启会重置；不验证登录、加密缓存或云同步。请勿保存真实日记 |
| `lib/main.dart` | 完整客户端验收 | 原有加密数据层；需要自己的 Supabase 配置及测试账号。配置未完成时只显示准备说明 |

两者共享原项目的界面与业务组件；演示入口不能替代完整客户端。验收完整客户端只用合成测试资料，不清理已有账号库。

## Windows / 安卓

本轮安装免费工具到 `.tooling/`：Temurin JDK 17.0.20.1、Android Command-line Tools 22.0、API 36（插件编译另下载 API 34、35）、Build Tools 36.0.0、Platform Tools、NDK 28.2.13676358、CMake 3.22.1。JDK 与 Command-line Tools ZIP 均已核对官方 SHA-256。Android SDK 许可由本人阅读后明确授权接受。`tool/flutter.ps1` 只为当前进程设置工具与缓存路径，并使用本机 Git Bash / NDK make 构建 libsodium，不修改系统 PATH。

当前路径包含中文，Java Properties 和 Android 原生工具链可能误读。开发时用临时盘符别名访问**同一个目录**，不复制或迁移项目。若 Q: 已占用，先停下检查，不能覆盖其他映射：

```powershell
subst
subst Q: "C:\Users\Dawn\Documents\ChatGPT\个人档案"
Set-Location Q:\
```

准备手机（约 3–5 分钟）：

1. Redmi 设置中找到系统版本，连续点击开启开发者选项；在开发者选项打开 **USB 调试**。不同 HyperOS 版本位置会不同。
2. USB 数据线连接电脑，解锁手机，在手机上核对并同意当前电脑的调试授权。不要开启 OEM 解锁或关闭系统安全防护。
3. 在项目终端运行下列设备检查；出现设备且状态为 `device` 才算成功，`unauthorized` 要回手机确认。将设备 ID 仅在本机命令使用，不必发到聊天。

```powershell
& .\.tooling\android-sdk\platform-tools\adb.exe devices -l
```

构建与运行共用现有 SDK 包装器：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\flutter.ps1 pub get
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\flutter.ps1 build apk --debug --target-platform android-arm64 -t lib/demo.dart --no-pub
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\flutter.ps1 run -d <设备ID> -t lib/demo.dart --no-pub
```

若 `pub get` 提示需要符号链接支持，在 Windows 设置 → 系统 → 开发者选项中启用“开发人员模式”，然后重试。这是 Windows 系统设置，需要本人决定和操作；本轮未代为开启。

此处先构建适合 Redmi K 等现代安卓手机的 ARM64 包，最低系统来自原工程的 Android 7.0 / API 24；不是所有老设备的通用包。APK 构建输出通常为 `build/app/outputs/flutter-apk/app-debug.apk`。只有实际生成并检查的文件才可安装。若手机已有使用相同包名的静档且签名不匹配，**不得通过卸载、清数据解决**；先停下处理签名或隔离测试包。

本机工具目录、用户 `.android` 目录可能包含 Android 调试授权密钥与 debug 签名，请勿上传或随 Mac 源码包分享。关闭调试会话、断开手机后，可用 `subst Q: /D` 解除自己创建的别名；解除后需在原路径重新运行 `pub get`，使生成的依赖路径恢复一致。不要在构建进行中解除。

## Mac / iPhone

当前只有 Windows 执行环境，不能在这里构建或签名 iOS。Mac 必须使用 macOS 版 Flutter；不要复制 Windows 的 `.tooling`、`.dart_tool`、`build`、`android/local.properties` 或 `ios/Flutter/Generated.xcconfig`。

已准备的源码包为 `build/mobile/QuietCampus-source-20261022.zip`，包含 213 个原项目源文件，已核对必要入口及工程文件；不包含本机配置、数据库、工具缓存或签名文件。它是同一工程的转移包，不是另建的应用。

先完成这一组（首次可能 1–2 小时，下载速度和 macOS 支持情况会影响）：

1. 在 Mac 的 App Store 安装该 macOS 支持的 Xcode，打开它，由本人阅读并接受 Apple 协议，安装 iOS 平台组件。若当前 macOS 不能安装所需 Xcode，先核对升级条件，不自动升级系统。
2. 按 [Flutter 安装文档](https://docs.flutter.dev/install/manual) 安装 **Flutter 3.47.7** 的 macOS 对应架构版本，加入该 Mac 的 PATH；按 [Flutter iOS 环境说明](https://docs.flutter.dev/platform-integration/ios/setup) 准备 CocoaPods / Xcode 工具链。
3. 将本轮生成的原项目源码包通过本人选择的本地传输方式放到 Mac，解压到一个简短英文路径，例如 `~/Developer/quiet-campus`。在目录内打开终端，运行：

```sh
flutter --version
flutter doctor -v
flutter pub get
flutter build ios --simulator --debug -t lib/demo.dart --no-codesign
```

成功标志：`flutter doctor` 的 Xcode 项通过，模拟器构建实际生成 `Runner.app`。若插件要求 CocoaPods，按 Flutter 的诊断安装；不应为消除错误删除或重建原 `ios/` 工程。

再做真机这一组（环境齐备后约 15–30 分钟）：

1. 用 USB 把 iPhone 接到 Mac，解锁并在手机上信任该电脑；按系统提示开启 iPhone“设置 → 隐私与安全性 → 开发者模式”。
2. 用 Xcode 打开 `ios/Runner.xcworkspace`，在 Runner → Signing & Capabilities 选择本人账号的开发 Team，由本人登录 Apple 账号并处理签名。不要把 Apple 密码或证书发到聊天。不购买会员、不上传 App Store。
3. 在终端运行 `flutter devices`，然后 `flutter run -d <iPhone设备ID> -t lib/demo.dart`。实际装入手机并可操作才算完成；免费个人签名不是正式上架，可能需周期性重新签名。

模拟器的成功不能证明真机麦克风、系统日历、通知或安全存储正常；完整客户端还需换 `lib/main.dart`，使用测试账号验证加密、恢复和同步。

## 真机验收清单

只用临时合成内容，逐项记录设备型号、系统版本和实际结果：

- 启动、本地日期、三目的地导航、中央新增；状态栏、手势区域、键盘和大字体不遮挡操作。
- 中文输入、Markdown 快捷排版、保存、回看、搜索高亮、历史标签和关联。演示重启重置属于已知限制，不是持久化验收。
- 麦克风拒绝、短录音、确认加入、播放、拖动、后台暂停及锁屏；不得用键盘转文字通过代替原声录音验证。
- 图片/PDF 导入预览、系统日历、提醒拒绝授权；系统能力和隐私权限由本人逐项触发。
- 完整客户端：测试账号断网编辑、重启恢复、两设备密文同步、并发冲突、恢复密钥、退出清理、加密备份。未配置测试后端前记为未验证。

## 本轮结果

| 项目 | 实际结果 |
|---|---|
| Windows 安卓工具链 | 已安装并用于实际构建；免费工具，未修改系统 PATH |
| 原生 Android 界面体验包 | **已成功**：`build/mobile/QuietCampus-Android-Preview.apk`，132,659,899 字节（约 126.5 MiB）。开发调试包体积不代表正式版 |
| APK 检查 | `apksigner verify --verbose` 通过，APK v2 签名；包名 `cn.quietcampus.quiet_campus`，版本 0.2.0+2，minSdk 24，targetSdk 36；确认 ARM64 的 Flutter、libsodium、SQLite、PDFium 及预览 gate 库实际入包。未跳过其原生构建钩子 |
| 完整客户端 `lib/main.dart` 构建 | **已成功**：`build/mobile/QuietCampus-Android-Client-unconfigured.apk`，175,760,441 字节（约 167.6 MiB）。同样通过 APK v2 签名和 ARM64 原生库检查。未配置自己的测试 Supabase，打开是服务连接准备说明，不算真实账号或同步验收 |
| 安卓真机 / 模拟器 | 未运行；`adb devices -l` 当前没有连接设备。没有安装或覆盖手机应用 |
| Mac / iOS | 源码与操作说明已准备；没有可执行的 Mac 环境，未编译 Swift、未生成或签名 IPA，未在模拟器或 iPhone 运行 |
| 登录 / 加密保存 / 同步 / 录音 / 提醒 | 仍未做真机验收；APK 签名和原生库检查不证明这些运行时能力通过 |

构建时处理了原路径中文字符被 Java Properties 误读，以及 Windows 上 libsodium 找不到 Git Bash / make 的问题；使用同目录别名和进程内工具路径解决，没有修改加密算法或存储格式。Windows `pub get` 仍提示符号链接支持，需要本人启用开发人员模式后才能顺畅执行后续依赖更新；本轮 Android 构建使用已生成的依赖配置与 `--no-pub` 成功。

构建完成后已停止本项目的 Gradle 构建进程、恢复原目录的依赖路径，并解除此次 Q: 别名；后续 Android 构建按上方步骤重新建立。未清理用户资料或数据库。

体验包和完整客户端使用同一个原项目包名；先只在没有真实静档资料的测试手机试用。体验包是内存演示，不能用来长期存档；其原声附件也不具备完整客户端的持久化与加密同步保证。

## 依据

- [Android SDK 工具与下载](https://developer.android.com/studio)、[许可](https://developer.android.com/studio/terms)
- [AGP 9.1 兼容要求](https://developer.android.com/build/releases/agp-9-1-0-release-notes)：现有项目使用 Gradle 9.3.1；JDK 17、Build Tools 36、NDK 28.2 与当前工具链相配。
- [Flutter Android 环境](https://docs.flutter.dev/platform-integration/android/setup)、[iOS 环境](https://docs.flutter.dev/platform-integration/ios/setup)
- [Temurin 下载](https://adoptium.net/temurin/releases/?version=17)：JDK ZIP 已核对发布方 SHA-256。
