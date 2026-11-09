# 原生发行构建与签名交接

更新：2026-11-02。仅准备候选，不执行购买、签约、发布或真实资料迁移。

后续已实际完成 [Android 0.2.3](android-data023-delivery.md) 与 [Windows 0.2.3](windows-data023-delivery.md) **Free 环境测试包**的构建和私有交付；Windows Release 模式编入 test 环境，不是通过生产预检的正式候选。以下保留最初 0.2.1 的核查和正式签名准备记录。原生导入现有[空档案恢复入口](native-backup-restore.md)，但签名换装仍未实机演练，不能据此指示卸载。

## 已有包与正式候选的区别

原包继续保留：Android AccountFix 0.2.1+3 使用 lib/main.dart，135,824,559 字节；Windows 0.2.1+3 完整 ZIP 为 36,889,124 字节。两者连接同一新加坡 Free 联调服务；APK 是 debug 测试签名，不是正式发行包。Preview 是会重置的另一入口，不能存真实档案。

最初工程核查没有重新编译；后续已交付的 0.2.3 见页首。新增[原生中英文与无障碍源码](native-language-accessibility.md)已递增为 [0.2.4+6 测试包](native-data024-delivery.md)，本地包及签名已有实际核验；不将测试包改名为正式发布包。

## 新增预检与构建入口

2026-11-03 回归验证发现，已知测试域名可通过末尾加点绕过正式环境预检。现按去掉末尾 DNS 根标签的主机名比较，已知测试域名与本地保留域名的带点写法都会被拒绝。修复前复现失败，修复后发行预检相关 4 项测试通过。

`tool/check-native-release.mjs` 只读检查正式环境标记、HTTPS 地址、客户端公开密钥和 Android 签名配置，拒绝当前 Free 联调项目、本地/示例地址、管理密钥、额外敏感配置和缺失签名。不连接服务，不输出配置值，不生成密钥。

预检不是证书、JWT 签名或服务可用性验证。配置字段存在、域名格式合法也不能证明账号归属、生产部署、备案或商店准入；构建后仍需验证实际包和设备。

本地正式配置从 config.release.example.json 复制为 config.release.local.json 后由本人安全填写；后者已忽略。只允许 APP_ENVIRONMENT、SUPABASE_URL、SUPABASE_PUBLISHABLE_KEY 三项。不得将服务器或恢复密钥填入。

在项目根目录执行：

```powershell
node tool/check-native-release.mjs android config.release.local.json
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build-native-candidate.ps1 -Platform android
# Windows 的同一原生入口：
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build-native-candidate.ps1 -Platform windows
```

构建脚本固定使用 lib/main.dart 和 release；预检失败不启动 Flutter，不回退 demo/debug，不替换归档安装包。需要其他渠道格式或架构时，先据渠道规则调整，不在缺少前置条件时绕过预检直接打包。Windows 此入口仅生成未认证的候选运行目录，不代表已有 MSIX 签名或微软商店身份。

本轮实测当前 config.local.json 被拒绝，原因是没有 production 标记、连接已知测试项目、没有 Android 正式签名配置；这是预期阻断，不是用户数据故障。三项自动测试涵盖安全/测试配置、敏感字段与错误 JSON 不回显、签名文件缺失。合成签名文件只用于检查文件存在的测试，未被当作有效证书。

## Android 签名不能直接切换

本轮重验测试 APK 的证书 SHA-256 为 `7e0a3bff4f42a6250c5acddec8ae7032fc333e00ce343ffd12ce309e198ffdd2`，包名 `cn.quietcampus.quiet_campus`。不要修改包名来绕过覆盖安装。

1. 本人确定正式密钥的所有者和离线保管位置；协作者只准备命令与忽略规则。没有本人进一步授权，不创建正式密钥、不代设口令、不上传私钥。
2. 首次正式包与测试包签名若不同，先停止手机换装。保留原安装包、原 App 和全部密文；不得用卸载/清数据处理冲突，也不能把文件改名当作解决办法。
3. 用虚构资料在备用环境验证完整备份与换装后的恢复，再决定真实资料路径。当前原生设置提供完整加密导出和独立离线解密工具；0.2.3 增加同账号 / 同封装的空档案恢复 UI，但尚未做手机跨签名演练，不能把浏览器恢复或原生逻辑测试当作换装通过。

原生跨签名恢复路径未打通且实际双向同步未验收前，只继续现有同签名测试，不向本人发出卸载或正式换装指令。已有完整备份不自动意味着能直接导入另一个账号/保险库。

## Mac/iOS 交接

本机是 Windows，没有可用的 Xcode/Docker 命令，也没有已确认可访问的 Mac 会话；不扫描 SSH 私钥或猜测远程主机。已有 iOS 工程不等于可安装 IPA。

Mac 可达后在原源码副本中先读项目指令，使用锁定 Flutter，运行相关测试及 `flutter build ios --simulator --no-codesign --target lib/main.dart` 做编译检查。无服务配置时打开准备说明，不能算登录验收。连接测试服务需由本人安全提供公开客户端配置。

正式构建前运行同一个 Node 预检的 ios 平台检查，再在 Xcode 中由本人选择 Team 和真实 Bundle ID/签名，核对权限、SDK 隐私清单、出口合规问卷及实际设备。未经签名的 .app、模拟器包或 TestFlight 都不是 App Store 正式下载验收。源码交接只包含实际源文件、锁定依赖与许可，不包含工具缓存、数据库、签名或私人导出文件。

完成 Xcode Team 设置及 iPhone 信任后，从源码根目录运行 `flutter devices` 确认设备，再运行 `flutter run -d <设备ID> --target lib/main.dart --dart-define-from-file=config.local.json`。将占位符换成上一步列出的设备 ID。打开登录页后，用虚构资料验证录音、保存、重启回看和同步。

正式环境与签名齐备后，从源码根目录运行 `node tool/check-native-release.mjs ios config.release.local.json`。预检通过后再运行 `flutter build ipa --release --target lib/main.dart --dart-define-from-file=config.release.local.json`。现行源码将 `APP_ENVIRONMENT=production` 显示为「云同步版」，其他环境显示「云同步测试版」。已归档的 0.2.4 测试包保留原有标识。

参考：[Flutter Android 发行](https://docs.flutter.dev/deployment/android)。已核对 2026-11-02；各大陆渠道的 APK/签名要求另核对，不能用 Google Play 规则替代。
