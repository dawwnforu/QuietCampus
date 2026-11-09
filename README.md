# 静档 · Quiet Campus

面向大学生的私人档案应用。Flutter 共用 iOS、Android、Windows 代码，支持私人记录、活动报名、证明附件、标签搜索、提醒和加密同步。

发行准备最新入口：[S01–S08 进展](docs/native-release-progress.md) · [0.2.4 原生包与下载核验](docs/native-data024-delivery.md) · [此前网页与账号准备](docs/test-release-delivery-20261102.md)。本人暂跳过个体工商户登记；真实双向同步、正式签名与商店发行仍待验收。正式候选使用 `tool/build-native-candidate.ps1`，不要将现有 Preview/Free 联调包当作正式版。

后续[原生中英文与无障碍修正](docs/native-language-accessibility.md)已进入 0.2.4 原生测试包；旧 [Android 0.2.3](docs/android-data023-delivery.md) / [Windows 0.2.3](docs/windows-data023-delivery.md) 继续保留，不包含新增语言功能。真实双端同步仍待验收。

商店材料补充：[原生 SDK、实际权限与数据流清单](docs/native-sdk-data-inventory.md)，用于核对隐私和渠道表单，尚未提交或取得检测认证。

示例资料界面：[Windows 双栏](docs/previews/windows.png) · [手机记录列表](docs/previews/mobile.png) · [手机编辑页](docs/previews/editor.png)。

## 浏览器本地版（开发中）

`lib/browser.dart` 复用原 Flutter 界面、Quill 和加密格式，以 IndexedDB 保存本地密文档案；不要求注册、不连接 Supabase、不含跨设备云同步。与原生入口 `lib/main.dart`、刷新即重置的 `lib/demo.dart` 分开构建，不替换原生数据层。

构建：`pwsh -NoProfile -File tool/build-web-product.ps1`；启动：`node tool/demo-server.mjs build/web-product 7360`。欢迎页为 `http://127.0.0.1:7360/welcome.html`，原档案入口仍为同来源的 `/`，合成示例为 `?demo=1`。这些本机地址不能当成公众或另一台手机的入口。普通Windows用户使用解压交付包中的 `Start-QuietCampus.cmd`，无需另装Flutter/Node；见[启动与交付说明](docs/web-delivery.md)。

主要记录、编辑、标签、日历、材料与备份界面已接入中英文；界面语言切换保留草稿，不翻译私人正文或标签。使用及备份说明：[中文](docs/web-user-guide.zh-CN.md) · [English](docs/web-user-guide.en.md)。实际证据、限制和剩余工作见 [网页推进记录](docs/web-product-progress.md)；手机实机、完整读屏、带附件的网页恢复和正式交付尚未验收，不代表公开发布或首售完成。

交付准备：[仅本地模拟交付](docs/web-delivery-rehearsal.md) · [公开托管前置条件](docs/web-hosting-readiness.md)。模拟订单不计收入，静态文件包不等于已部署网站；域名、公开上传、平台协议和收费仍须本人确认。

## 已实现

- **账号与口令（0.2.1）**：档案与解锁等入口显示当前登录邮箱，支持保留各账号本机密文、待同步队列和冲突的账号切换；新口令先校验长度与两次一致，错误保留输入，口令 / 恢复密钥支持显示隐藏。详见 [操作与验证说明](docs/account-auth-ux.md)。

