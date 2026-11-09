# 第三方组件

Flutter 会把所用包的原始 LICENSE 汇入应用的许可页面（设置 → 开源许可）。打包时应保留此页面及相关声明，并按 `pubspec.lock`、`package-lock.json` 核对实际分发内容。

| 组件 | 用途 | 上游许可来源 |
| --- | --- | --- |
| Flutter / Dart | 三端客户端与开发工具 | https://github.com/flutter/flutter/blob/master/LICENSE |
| Noto Sans SC | 正文与操作界面；随包字体，未经修改 | notofonts/noto-cjk 提交 f8d157532fbfaeda587e826d4cd5b21a49186f7c，Sans/SubsetOTF/SC/NotoSansSC-Regular.otf；SIL OFL 1.1，原始许可见 assets/fonts/NotoSansSC-LICENSE.txt |
| LXGW WenKai Lite 1.530 | 标题与记录名称；随包字体，未经修改 | https://github.com/lxgw/LxgwWenKai-Lite/releases/tag/v1.530 ；SIL OFL 1.1，原始许可见 assets/fonts/LXGWWenKaiLite-LICENSE.txt |
| Flutter Quill | 唯一富文本编辑器；正文保存为 Delta JSON | https://github.com/singerdmx/flutter-quill/blob/master/LICENSE （MIT） |
| pdfrx 2.9.0 / pdfrx_engine 0.7.4 | 图片/PDF 材料库中的本机 PDF 预览；只传入内存字节，不使用在线预览 | https://github.com/espresso3389/pdfrx/blob/master/LICENSE （MIT；实际版本锁于 pubspec.lock，包内原始 LICENSE 随 Flutter 汇入许可页） |
| pdfium_dart 0.4.0 / pdfium_flutter 0.4.0 | PDFium 原生绑定和平台打包 | 对应 pub.dev 包内 LICENSE（MIT）；原生构建引用 bblanchon/pdfium-binaries chromium/7811，Darwin XCFramework 对应上游发布 v144.0.7811.0-20260502-190206，见包内 hook/build.dart、Package.swift、podspec。 |
| PDFium 与随包依赖 | PDF 渲染引擎（Web WASM 随 pdfrx 包提供，原生构建下载官方发布二进制） | 保留 chromium/7811 Windows 发布包的完整 LICENSE、VERSION 与 licenses/ 至 assets/licenses/pdfium/：PDFium BSD、ICU、FreeType、libjpeg-turbo/IJG、libpng、zlib、OpenJPEG、LittleCMS、libtiff、AGG、abseil、fast_float、simdutf、LLVM libc 等。应用“开源许可”附加展示这些声明；正式分发各平台前还须核对实际产物是否带有平台新增声明。 |
| material_ui 1.8.0 / cupertino_ui 1.1.4 / rxdart 0.28.0 / synchronized 3.5.0 | pdfrx 锁定的传递依赖 | 对应包内 LICENSE；前两项为 Flutter BSD 声明，后两项许可随 Flutter 自动汇入应用许可页。 |
| characters 1.4.1 / unorm_dart 0.3.3 | 搜索时按字素映射原文、NFKC 规范化；仅本机计算 | https://pub.dev/packages/characters/license （BSD-3-Clause）；https://pub.dev/packages/unorm_dart/license （MIT，Copyright 2018 Yasuhiro Shimizu；原始许可由 Flutter 汇入许可页面） |
| TableCalendar 3.3.0 | 活动月历、周历和日期选择 | https://github.com/aleksanderwozniak/table_calendar （Apache-2.0；原始许可由 Flutter 随包汇入许可页） |
| sodium / libsodium | XChaCha20-Poly1305、Argon2id、密钥派生及安全内存 | https://pub.dev/packages/sodium/license （BSD-3-Clause / ISC，含原生组件声明） |
| sqlite3 | 本机密文与同步队列 | https://pub.dev/packages/sqlite3/license （Dart 绑定 MIT；SQLite 上游为公有领域） |
| supabase_flutter | 认证、密文接口、附件与订阅 | https://pub.dev/packages/supabase_flutter/license |
| record 7.1.2 | 用户主动录制原声；PCM 内存流，不使用文件录音 | https://pub.dev/packages/record/license （BSD-3-Clause；平台包的许可由 Flutter 随包汇入） |
| audioplayers 6.8.1 | Android / Windows / Web 原声内存播放；iOS 另用系统 AVAudioPlayer(data:) | https://pub.dev/packages/audioplayers/license （MIT；平台包的许可由 Flutter 随包汇入） |
| flutter_secure_storage | 系统安全存储中的会话与本机密钥 | https://pub.dev/packages/flutter_secure_storage/license |
| file_picker / open_filex | 用户主动选择文件、保存备份、外部预览 | https://pub.dev/packages/file_picker/license 、https://pub.dev/packages/open_filex/license |
| flutter_local_notifications / timezone / flutter_timezone | 本地提醒及设备时区 | 对应 pub.dev 包内 LICENSE |
| PGlite | 仅开发测试：实际运行 PostgreSQL 权限与函数测试 | https://github.com/electric-sql/pglite/blob/main/LICENSE |
| libsodium-wrappers-sumo | 仅开发测试和用户主动运行的独立备份解密工具 | https://github.com/jedisct1/libsodium.js/blob/master/LICENSE |
| libsodium.js sumo 0.8.4 | 新浏览器本地版随包的加密脚本，不通过CDN加载 | sodium 4.1.2 官方 update_web 工具校验固定提交 a79e5ddbbcfd130e27dcbbda1b5ba072c7a9787d；ISC 版权与许可保存在 web/licenses/libsodium-js-0.8.4-LICENSE.txt，Dart sodium/libsodium 许可见 web/licenses/sodium-4.1.2-LICENSE.txt。 |

