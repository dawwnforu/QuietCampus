# Android 0.2.3：原生恢复测试包

2026-11-02。原 Flutter 项目的 `lib/main.dart`，不是内存演示，没有改加密算法或数据格式。Windows 新构建状态见[发行进展](native-release-progress.md)，不以 Android 成功替代 Windows 或 iOS 验收。

## 手机下载

[本人 Google Drive：静档安卓云同步测试版 0.2.3，先解压](https://drive.google.com/file/d/1h2yfhi-6g7i0RuaJz_ZxFHDzAZWgQUxh/view?usp=drivesdk)

私有 ZIP 回读核对 94,730,275 字节，shared=false，只有 owner 权限；没有公开共享。内含实际 APK 和中文安装说明。使用 ZIP 是因为 APK 超过连接器 100 MiB 上限；不是将它变成网页应用。

1. 用自己的 Google 账号下载 ZIP，在手机文件管理中解压。
2. 打开解出的 `QuietCampus-Android-DataTest-0.2.3.apk`，选择正常更新。不要卸载、清数据；签名冲突就停下反馈。
3. 仅用虚构记录测试。新增恢复入口在同账号尚未解锁且本机没有资料的页面，详见[恢复说明](native-backup-restore.md)。

## 已核验

- APK 135,891,663 字节；包名 `cn.quietcampus.quiet_campus`，versionName 0.2.3、versionCode 5，minSdk 24、targetSdk 36。
- APK SHA-256：`92ff139df410abc9a38230665e4df42047836e55df8254f2a5d54374453b0575`。
- `apksigner verify` 通过；证书 SHA-256 为 `7e0a3bff4f42a6250c5acddec8ae7032fc333e00ce343ffd12ce309e198ffdd2`，与旧包相同。仍为测试 debug 签名，不作为正式发行证书。
- 包内有原生 main、恢复代码和版本文字，没有 DemoController；Flutter、libsodium 和 SQLite 的 ARM64 组件存在。其他 JNI 组件附带的 ABI 不表示 Flutter 引擎支持全部 CPU；本包针对 ARM64 手机，不能安装于 iPhone。
- 测试端点及客户端公开密钥与原配置一致，只输出比较结果，没有记录或上传解密密钥。服务仍为新加坡 Free 联调环境，仅用虚构资料。
- 相关 27 项 Flutter 检查、7 项 Node 检查与静态分析通过；范围见[恢复说明](native-backup-restore.md)。

## 构建与保留

第一次重建遇到 JNI CMake 缓存的中文路径问题；保留原 JNI 缓存后，在同一项目的临时 Q: 别名中离线重新解析锁定依赖，`assembleDebug` 实际 27.3 秒通过。桌面插件符号链接准备失败未被伪称成功，Android 使用已解析配置和 `--no-pub`，没有移除原生钩子。

生成配置原字节已在 finally 恢复，自己创建的盘符已移除；原 0.2.1/0.2.2 安装包保留。没有安装或启动本人手机、重置数据库、应用服务端迁移或新增在线 AI。

## 尚未验证

本机 Widget / 组件测试不证明 Android 真机更新后资料保留、实际文件选择器、完整恢复、跨签名换装或真实 Android↔Windows 同步通过。0.2.3 也未被任何商店审核或公开发行。

导入只支持同账号、相同密钥封装、64 MiB 内的完整加密备份，且不替换非空本机档案；不要为满足条件主动删除旧资料。改口令后的旧封装备份和大档案仍保留，不能据此宣布通用灾难恢复已完成。