- **小兔讲述试作**：随笔列表直接显示小兔讲述，点卡片或箭头打开原始富文本，编辑仍在详情里；块内标签采用小号深蓝斜体，点击仍能筛选。原创小兔阿跃（暂名）保留四类图片倾向，【神态动作】独立使用 20 条原创剧本式描写，同一图片可搭配不同文字；同条记录在同类情境下稳定显示。当前用本机规则试讲，未接入 AI，不上传、不存储讲述文本，不能泛化理解日记；搜索和导出仍只使用原文。参见 [小兔预览说明](docs/rabbit-preview.md)。
- **材料库（0.2）**：档案入口内导入图片/PDF，保存名称、分类、说明、标签和日期；同一份原件可关联多段经历/项目，并在原 Quill 编辑器中插入引用卡片、打开内存预览。材料与文件名沿用原有加密；解除关联、删除记录、删除材料分别处理。使用前需把同账号所有设备升级到 0.2，旧客户端不支持新的 v2 内容。实现与验证范围见 [材料库接入记录](docs/material-library.md)。
- **随笔**：日记、经历和项目共用紧凑时间线与分类，首页显示设备本地日期；主导航为随笔、活动、档案，中央加号用于写日记、留经历、存项目。
- **搜索与回看**：标题、Quill 正文、标签、类型及承担工作共用本机搜索。NFKC 规范化后支持精确及顺序字符模糊命中，重复命中统一高亮；摘要定位到正文首个命中附近，打开全文仍保留富文本。高亮只在显示层计算，不写入 Delta、同步或导出。不是语义搜索或错别字纠正。
- **分批与导出**：列表先展示 20 篇，可继续加载；搜索与“导出全部随笔”覆盖全部已解锁的本机记录，不受当前分类和显示数量限制。明文 JSON 导出保留 Delta 和附件信息，不含附件文件；单篇可导出原始正文文本。完整加密备份仍使用原有设置入口。这是客户端渲染分批，不是新的服务端搜索或分页。
- **标签**：输入 `#标签` 后回车 / 空格确认，可点击历史标签复用；`#甲#乙`、全角井号及粘贴多个标签均可识别。历史目录作为独立加密记录保存，移除某条记录上的标签或删除记录后仍能复用。管理页支持搜索、查看关联数量、重命名、同名合并和从所有记录移除标签；标签目录不计入记录或字数统计。批量更新逐条保存，若中途失败会提示已处理数量，重试可继续完成；跨设备并发仍通过现有冲突版本机制处理。
- **活动**：TableCalendar 月历 / 双周 / 周历、当天日程时间轴；开始和结束时间、参与状态、截止时间、提醒、承担工作及证明材料。
- **档案**：可编辑的加密个人资料；记录数、正文非空白字符数、项目数、记录天数、12 周日期分布和半年月度分布，以及经历证明材料。修改同一记录不增加次数；日程及个人资料不计入记录统计。所有统计只在解锁后的本机计算。
- **隐私底座**：邮箱验证码登录；独立加密口令、恢复密钥、本机系统安全存储；正文和附件上传前加密。云端账户归属检查覆盖数据库、附件和同步订阅。
- **数据保护**：SQLite 密文和待同步队列；版本冲突保留两个版本；删除墓碑；幂等重试；完整加密快照导出、独立离线解密工具、账号删除。

没有公开主页、用户发现、关注关系、广告或第三方 AI 接入。简历生成、校园平台自动导入和机会推荐留到后续。

## 文档式随笔编辑

宽屏随笔列表中，选中记录后点击右侧“编辑”，直接在原阅读区域修改；标题和正文沿用阅读字体、暖白背景与留白，不再放进固定高度的表单框。保存后回到原记录。标签、关联活动折叠在“标签与关联”中；需要时展开“排版”，录音、材料引用、附件和提醒仍保留。窄屏也使用相同文档正文；编辑中切换宽窄屏或收起导航保留当前草稿，切换记录/目的地或退出编辑会检查未保存修改。

支持类似飞书文档的 Markdown 快捷输入，而非源码编辑器：行首 `# ` / `## ` / `### ` 转标题，`- ` / `1. ` 转列表，`> ` 转引用，`[ ] ` / `[x] ` 转待办；三个反引号后加空格或回车进入代码块。成对输入星号/下划线、波浪号或反引号，可转为粗体、斜体、删除线或行内代码。只转换新输入；中文组合输入结束后再处理，撤销恢复的原文不被立即重新格式化。它是列出语法的输入辅助，不是完整 CommonMark/GFM 导入、表格解析或 Markdown 文件同步。

