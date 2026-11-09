# 网页首版推进与证据

目标来源：本人提供的 goal-objective.md；完整范围包含 A–E、价格实验、交付与首批采用，不因某段代码或截图通过而缩小。

## 当前盘点

| 范围 | 当前权威证据 | 尚缺内容 |
|---|---|---|
| 原项目 | 本仓库 Flutter；Git 尚无提交，既有文件均未跟踪；不重置工作区 | 最终作者、名称、整体产品授权待本人确认 |
| 视觉/交互 | lib/theme.dart、rabbit_avatar.dart、archive_home.dart；docs/previews；主要中英文界面与390px Chrome实操 | 手机实机、完整无障碍、边缘英文文案复核 |
| 内存演示 | lib/demo.dart + DemoController；实测新增、修改、关键词查找与重置；已独立读取桌面13篇示例JSON | 先前14篇场景的导出文件未定位；手机实机 |
| 原生档案 | lib/main.dart/controller.dart/local_store.dart/cloud.dart；0.2.1本机包 | 真实跨设备、恢复与多账号隔离仍有验收缺口；不作为网页本地版成功证据 |
| 备份 | 新增 BackupArchive 预检、全对象认证及 BrowserArchiveController 恢复；Chrome已实际下载并在7361空来源预览/确认恢复 | 带真实网页附件的恢复、移动端和异常恢复界面仍需验收 |
| 网页真实存储 | lib/browser.dart 复用原 ArchiveHome；IndexedDB 原子密文快照；已构建主要中英文版，并刷新找回测试记录 | 手机实机、带附件恢复、完整交付验收仍未完成 |
| 自由记录与时间 | 本地日期已用设备时区；原repo/r75未见16点限制和晚间提醒 | 核对已接受的原始实现；证据未找到前不回退已有自由记录 |
| 发布/收款 | 本机ZIP、静态托管ZIP、欢迎/说明/许可页；本地模拟交付及重复去重已验；域名/HTTPS条件已有官方依据 | 真实托管访问、本人地区/主体适用审核、平台收款资格与最终条款审阅；没有公开发布或收款 |

实施前范围见 [一页交付说明](web-first-sale-scope.md)。

## 必须逐项取得的证据

1. 浏览器新增、持久保存、刷新/重开与解锁、统一搜索高亮、编辑不污染其他内容。
2. 保留富文本、材料/附件、活动与标签关联；标签管理留在随笔，展示超限再展开。
3. 完整加密导出、格式/版本/大小校验、预览、隔离恢复、损坏不覆盖、重复导入不重复。
4. 同源并发窗口写入和失败状态有明确行为；不静默覆盖或自动重建正常资料。
5. 主要界面和使用说明中英文，切换不丢输入；本地日期、键盘与窄屏可操作、减少动态效果。
6. 有明确合成数据的体验入口、手机落地页、版本/来源/许可证说明、可运行文件及启动命令；公开URL没有则明确待部署。
7. 商品说明与真实能力一致，价格/支持边界待本人确认；国内/海外各一候选渠道有官方证据或明确未知。
8. 现金与人工成本分列，免费/0.01/覆盖成本方案比较后仅推荐一个本轮方案，未来收入含零成交可能。
9. 无真实付费授权时只有标明模拟的交易与重复履约检查，不把成功页当付款凭证。
10. 真实邀请文案、任务路径、观察步骤与中英文宣传稿可用；实际参与者/订单/到账保持真实数值，当前为0。
11. 未经批准不部署公网、不购买/签约/收款/联系他人、不迁移真实账号；不读取或上传私人正文与凭据。

## 已查技术证据

