# 安卓与 Windows：安装和配置

更新：2026-11-02。[0.2.4 最新入口](native-data024-delivery.md)：Android 已构建、验签并私有上传 Drive；Windows 0.2.4 完整 ZIP 在本机，新版上传已获授权但遇网络超时，尚未取得完成证据，旧 0.2.3 云端包保留。Android ZIP 先解压再正常更新 APK；Windows ZIP 完整解压后打开 quiet_campus.exe。真实双向同步、手机更新和恢复仍待设备验收。下文是历史 0.2.1 / 0.2.2 操作记录，不作为当前首选入口。

2026-11-02 新增：[Android 0.2.2 同签名数据测试版](https://drive.google.com/file/d/16YmuH1rK2Fwxj4HOntWDpi0aKeV5XC9s/view?usp=drivesdk)，本轮已构建、上传并回读核验。当前优先用此包正常更新手机，不卸载或清数据；Windows 仍使用下方原 0.2.1 数据包，协议未变。[最新交付说明](test-release-delivery-20261102.md)。

## 当前可用文件

| 文件 | 当前用途 |
|---|---|
| [Windows 0.2.1 账号口令修复版](../build/desktop/QuietCampus-Windows-AccountFix-0.2.1.zip) | 已构建并验证完整 ZIP，36,889,124 字节、60 文件；当前邮箱 / 保留资料切换账号 / 口令错误保留与显示隐藏。服务配置沿用 Free 测试项目 |
| [安卓 0.2.1 APK（本人 Drive）](https://drive.google.com/file/d/1xKKr42VxEqFGxdA4qFpkg9k-qsLrmix8/view?usp=drivesdk) · [本机文件](../build/mobile/QuietCampus-Android-AccountFix-0.2.1.apk) | 已构建并上传，回读 135,824,559 字节、私有未共享；ARM64、版本号 3、旧签名不变。正常更新，不卸载、不清数据；真实界面待本人验证 |
| [安卓传输 ZIP](../build/mobile/QuietCampus-Android-AccountFix-0.2.1.zip) | 94,663,774 字节，内含同一新版 APK；先解压再点 APK 更新，不直接安装 ZIP |
| [安卓体验包](../build/mobile/QuietCampus-Android-Preview.apk) | 已成功构建，约 126.5 MiB，通过签名和 ARM64 原生库检查。先看界面、编辑与导航；重启重置，不存真实日记 |
| [安卓完整客户端开发包](../build/mobile/QuietCampus-Android-Client-unconfigured.apk) | 已成功构建，约 167.6 MiB；尚未配置后端，打开显示服务连接准备说明。不是安装后即可登录同步的版本 |
| [Windows 原生体验包](../build/desktop/QuietCampus-Windows-Preview.zip) | 已成功构建并打包，约 34.5 MiB。完整解压后运行 `quiet_campus.exe`；包含 DLL、data 和本地 C++ 运行库，本机已检测到原生窗口正常响应 |
| [旧 Windows 0.2.0 联调版](../build/desktop/QuietCampus-Windows-SyncTest.zip) | 保留旧包用于对照。SMTP / OTP 已配置，本人反馈 Windows 收信与登录成功；账号核对和跨端同步尚未验收 |
| [安卓加密同步联调版](../build/mobile/QuietCampus-Android-SyncTest.apk) | 2026-10-23 新增，约 167.6 MiB；原 lib/main.dart，同一个测试服务，签名与预览包一致，可按系统提示覆盖更新。实际真机和跨端同步待验收；不能通过卸载或清数据处理安装问题 |

上述 APK 都来自原项目，包名相同，手机每次只更新一个版本。核对账号和持久保存使用最新数据版；Preview 是历史内存演示。若设备已有资料或遇到签名冲突，先核对提示，不能用卸载、清数据解决。

## 安卓：先做三个动作

1. 将最新数据 APK 通过本人 Drive 或 USB 文件传输放到 Redmi 手机。若聊天中的本机链接不能在手机打开，从电脑项目的 `build/mobile/` 取文件；不要重新下载历史 Preview。
2. 在手机“文件管理”中点 APK，按系统提示允许当前文件管理器安装该文件，再确认安装。保留系统安全检查；若被拦截，记录提示后处理，不关闭安全防护。
3. 打开“静档”，在档案页查看“当前登录邮箱”；与 Windows 不同则用“切换账号”返回邮箱验证码登录。不同邮箱的资料不会自动合并。先用虚构文字测试保存和回看；原声录音仍待本人实机验证。

**安装运行包不需要 Flutter、Android Studio、USB 调试或自行填写 API 密钥。** USB 调试只在需要电脑调试时开启。仅 Preview 体验包重启重置；数据版使用原本机加密缓存与队列，重启保留仍需本人验收。

## Windows：先做三个动作

1. 下载上面的 AccountFix-0.2.1 Windows ZIP，右键“全部解压”，放到独立文件夹，保留旧包作对照。
2. 正常保存草稿并关闭旧静档窗口，再双击新文件夹的 `quiet_campus.exe`。保留所有 DLL 和 `data`，不安装编译器或重填服务参数。两版共用原账号缓存，不同时运行两个窗口。
3. 在“档案”查看“当前登录邮箱”，也可进入设置，确认底部版本为 0.2.1。中央“＋ → 写日记”创建虚构内容。遇到错误不通过删除本机资料修复。

此前已实际启动 0.2.0 原生数据版并检测到窗口响应，本人反馈收信登录成功。本轮新包的实际界面与其他 Windows 电脑兼容性仍需本人验收；它是 x64 解压运行包，未购买代码签名证书，也未正式上架。

录音只在本人点击时进行；若 Windows 没有麦克风权限，可检查“设置 → 隐私和安全性 → 麦克风 → 允许桌面应用访问麦克风”。没有麦克风时可以先测试文字；本轮没有自动采集任何声音。

## 仅开发电脑需要的构建条件

这里区分“生成 Windows 包的电脑”和“将来运行 Windows 包的电脑”：普通使用者不应为了运行 EXE 安装完整编译工具。

以后自行重新编译时需要：

1. 在 Windows 设置中搜索“开发人员模式”，启用它，使 Flutter 能创建插件符号链接。不需要设备门户或远程发现。
2. 由本人阅读 [Visual Studio Community 2026 许可](https://visualstudio.microsoft.com/license-terms/vs2026-ga-community/)，授权协作者安装，或自行从 [微软官网](https://visualstudio.microsoft.com/vs/community/) 安装 Community 版。选择“使用 C++ 的桌面开发”，包含 MSVC x64/x86、CMake、Windows SDK，并补充 C++ ATL。个人开发者适用免费 Community 许可；不选择付费版。
3. 完成后由协作者核对环境、重新编译，检查 EXE/DLL/资源是否齐全，准备完整 Windows 运行包，再检查实际启动。系统安装的管理员弹窗和必要重启由本人确认。

Flutter 的 Windows 工具要求见 [官方说明](https://docs.flutter.dev/platform-integration/windows/setup)。本轮本人已阅读许可并授权免费组件安装，安装器签名已验证，返回 0，Visual Studio Community 2026 18.11.1 / MSVC 14.51、CMake、Windows SDK、ATL 均已安装并用于构建。本人确认自行开启开发人员模式；原路径依赖解析成功，但英文别名下插件符号链接仍返回权限错误，本轮仅在本项目临时构建目录使用 NTFS 目录联接完成编译，没有再改系统设置。

包中已附上 Microsoft 的 x64 C++ 运行库，因此普通试用者不需要安装 Visual Studio。运行包完整性检查涵盖 EXE/DLL 的 x64 架构、Flutter/加密/SQLite/PDF/录音依赖、资源和 C++ 运行库；ZIP 共 60 个文件。不包含数据库、用户配置或签名私钥。

## 如果要真正每天保存、安卓与 Windows 同步

2026-10-23：已开始准备官方 Free 云项目联调；本人已确认境外测试环境仅使用虚构记录。请按 [Supabase 免费联调步骤](supabase-free-test.md) 注册和配置。以下保留客户端配置原理，当前仍未完成真实同步。

这与“先看界面”的配置不同。两端要使用同一套已部署并可访问的 Supabase 服务，再构建完整客户端；现有未配置 APK 不会因为在电脑旁放了 JSON 文件就自动连上服务。

需要在开发电脑的 `config.local.json` 中填写：

```json
{
  "SUPABASE_URL": "https://你实际部署的服务域名",
  "SUPABASE_PUBLISHABLE_KEY": "该服务提供的客户端公开密钥"
}
```

上面只是格式示意，不能直接使用占位内容。示例文件里的 `127.0.0.1` 也不能直接当作手机访问电脑的地址，它在手机上指向手机自身。

仅填写服务 URL 和客户端公开密钥；不放 `service_role`、服务端 Secret Key、数据库密码、加密口令或恢复密钥，不把密钥贴到聊天。当前数据包已编入 quiet-campus-test 的 Free 新加坡测试服务配置；数据库与私有桶已配置，见 [实际进展](supabase-free-test.md)。本轮不新购服务、不改云数据库。

配置是**编译时注入**，需要由协作者用 `--dart-define-from-file=config.local.json` 重建安卓/Windows 完整客户端。以后再按测试账号验证：邮箱验证码登录、独立加密口令、恢复密钥离线保存、离线记录、重启恢复及两端密文同步。原项目没有“安装后在账户设置填服务地址”的界面，不额外编造设置项。

没有豆包语音识别 API、在线 AI 或自动云端推理回退需要配置。小兔目前使用本地规则试讲，尚未接入真正的本地 AI。键盘转文字由自己的输入法处理；原声随笔保存声音，仍须单独验证设备录音、加密存储和播放。

## 本轮验收边界

安卓包已构建、签名与原生库检查通过；Windows 原生 release 包已构建、打包并启动窗口。安卓真机、Windows 实际功能交互、长期持久化及跨端同步尚未验收。没有把浏览器演示算作 Windows 安装包，没有覆盖或清空用户数据库。

补充：Windows 下现有 `test/crypto_test.dart` 原生 libsodium 自检已通过，使用合成资料验证解锁、恢复、错误口令、篡改、账号/记录/附件绑定等；没有移开或禁用原生构建钩子。测试中“多设备”是同机多份解锁对象，不代表真实的安卓–Windows 联调。