原始正文仍以 Quill Delta 加密保存；旧记录不批量转码，材料嵌入、标签、原声附件、搜索、明文文本/JSON 导出与完整加密备份保持原机制。不增加数据版本、数据库迁移或在线处理。编辑仍需点击“保存”，不是自动保存服务。

## 可操作演示

演示与原生客户端共用 Flutter 界面，无需配置云端。点击「新记录」选择「写日记 / 留经历 / 存项目」，可编辑、保存、搜索、删除，也可试用附件。**演示资料仅留在当前页面内存中，刷新或关闭即重置；没有登录、加密同步和系统通知，请只使用示例内容。**

```powershell
flutter run -d chrome -t lib/demo.dart --web-port=7357 --web-hostname=127.0.0.1
```

本工作区可直接运行 `powershell -ExecutionPolicy Bypass -File tool/demo.ps1`，构建后在 `http://127.0.0.1:7357` 提供本机演示。该脚本处理便携 SDK 的中文目录编译问题，退出时恢复 SDK 文件；需要 Node.js，按 Ctrl+C 停止服务。

## 运行客户端

使用 **Flutter 3.47.7 / Dart 3.13.5**。依赖版本已在 `pubspec.yaml` 和 `pubspec.lock` 中锁定。

```powershell
flutter pub get
Copy-Item config.example.json config.local.json
# 在 config.local.json 填入服务地址和客户端公开密钥
flutter run -d windows --dart-define-from-file=config.local.json
```

`config.local.json` 已忽略，不要填写 `service_role`、服务器 Secret Key、加密口令或恢复密钥。正式构建连接的服务必须使用 HTTPS。

Windows 需安装 Visual Studio 的“使用 C++ 的桌面开发”、Windows SDK、C++ ATL，并开启支持符号链接的开发环境。`sodium` 会从随包分发的 libsodium 源码构建原生组件；Android 在 Windows 上编译还需要 Git Bash 和 make。Android 需 Android SDK/JDK；iOS 需 macOS/Xcode 与对应签名配置。

本工作区另有便携 Flutter，可通过 `powershell -ExecutionPolicy Bypass -File tool/flutter.ps1 ...` 使用；该辅助脚本只在子进程内将工具缓存和临时文件定向到 `.tooling`。不需要把 `.tooling` 提交到 Git。

手机试跑按 [安卓与 iPhone 开发环境说明](docs/mobile-device-setup.md) 操作，包含本机 Android 工具、中文路径处理、Mac 源码转移与 Xcode 签名步骤。手机演示入口仍是 `lib/demo.dart`，完整加密客户端仍是 `lib/main.dart`；安装包、真机和真实同步的验收须分别记录。

当前先试用安卓与 Windows，按 [安装和配置快速说明](docs/android-windows-quickstart.md) 操作；其中区分体验包、完整客户端、运行所需条件和编译工具，iPhone 暂缓。

## 本地同步服务

### 系统日历与提醒

新增日程默认选择“系统日历”，可切换到“静档内提醒”。保存时先保留静档里的加密记录，再由用户确认是否导出时间和名称；默认隐藏具体名称，不导出正文、个人资料、标签或附件。系统日历副本可能进入 iCloud / Google / 厂商云端，需在系统日历单独修改或删除；本版没有双向同步或自动导入其他日历。

Android 用官方 `ACTION_INSERT` 打开日历编辑器，无需读取整个日历；闹钟由用户在系统页面确认。iOS 使用 EventKitUI，iOS 17+ 由系统编辑器处理保存，旧版仅在主动添加时申请日历权限。Windows 和浏览器导出符合 RFC 5545 的 `.ics` 文件，支持 UTC 时间、UTF-8 折行及提醒。

静档内提醒使用已有本地通知组件。Android 设置中可主动申请精确提醒权限，未授权时降为普通通知并提示；iOS 使用本地通知。通知默认隐藏具体内容，有无声音仍受静音、勿扰和系统限制影响。iOS 不能任意将第三方应用设为系统默认日历，本版提供的是个人计划界面和系统日历添加入口。Android/iOS 原生桥接及通知需在真机继续验收，浏览器演示不发送系统通知。

