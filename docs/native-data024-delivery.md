# 0.2.4：原生中英文与布局测试包

2026-11-02。继续原 Flutter 项目和 `lib/main.dart`，版本 0.2.4+6。保留加密、Quill Delta、离线队列、账号隔离、冲突、附件和原免费测试配置；没有数据库迁移。仅用于虚构资料联调，不是正式商店候选。

## 当前入口

| 平台 | 产物与已验证范围 | 待验证 / 交付状态 |
| --- | --- | --- |
| Windows x64 | [本人 Drive：0.2.4 完整 ZIP](https://drive.google.com/file/d/1pciXUAun5-WZm2B9k7Os8MJ5dBeI4plg/view?usp=drivesdk) · [本机完整 ZIP](../build/desktop/QuietCampus-Windows-DataTest-0.2.4.zip)，36,023,767 字节、53 文件；Release 模式，test 环境 | 2026-11-03 上传完成，回读 36,023,767 字节、shared=false、仅 owner。此前本机已启动到锁定档案页 |
| Android ARM64 | [本人 Drive：0.2.4 先解压 ZIP](https://drive.google.com/file/d/1qPxYCq75TnqQLqmf1MzPYIFf_k3Z3Owf/view?usp=drivesdk) · [本机 APK](../build/mobile/QuietCampus-Android-DataTest-0.2.4.apk) / [ZIP](../build/mobile/QuietCampus-Android-DataTest-0.2.4.zip)；版本 6、原包名、原签名，ZIP 内 APK 哈希一致 | 上传完成，回读 94,744,981 字节、shared=false、仅 owner；没有连接实机 |
| Mac / iOS | [最新原源码交接 ZIP](../build/handoff/QuietCampus-Mac-Source-0.2.4.zip)，15,691,078 字节、114 文件；不含实际同步配置、数据库、签名或符号链接 | 仅本地源码，未上传；不是 IPA，未连接 Mac 或运行 iPhone |

Android 与 Windows 最新私有云下载均为上方 0.2.4。[Windows 0.2.3](windows-data023-delivery.md)、[Android 0.2.3](android-data023-delivery.md) 和其他旧包仍可用于对照。

## 改动与实际检查

- 登录、解锁、设置、恢复和主界面复用现有中英文机制；语言偏好保存在现有系统安全存储中。切换保留口令输入、富文本及草稿，不翻译本人内容。窄屏双倍字号的账号栏改为上下布局。详细范围见 [S04 检查](native-language-accessibility.md)。
- 上轮 44 个不同 Flutter 用例及 8 项 Node 检查通过；本轮功能未再变更，仅版本递增与打包。Windows 实际构建 98.5 秒通过，EXE 资源版本 0.2.4+6，原生主入口、恢复代码、语言偏好和英文界面文本均在 AOT 中核对；未包含 DemoController，编入配置只做布尔比较，不输出值。
- Windows 原生库清单登记的四项库齐全，运行目录补入三个官方 MSVC Release 运行库与许可说明；没有用户数据库、签名文件或私人备份。当前开发电脑实际显示“欢迎回来”、当前登录邮箱、测试版标记、口令与恢复入口；未点击解锁、切换账号或操作真实档案。窗口部分被另一应用的安装器遮挡，不能据此认定全部布局或读屏通过。
- Windows JNI 的 JVM 导入仍未在无开发工具的干净系统验证。不要预先安装 Java 或关闭系统保护；出现组件错误时保留原状反馈。
- Android 首次构建 597.0 秒通过；实际 APK 清单核对发现 open_filex 依赖合入 4 项本项目不需要的媒体读取权限，第一份 APK 已保存在 build/qa，不交付。原应用清单使用 tools:node 移除 READ_EXTERNAL_STORAGE / READ_MEDIA_IMAGES / READ_MEDIA_VIDEO / READ_MEDIA_AUDIO，未改插件源码；现有文件选择走 URI 授权，OpenFilex 的唯一调用只打开应用私有缓存，相关源码已核对。重建 18.6 秒通过，重新验签 / 读取合并清单确认四项均不存在；真实文件选择和外部预览仍待手机验证。
- 最终 Android APK 签名 v2 有效，证书 SHA-256 与旧版相同；minSdk 24、targetSdk 36，Flutter 引擎面向 ARM64。最终包核对到原生入口、恢复和语言代码、原测试配置与所需 ARM64 原生库，不包含 DemoController。
- Mac 源码交接包含最新 lib/ios/assets 与锁定依赖和示例配置；按 README-MAC.txt 由本人确认工具链及签名后再构建。没有因 Windows 构建而宣称 iOS 通过。

## 完整性与版本回退

- Windows ZIP SHA-256：`aecc8a5bba4b947732e0d8eb1f2fcb1ebe7205f54e132eec987e36f04fa4dbc4`。
- Windows EXE SHA-256：`a2fd56e6c9acdbfe26b1a8f2ddb2c218fa5800a6cceaa49fe3648c253d7b0184`。
- Mac 源码 ZIP SHA-256：`e1b54e1d804d53489259ae30726c0aa71034bba437f31db711968a7a8f6b74f6`。
- Android APK SHA-256：`45ad8a8fd971b2d39dae0948948332fba12468ab27749ca10680d402c248246c`。
- Android 传输 ZIP：94,744,981 字节，SHA-256 `34c836ac830929834a604f85b8acbc8de5ac3a0e7c836722e3437f54653fb70b`；只包含最终 APK 与安装说明。

Windows 完整解压到独立目录，保留旧版；不要只移动 EXE。0.2.4 没有变更加密或记录格式，但旧版不会显示新语言功能。安卓如出现签名冲突应停止；本轮不指示卸载、清数据或安装低版本来绕过检查。

## 下一次本人验收（有空时，约 10 分钟）

1. 两端使用相同测试邮箱，凭据只填客户端。账号切换选择保留资料的“切换账号”，不是“退出并清缓存”。
2. Windows 保存独特标题的虚构随笔，重启确认仍在；安卓核对这个确切标题与正文。
3. 安卓追加一句虚构文字，等同步后在 Windows 打开原文核对；若不一致，记录两端版本、同步提示和是否同邮箱，不清数据。

只看到“已同步”不证明另一设备已收到。文件选择、原声听感、拒绝系统权限、真实中文键盘、TalkBack / VoiceOver、跨签名恢复和正式商店发行仍分别待验收。