Memos 用于研究记录时间线、标签和筛选流程，没有复制源码或素材。AppFlowy 用于跨端文档和结构化档案的设计参考，没有引入 AGPL 主项目源码、品牌或素材。Journiv 未引入。没有接入第三方在线字体或分析 SDK；没有接入在线语音识别服务；此前未部署的豆包网关已撤下。

本项目的新业务代码没有在此授予开源许可；本文件只说明第三方组件，不能替代其原始许可。

## Android 0.2.4 实际包内核验

2026-11-02 从最终已验签 APK 读取：Flutter NOTICES.Z 为 gzip 格式，压缩 121,215 字节、解压 1,467,463 字节，包含 Quill、Supabase、sodium、sqlite3、文件选择、录音和播放等已用 Dart 包的声明。另有两份字体许可、PDFium 许可目录的 17 个文件及 META-INF 下 6 份 Android 原生许可文件。

[本次许可对应证据](docs/release/android024-native-license-evidence.json)绑定已交付 APK 的 SHA-256：60 个原生版本标记中，57 个 AndroidX 标记直接匹配本机 Maven POM，另两个协程标记与对应缓存 JAR 内标记一致后匹配 POM；共 59 项读取到 Apache 2.0 声明。这些是组件自身的声明，不代替各自 NOTICE、内含第三方代码和改动声明的完整核对。

androidx.arch.core 的 core-runtime 标记内容不是有效版本号，保留为未确认，不按相邻组件猜版本。没有版本标记的依赖也不属于这 60 项覆盖范围。完整 resolved runtime classpath 导出受本机工具链路径和权限限制未成功，不能把该记录写成“全部原生依赖已通过商用审核”。本次没有修改或重新打包应用；正式候选还需按实际 release 依赖清单核对原生声明。

网页欢迎页和说明另带两份上述字体的固定文案WOFF2子集，改名为 Quiet Portal Sans / Quiet Portal Display；保留原copyright和OFL许可，随网页的fonts目录分发。生成方式见tool/subset-web-fonts.py，原Flutter编辑器完整字体未改变。Windows网页交付候选还带官方Node.js24.22.1 Windows x64运行文件和完整上游LICENSE；仅用于127.0.0.1静态启动器，不是新增应用后台。来源、校验和及复现步骤见docs/web-delivery.md。

## Windows 体验包中的平台运行库

Windows x64 解压运行包附带 Microsoft Visual C++ 运行库 14.51.36231，来源为已获本人授权安装的 Visual Studio Community 2026 的 `VC/Redist/MSVC` 目录。原 DLL 版权及签名保留，适用 Microsoft 的可再分发组件条款，不按本项目的开源组件许可处理。

许可：https://visualstudio.microsoft.com/license-terms/vs2026-ga-community/ 。打包方式参考 Flutter 官方的 application-local 分发说明：https://docs.flutter.dev/platform-integration/windows/building 。