### 启动 Supabase

安装并启动 Docker Desktop（Linux 容器），然后使用 Supabase CLI：

```powershell
npx supabase@2.121.0 start
npx supabase@2.121.0 db reset --local
npx supabase@2.121.0 functions serve delete-account --no-verify-jwt
npx supabase@2.121.0 status
```

客户端配置采用 `status` 显示的本地 API URL 和低权限公开密钥。邮件验证码在本地邮件预览 `http://127.0.0.1:54324` 查看。确认邮件和登录邮件都已配置为六位验证码模板。

Windows 使用 `127.0.0.1`；Android 模拟器访问宿主服务使用 `10.0.2.2`。真实手机需要能访问宿主机的地址。Android 的 HTTP 例外只存在于 debug manifest；iOS 真机请连接有可信 HTTPS 证书的测试服务。

`db reset --local` 会清空本地测试数据库，已有真实资料时不要运行它。境内部署见 [部署说明](docs/deploy-mainland.md)。

## 备份与恢复

源码 0.2.3 增加[原生空档案完整恢复](docs/native-backup-restore.md)：在同账号的解锁页选择完整加密备份，验证口令/恢复密钥与所有内容，预览确认后事务写入本机；不替换非空档案、不同账号或不同密钥封装。当前导入上限 64 MiB，真实换装和云端恢复仍待验收；此前交付的 0.2.2 APK 不包含这一入口。

在“设置 → 导出完整加密备份”保存 JSON 快照，包括记录、待同步修改、冲突版本和引用的附件。联网后先尝试同步；离线导出的范围以本机缓存为准，未缓存且无法下载的附件会使导出失败，不会输出缺少附件的快照。

备份不包含明文主密钥。独立解密不依赖服务端，需 Node.js 22+：

```powershell
npm ci
node tool/decrypt-backup.mjs backup.json recovered-archive
# 忘记口令时，在提示中输入恢复密钥：
node tool/decrypt-backup.mjs backup.json recovered-archive --recovery
```

输出目录必须不存在。工具隐藏口令输入，将记录写为 `records.json`，附件按随机 ID 命名并保留安全的扩展名；原始文件名保存在记录里。**输出目录是明文，请自行妥善保管。** 口令或恢复密钥需与对应备份配套保存；改口令后，旧备份仍使用旧的口令/恢复密钥。

## 检查

```powershell
npm ci
npm test
flutter analyze
flutter test --reporter expanded
deno test --node-modules-dir=none --allow-env=SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,SUPABASE_ANON_KEY --lock=supabase/functions/deno.lock supabase/functions/delete-account/index_test.ts
```

- Node 测试在嵌入式 PostgreSQL/PGlite 中实际执行迁移和 RLS，用最小 Auth/Storage 表夹具验证跨账号隔离、CAS、重复请求、墓碑和删除。它不替代运行完整 Supabase 后的接口联调。
- Flutter 测试验证本机 SQLite、离线重试、上传过程中继续编辑、冲突处理、中文富文本和小屏布局；`crypto_test.dart` 运行真实原生 libsodium。
- `.github/workflows/verify.yml` 提供 Windows/Linux/macOS 检查及对应平台构建。配置文件已写入，尚未在远端运行。

本次环境已验证的范围与尚需联调的内容见 [验证记录](docs/verification.md)。
本轮接入原项目的差异、完整流程检查与限制见 [原 Flutter 界面接入记录](docs/native-ui-integration.md)。

## 当前边界