- sodium 4.1.2 支持 Web 和现有密码算法；Web须另外打包匹配的 sumo JavaScript 资源；JS内存清理保证与原生不同：[版本文档](https://pub.dev/packages/sodium/versions/4.1.2)。
- IndexedDB按来源隔离并支持事务；默认仍可能被回收，持久存储申请不替代用户备份：[IndexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)、[配额与回收](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria)。
- 当前SDK为 Flutter3.47.7，不能照抄较新文档仅3.50+支持的内容哈希参数；构建和托管以实际产物与当前SDK检查：[官方Web发布](https://docs.flutter.dev/deployment/web)。

这些来源支持实现选择，不构成已完成的运行/发行证据。后续每一项按实际测试、浏览器操作与交付产物补证。

## 2026-10-26：本地网页开发增量

- 新入口 `lib/browser.dart`；与 `lib/demo.dart`、原生 `lib/main.dart` 分开启动，复用原 Flutter 页面、Quill、模型、加密格式和标签管理。没有连接 Supabase，也没有修改原生数据库。
- `BrowserSnapshotStore` 保存完整密文快照，写入需匹配当前存储版本。不同页面竞争时，过期写入被拒绝；失败不先更新内存中的原记录。不是多设备同步。
- `BackupArchive` 校验格式/v1、原始记录v1/v2、固定KDF参数、重复标识、密文认证和附件完整性；未来版本拒绝，不自动重建数据库。导入界面先验证/预览，已有资料须先下载完整备份后才能确认整体替换，不做隐式合并。
- 当前浏览器实现采用整份快照：加密 JSON 上限64 MiB、单附件20 MiB、单记录密文封装上限2 MiB。它们不是原生库新限制；大型原生备份超限时拒绝导入并保留原文件。原生同步修复不能以此浏览器恢复冒充完成。
- 密钥只在已解锁内存中；退出/锁定需重新输入。创建档案时提供恢复文件。下载完成只代表浏览器完成下载动作，仍须用户确认另存。浏览器资料受来源、配额、回收和清理影响。
- `sodium:update_web` 已下载并校验 sumo 0.8.4，固定上游提交 `a79e5ddbbcfd130e27dcbbda1b5ba072c7a9787d`；构建结果使用本地 sodium.js 和 CanvasKit，不依赖在线加密脚本。
- 浏览器JS版本的 Argon2 运行在当前线程，解锁期间可能短暂阻塞界面；这不是后台AI或原生安全内存保证。
- 原编辑器补上正文语义标签和聚焦动作；不会把正文转成纯文本。完整屏幕阅读器与中英文验收仍待完成。

### 已取得的测试证据

1. 原生实际 sodium：`flutter test test/backup_archive_test.dart test/crypto_test.dart --no-pub --no-test-assets --reporter expanded`，7项通过。包含原格式/富文本/附件/冲突、恢复密钥、错误口令、篡改、缺文件、未来格式拒绝。
2. `flutter test test/browser_archive_controller_test.dart --no-pub --no-test-assets --reporter expanded`，4项通过。覆盖重建控制器后解锁读取、隔离恢复、重复导入、失败保留资料、多窗口拒绝覆盖、标签关联和墓碑。
3. 真实Chrome IndexedDB：`dart --disable-dart-dev --packages=.dart_tool/package_config.json .tooling/pub-cache/hosted/pub.dev/test-1.31.1/bin/test.dart test/browser_snapshot_store_test.dart --platform chrome --reporter expanded --timeout 30s`，4项通过。使用独立临时测试浏览器，测试重开、过期版本、竞争写入和无效写入不覆盖。
4. `flutter test test/document_editor_test.dart --no-pub --no-test-assets --reporter expanded`，5项通过。新增语义聚焦动作后，通过实际编辑事件保存Markdown富文本；其余为既有布局/草稿保护/撤销回归。
5. 最终 `dart analyze` 覆盖新增入口、存储、控制器、解析器、共用编辑器及三个对应测试文件，无问题。
6. 六组相关回归合跑：`flutter test test/document_editor_test.dart test/browser_archive_controller_test.dart test/record_search_test.dart test/tags_test.dart test/backup_archive_test.dart test/crypto_test.dart --no-pub --no-test-assets --reporter expanded`，29项通过；加上上面的真实Chrome存储4项，共33项不同测试取得通过证据。最终正文/标题语义修改后又单独跑编辑器5项通过，不重复累加测试数量。

浏览器测试经历：原 Flutter Web 测试运行器停留在加载，人工停止且没有测试通过；普通 `dart test` 被无关 PDF 原生构建钩子的本机VS编码问题阻断。改为直接运行现有纯Dart测试入口，未修改SDK/第三方源码，并在真实Chrome上取得4项结果。不能把前两次失败当成通过。

### 当前运行入口

构建：`pwsh -NoProfile -File tool/build-web-product.ps1`。

启动：`node tool/demo-server.mjs build/web-product 7360`。

本机档案入口：`http://127.0.0.1:7360/`；合成示例入口：`http://127.0.0.1:7360/?demo=1`。仅绑定127.0.0.1，不是可供外部手机访问的公开地址；手机仍需获准部署到稳定HTTPS来源。原7357演示未替换。

当前真实网页操作已验证：

- 内置浏览器：新建档案、错误确认口令保留输入、下载虚构恢复文件、标题保存后刷新重新解锁找回。其完整正文输入路径没有取得最终通过证据。
- Chrome：新建独立虚构档案，保存34个非空白字符的测试正文；中文关键词找到并在打开的原文中看到高亮；刷新后重新解锁，原文仍一致。没有把DOM输入框的值当成保存证据，均打开实际记录核对。
- 从Chrome设置下载完整密文备份，文件实际落在下载目录；只含一个虚构记录，格式quiet-campus-backup/v1，未出现测试正文的明文。
- 本机另启7361来源，实际看到空档案入口后选取该备份；输入测试口令、查看1对象/0附件/0冲突的预览并确认，恢复后打开原文一致。未覆盖7360资料。
- 恢复副本刷新后仍可解锁，再编辑标题为“隔离恢复后编辑标题”，保存后列表和详情标题一致，正文及34字符统计保留。原来源不随副本编辑变化；不把来源隔离称为云账号隔离。

本轮正文可访问性修复过程：最初只有Quill子段落语义，新增外层输入后发现焦点仍落在内部段落，界面控件的值未进入文档。最后由单一正文语义节点提供完整文本及编辑动作、与FocusNode同步状态、请求Quill键盘连接并排除重复子节点。语义编辑只替换变化的字素范围，周围Delta格式保留。中文输入实操和语义/虚拟键盘Markdown回归分别有证据；完整TalkBack/VoiceOver及材料嵌入朗读尚未验证。标题最终使用标准TextField装饰标签，去掉重复语义包装。

操作证据：`docs/previews/web-local-search-proof.png`、`web-isolated-restore-proof.png`、`web-restored-edit-proof.png`。后两者分别是恢复后原文与编辑标题后保留正文；不是手机实机或云同步证据。

交易证据与未知项已整理至 `docs/web-sales-channels.md`：小红书与Gumroad各一候选，资格/品类/费用/最低金额/售后/提现按官方证据分别记状态；没有确定本人的收款资格，不开通或伪装已售。试用邀请、中英文文案和观察步骤见 `docs/web-pilot-kit.md`；`web-pilot-observations.csv`只有表头，参与者/订单/到账仍为0。

仍未完成：完整中英文界面与使用说明、落地页和示例完整流程、普通用户打包/启动与版本清单、完整浏览器/移动和带附件验收、部署地区的域名/HTTPS及适用义务核查、模拟交易交付、最终商品/支持/授权边界审阅。用户真实试用与收款没有发生。目标保持A–E全范围；不标记公开或首售就绪。

## 2026-10-26：中英文主流程增量

本段更新上面的历史“仍未完成”状态；没有缩小原A–E目标。

- 新增 `lib/app_language.dart`，只处理已知界面文案与占位参数。私人标题、标签、正文、原始Delta和导出数据不翻译；参数按一次替换，用户写下的`{count}`不会再次被当成模板。
- 浏览器记录、编辑、标签、活动日历、材料和备份主要流程接入中英文。选择的语言仅作为非敏感本地偏好保存，不依IP自动切换。原生入口仍默认中文；没有重打Android/Windows包。
- 语言控制由页面内的 `ArchiveLanguageScope` / `ArchiveLanguageSwitch` 提供。第一版放在Navigator外虽可见，但Chrome实际可访问性树没有按钮；已移进实际页面和编辑器。没有借“翻译”重建编辑器或清空草稿。
- 搜索可传入当前显示的类型标签，命中范围对应该标签；英文界面仍可用原中文类型别名找回，但不伪造别名在英文文字里的高亮。原标题/正文/标签的精确、分散字符和重复匹配沿用原实现。
- 小兔试讲及其20条独立动作有英文呈现，仍为本机确定规则，不宣称AI理解或自动翻译用户内容。不新增网络推理、日志或数据迁移。
- 材料删除提示改为复用实际存储层的删除说明；本地版不再宣称删除会同步到其他设备。示例页删除说明也明确只影响内存演示；冲突选择提示不再无条件承诺恢复到云端。
- 新增 [中文使用说明](web-user-guide.zh-CN.md) 和 [English guide](web-user-guide.en.md)，覆盖入口、私人与演示区别、口令/恢复、记录、标签、原声、搜索、加密/明文导出区别、隔离恢复、来源绑定及失败保留资料。

### 本次实际验证

最终代码运行 `flutter test test/app_language_test.dart test/document_editor_test.dart test/record_search_test.dart test/tags_test.dart test/rabbit_story_test.dart --no-pub --no-test-assets --reporter expanded`，**27项通过**。其中新增4项测试证明：占位内容不递归替换；显示类型的匹配范围正确且导出不污染；390px界面切换保留同一个编辑器State、富文本、选中及未完成标签、标题并能保存；英文搜索与窄屏三入口导航不重置查询/改写资料。旧中文组件测试补上明确中文locale，未放宽数据断言。首次测试发现档案页英文隐私说明横向溢出，已加可换行约束后重跑通过。

`dart analyze lib test/app_language_test.dart test/tags_test.dart test/rabbit_story_test.dart` 无问题。最终 `tool/build-web-product.ps1` 成功，`main.dart.js` 为5,795,348字节。构建仍提示既有CupertinoIcons字体未打包；没有把该警告计为全面图标验收通过。

真实Chrome仅使用7361隔离来源中先前的虚构档案：

1. 解锁后在实际编辑器使用键盘将标题改为“双语草稿 Save <A&B>”，选中`#bilingual`，另输入未完成`#draft`；切换中英文后确认这些输入仍在。
2. 保存后实际打开原文，标题与两个标签一致，原34个非空白字符正文仍为先前虚构内容。没有只看DOM输入框的值就声称保存成功。
3. 刷新、重新解锁后标题/标签/正文仍在；英文`journal`检索找到该记录，界面类型和小兔回应中的实际英文匹配均有高亮。小兔展示不替代打开的原文。
4. 实际窄屏确认 `innerWidth=390` 且 Flutter可见视图宽度=390，取得 `docs/previews/web-english-mobile-proof.png`。先前运行中更改设备仿真尺寸时曾发生视图裁切；刷新确认真实尺寸后才取得最终截图，不把前一张裁切图算作适配通过。已恢复浏览器默认尺寸。
5. 新打开同来源示例页仍为英文，明确显示合成资料、刷新重置、13篇示例；语言偏好不要求账号。该示例没有被算作真实用户或云端持久保存。

### 剩余验收与下一段

主要界面和两份说明已具备；仍有边缘文案、示例工具按钮及部分读屏标签需复核，不能称完整国际化/无障碍验收通过。编辑器已有标题在Chrome树中仍表现为无名称textbox；正文有明确标签，完整读屏修正还需独立验证。390px桌面仿真不替代Android/iPhone真机。

下一段优先接上原Flutter的手机优先落地/使用说明入口与清楚的合成示例路径，完成普通用户可运行的交付包和版本清单；随后补带附件/异常恢复、模拟交付及部署条件的证据。未公开部署、未购买、未联络参与者、未接真实支付；真实参与者、订单、到账仍为0，目标保持active。

## 2026-10-26：欢迎页、解压启动包与备份确认

### 实际交付

- `tool/web-product/welcome.html` 是原项目的同源欢迎页，介绍记录/找回/备份，区分合成示例与自己的浏览器档案。没有另建HTML记录系统；两个主入口仍进入原Flutter `lib/browser.dart`。
- 英文/中文欢迎页共用一套页面，语言偏好与Flutter一致，不按IP切换。日期使用本地日；提供可见焦点、跳到正文、语义化标题和触摸按钮，减少动态设置会取消装饰性旋转。
- `tool/prepare-web-product.ps1` 将既有Markdown说明渲染为 `guide.zh-CN.html` / `guide.en.html`，另有 `privacy.html` 草案、`licenses.html` 和 `release.json`。当前入口 `http://127.0.0.1:7360/welcome.html` 不是公众地址；原 `/` 不变，没有迁移或清空IndexedDB。
- 欢迎页直接用原完整字体会加载约22MB；现为固定文案制作原OFL字体的WOFF2子集，改名Quiet Portal Sans / Display，两份共230,932字节。原Flutter完整字体未替换，原版权/许可证保留。生成工具只在项目工具目录安装，没有全局安装或加入用户运行依赖。
- `tool/package-web-product.ps1` 生成Windows x64本地验收包，带官方Node.js24.22.1与完整LICENSE、只监听127.0.0.1的静态服务、启动cmd、原Flutter网页及说明。Node来源与官方SHA256已核对，详情见 `docs/web-delivery.md`。不要求普通使用者安装Skill、Codex、Flutter或Node。
- 版本候选标识 `web-local-20261026.1`，来源为原项目 `0.2.1+3`、无Git提交的当前工作树。最终包：`build/delivery/QuietCampus-Web-Candidate-20261026-142541.zip`，69,956,015字节。此前134137/135114时间戳的包为中间候选，不能当作最新修复包。
- 已从这个最终ZIP实际解压，核对元数据与文件边界，再运行其 `Start-QuietCampus.cmd`，当前7360由解压包自带运行文件提供。原7357未替换。网页中没有原生测试项目标识或Supabase秘密密钥前缀，包内没有本地数据库、配置密钥文件或档案备份。该检查不是完整安全审计。

### 新发现与修复

1. 已填写标题在浏览器树里曾没有名称。改成标准浮动标签，正文仍沿用Quill；Chrome实际创建和编辑后能看到“标题（可以不填）”标签。新增语义断言及原编辑器回归通过，没有增加重复输入代理。
2. 示例页的刷新按钮不再叫“同步”，明确为“刷新示例视图”；英文单条统计改成 `Notes: 1`，不把示例展示当真实同步。
3. 锁定的FilePicker网页实现可能发起下载后返回null，旧的恢复前备份门槛因此无法可靠判断。现在支持的浏览器优先显示保存对话框，不支持时保留下载方式；只把已安装的file_picker_web4.2.0从传递依赖声明为直接依赖，没有升级版本。
4. 恢复预览中导出目标档案后，必须由本人核对文件并勾选“我已核对并保存当前档案的完整加密备份”才可整体替换。保存请求、函数返回或点击按钮不会自动放行。错误不提供确认框，新请求会重置确认；原加密、备份格式、CAS及异常不覆盖机制没有改变。

### 本次证据

- `node --test test/web-delivery.test.mjs`，2项通过。实际HTTP覆盖UTF-8、HEAD、拒绝POST、编码路径越界、目录链接越界、非预期Host；再次启动遇到占用端口会退出，原服务仍响应。沙箱内创建测试链接被操作系统拒绝后，在已授权项目测试范围内重跑成功；未放宽服务器校验。
- 最终回归：`flutter test test/app_language_test.dart test/document_editor_test.dart test/record_search_test.dart test/tags_test.dart test/rabbit_story_test.dart test/backup_confirmation_test.dart test/backup_archive_test.dart test/browser_archive_controller_test.dart test/crypto_test.dart --no-pub --no-test-assets --reporter expanded`，**40项通过**。包括下载完成不自动确认、失败不放行、确认可撤销、原富文本、标签、搜索、加密、恢复和失败保留资料。加上上面的Node测试，本次最终取得42项不同测试通过；不与历史重复累加。
- `dart analyze lib test/app_language_test.dart test/backup_confirmation_test.dart` 无问题；最终网页构建成功，`main.dart.js`5,799,168字节。既有CupertinoIcons字体警告仍存在，不宣称全面图标验收。
- Chrome 390px实际查看欢迎页、切换英文、打开英文说明并进入原Flutter示例。标题/正文/操作入口可用，无横向页面溢出；截图 `docs/previews/web-welcome-mobile-proof.png`。不是手机实机证据。
- 从解压包实际服务进入示例：13篇→新增虚构“交付示例演练-1026”变14篇；正文含中文和`<A&B>`。修改标题后打开原文仍一致；正文关键词“虚构示例”实际筛为1篇，导出确认仍显示全14篇；重置后回到13篇并清除该示例。没有操作真实本地档案。
- 自动化未取得该次下载的完成事件或落盘文件，不能把14篇确认框当作导出文件完整性证据。浏览器策略禁止打开内部下载页，未绕过。后续本人按当前欢迎页的示例导出步骤回复“文件已保存”，记为**本人确认文件保存成功**；默认Downloads、Desktop、Documents未定位到匹配新文件，因此尚未独立核对该文件的内容/位置。此状态与早先另一次加密备份已下载/隔离恢复的证据分开记录。

### 仍需继续

标题标签和原样例刷新按钮已修正，但完整读屏、物理手机、带附件的网页恢复/错误恢复界面仍待验收。下一段继续补这些证据、模拟交易交付、实际静态托管的域名/HTTPS与适用义务，以及最终商品/支持/授权审阅。

窗口启动器已实际运行，自动拉起默认浏览器未单独取得证据；手动复制控制台URL已可访问。没有在干净Windows新机器验收。用户已确认的导出不重复要求，但也不把未读到的文件内容写成独立校验通过。

真实拉新参与者、订单、收入、到账均为0；本人协助验收不计采用或销售。没有公开部署、购买、签约、设置收款、发帖或联络他人。A–E完整目标保持active，尚不宣称首售就绪。

### 桌面导出文件复核补充

本人随后明确保存位置为桌面。已只读核对 `C:/Users/Dawn/Desktop/静档全部随笔.json`：8,834字节，UTF-8 JSON可解析，格式为 `quiet-campus-notes-v1`；共13条记录、13个不同ID，每条均有可读取的Delta操作结构。此文件不含先前新增/修改的“交付示例演练-1026”标记，与重置后的13篇示例规模一致，不能替代此前14篇导出的文件证据。当前可确认示例导出实际落盘并可读取；这是明文随笔导出，不是包含附件原件的完整加密备份。文件未修改、移动或上传，参与者及销售统计不变。

## 2026-10-26：附件恢复回归、模拟交付与待托管文件

上轮桌面导出复核属于取得文件内容证据的实际进展。本轮继续原A–E范围，没有重新定义完成条件。

### 附件与异常恢复

新增 `test/browser_attachment_restore_test.dart` 的3项测试通过，采用原BrowserArchiveController、BackupArchive和实际libsodium；没有修改加密算法、数据格式或用户数据库。测试生成64×64几何PNG并实际解码、1秒低音量合成PCM WAV，不含真人照片或声音。完整加密备份→独立控制器恢复→锁定/重开→编辑标题后，原Delta及两份原件字节一致；备份不含所检查的标题、标签、文件名明文。未来格式、缺文件、篡改附件、截断JSON均拒绝，已有持久快照与可读原件不变。

仅用于人工界面验收的随机新目录 `build/qa/browser-attachments-65adfac1/` 含valid/missing/future JSON和公开虚构测试口令说明，不进入交付/托管目录。测试输出不是生产数据。

真实Chrome另启7363隔离来源，看到空档案入口；文件选择自动化未使界面进入口令/恢复预览，没有取得附件恢复后的UI证据。实际页面仍为空入口，控制台无捕获错误，也没有可见系统文件对话框。停止这条自动化分支，没有绕过浏览器安全策略或通过隐藏状态写入IndexedDB。因此**3项测试不能代替网页附件恢复、图片显示或音频播放验收**。原7360/7361及7357未被覆盖，浏览器已回到7360欢迎页。

### 模拟交付

`tool/rehearse-web-delivery.mjs` 只在本地使用SIM虚构订单与模拟服务商查询，不连接支付/邮件接口。实际使用69956015字节的Windows候选ZIP运行，输出 `build/qa/delivery-rehearsal-20261026-1/REHEARSAL.json` 及一份带说明和模拟凭据的交付副本。返回页参数不足以交付；匹配结果仅交付一次；重复调用及重新加载脚本通过磁盘凭据去重。中断后有文件无凭据时停止并保留，不把部分拷贝当完成。

`node --test test/web-fulfillment.test.mjs test/web-hosting.test.mjs`：4项通过，包含上面的交付3项，以及构建目录1项。与Flutter附件测试合计本轮新增7项，不与历史重复相加。`dart analyze test/browser_attachment_restore_test.dart` 最终无问题。

模拟不是获准售价，不是平台真实回调、退款或到账测试；详见 `docs/web-delivery-rehearsal.md`。真实用户、订单、收入、到账仍均为0。

### 托管准备

新增 `docs/web-hosting-readiness.md`，按2026-10-26官方说明核对一个纯静态托管候选、免费额度、默认域名与自有域名、HTTPS、源站变更备份迁移、访问元数据以及大陆备案/许可适用条件。本人主体/地区与业务分类仍待相应接入及主管部门确认，不用境外托管推断豁免；没有购买或部署。

`tool/prepare-web-product.ps1` 增加复制Pages `_headers`，仅no-store/nosniff/no-referrer。构建目录79文件、74728005字节，均小于25MiB单文件限制且少于控制台1000文件；目录检查未混入测试备份、数据库或runtime。平台是否实际应用响应头仍未验证。

新待托管静态ZIP：`build/hosting/QuietCampus-Static-Review-20261026-154309.zip`，33448817字节；已打开核对ZIP根部含index.html和_headers，含目录共87条，无Windows runtime/QA演练文件。它只用于审阅和后续获准的静态部署，不能双击启动，也不是Windows解压运行包的替代。Windows最新可运行包仍是 `QuietCampus-Web-Candidate-20261026-142541.zip`；7360由该解压包服务，build/web-product中的headers准备不冒充已更新到运行包。

剩余：真实浏览器带附件恢复/异常界面、手机实机及完整辅助技术验收；确认产品署名/授权/支持条件、适用主体与渠道资格，之后才可能获准公开部署和邀请。目标保持active，未达到首售就绪。

## 2026-10-27：恢复7363测试入口

本人反馈打不开。实际检查：旧服务进程句柄已不存在，7363连接失败；源构建目录在此前失败构建后留下未注入sodium.js的index.html，不能当作可用版本继续服务。新启动的源目录服务已停止，改以已验收的 `build/delivery-check-20261026-142541/QuietCampus-Web-Candidate-20261026-142541/site` 启动7363。HTTP核对入口为浏览器本地版、含加密脚本，main.dart.js/flutter_bootstrap.js/sodium.js均200；实际页面显示仍待本人确认。端口和来源未变，没有清理或迁移浏览器资料。以后重启此测试来源应优先使用该已验收目录，源构建目录须成功重建后再采用。

补记此前暂停前状态：作者署名由本人确认DAwwN，运营方向中国大陆；已写入说明和构建脚本，尚未打成新包。备份单选参数不符合所锁定FilePicker接口，未通过构建且已撤回，不作为已实现或已验收。最新可用Windows包仍是142541候选。