- 同步在前台在线时订阅更新，并每 30 秒及恢复前台时对账；不承诺应用关闭时立即同步。
- 单附件上限 20 MiB，使用带版本头的二进制认证密文上传；标题和原文件名保留在加密记录中。
- 每台设备安排最近 60 项本地提醒，打开应用会重新安排；Android 使用非精确提醒，可能被系统省电策略推迟。
- 本机缓存全部持久化为密文；用户选择的源文件、系统通知时间以及用户主动生成的外部预览副本属于设备侧可见信息。预览缓存下次启动清理，导入后调用文件选择器清理临时文件。
- 删除记录保留墓碑。为保护尚未同步设备上的修改，已上传的无引用附件密文暂保留到删除账号时统一清除；本机取消的附件草稿不进入上传队列。
- 账号删除会先阻止新访问，再删除附件和账号关联数据。中途失败可重试。远程离线设备、用户导出文件和运维历史备份需按各自保留策略清理。
- 服务端仍可见账号邮箱、对象 ID、版本号、密文大小及请求信息。端到端加密不防范已经受控的终端或恶意客户端更新；尚未完成独立安全审计，不应直接用于公开运营。

第三方组件说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 每日任务的数据准备

已预留按日期发布的共用任务表，详见[每日任务配置](docs/daily-tasks.md)。仅提交本地迁移与权限测试；没有部署、任务内容、撕页动画或客户端接入，私人内容继续使用现有端到端加密记录。

## 原声随笔（本地录音，不识别）

随笔编辑器 → **留一段原声** → 主动开启麦克风 → 结束录音 → 试听 → 加入这篇随笔 → 保存。也可以只留声音，不填写正文；标题、标签和已有富文本仍可编辑。回看时点附件播放，支持暂停与拖动进度。没有新增目的地或账户设置。

- 使用 record 7.1.2 采集内存 PCM，44.1kHz / 单声道 / 16bit，封装为 WAV；单段最多 2 分钟，约 10.1 MiB。录音处理关闭自动增益、降噪和回声消除请求；设备系统仍可能处理麦克风信号，须实机试听。实际格式被硬件调整时拒绝保存错误格式，避免回放变速。
- 首次点击“开始录音”才请求麦克风权限。拒绝、空录音和放弃均不改原有正文。录音结束后可试听；加入失败保留当前录音供重试。加入后仍需保存这篇随笔。
- 退出前台、设备音频中断时结束采集，保留已录片段供本人确认；不自动继续录音或后台录音。锁定档案、关闭录音窗口时释放设备并清理应用持有的音频缓冲。尚未加入/保存的录音不具备崩溃恢复能力。
- 原声复用现有 Attachment、密文缓存、离线队列、冲突处理和完整加密备份；音频文件名在加密记录内。**没有新数据格式或数据库迁移**。旧客户端可保留、备份这个普通附件，但不具备新增的内置回听界面。
- 播放仅在主动点击后读取解密数据。Android/Windows/Web 使用 audioplayers 6.8.1 的内存字节源；iOS 使用 AVAudioPlayer(data:) 的原生通道，避开该包在 iOS 的明文临时文件转换。关闭播放器、切后台、锁定档案会停止并释放应用持有的解密缓冲；不能保证操作系统或编解码器内部副本立即归零。
- 现有“添加附件”仍可选择已有音频；WAV、M4A、MP3、AAC、OGG、FLAC 进入应用内回听，具体编码兼容性取决于平台解码器。不能播放时原件仍保留。
- 不调用在线 AI、不转写、不推断声音中的情绪、不发送日记上下文，不需要豆包密钥。先前尚未部署的识别网关、配额/去重迁移和客户端入口已撤下；未操作真实数据库。键盘自带听写由用户自行决定，其联网行为由所用键盘/系统控制。
- 开启现有云同步后会上传**加密音频**，仍产生存储与流量；没有语音识别 API 费用。按标题/正文/标签搜索，不检索声音内容。随笔文本/JSON 导出不包含音频原件；完整原声归档使用现有加密备份。

平台准备：Android RECORD_AUDIO、iOS NSMicrophoneUsageDescription、Windows MSIX microphone 已配置。record 与 audioplayers 的实际版本锁于 pubspec.lock，原始许可随 Flutter 汇入开源许可页。

实际检查和未验证范围见 [验证记录](docs/verification.md)。本机源码修改不代表 7357 演示页自动更新，也不代表原生安装包已验收。
