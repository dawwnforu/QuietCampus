# 原生中英文与无障碍检查

更新：2026-11-02。S04 的源码工作已进入 [0.2.4 测试包](native-data024-delivery.md)；此前已交付的 0.2.3 不包含本页新增改动。新包构建不代表真机功能已验收。

## 已接入原项目

- `lib/main.dart` 复用已有语言作用域和中文 / 英文词表。登录、解锁、设置、恢复和主界面可切换语言；选择保存在现有系统安全存储的 `quiet-campus.language` 项中。读取或保存偏好失败不阻塞档案，未增加账号服务或数据表。
- 登录、口令验证、备份预览、同步状态与错误提示按界面语言显示。邮箱、标题、正文、标签、附件和原始 Delta 不翻译；切换语言不重建编辑器、不清空草稿或口令。此项语言偏好不随档案同步。
- 原生首页标明“云同步测试版”，不再复用浏览器的“浏览器本地版”标记。版本、账号、恢复入口继续沿用原有位置。
- 390 像素宽、双倍字号检查发现账号栏横向溢出，`AccountPanel` 已按可用宽度 / 字号改为上下排列；连接失败页允许滚动，长口令帮助文字允许多行。
- 加密、数据库格式、同步协议、权限申请时机及原有账号切换行为没有变化。小兔仍为本机规则，不是端侧模型。

## 实际检查

使用本机 Windows Flutter 测试引擎；认证、录音、通知和播放器使用明确的替身，不连接真实账号或申请本人系统权限。

| 测试文件 | 不同用例数 | 验证范围 |
| --- | ---: | --- |
| native_language_test.dart | 4 | 原生应用根入口、语言持久偏好、口令和编辑草稿保留；390×844 双倍字号首页 / 设置；登录页按钮标签、Android / iOS 最小点击目标、自动文字对比度检查 |
| account_auth_test.dart | 5 | 账号切换、输入校验及失败后保留、显示隐藏；夹具明确设为中文，保留原行为断言 |
| native_backup_restore_test.dart | 7 | 原有真实加密 / SQLite 恢复检查；恢复对话框的中文和英文大字号交互 |
| app_language_test.dart | 4 | 原文与占位符保持、类型搜索、语言切换保留富文本和标签 |
| document_editor_test.dart | 5 | Markdown 快捷输入、中文组合输入、撤销、富文本保存、布局切换与草稿 |
| record_search_test.dart | 6 | 精确 / 分散字符命中、规范化、摘要和全部导出，高亮不写回原始内容 |
| audio_notes_test.dart | 9 | 原声录制 / 播放 / 保存失败重试；拒绝麦克风、取消、锁定和后台处理，不改原富文本 |
| reminders_test.dart | 2 | 精确提醒退回普通提醒；拒绝通知后仍可通过实际 ArchiveController、libsodium 和临时 SQLite 保存密文及待同步队列，不发送通知 |
| responsive_ui_test.dart / home_navigation_test.dart | 2 | 宽窄屏导航 / 编辑与侧栏隐藏，设置仍在账户位置 |

上述 44 个不同用例均通过，按组运行，不将重复运行累计。新增通知检查初次因测试插件单例尚未初始化而失败，修正夹具后两项通过，没有放宽产品权限或修改保存逻辑。原生语言检查此前发现的真实账号栏溢出已修复并回归通过。

本地命令：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test-native.ps1 test/native_language_test.dart test/account_auth_test.dart test/native_backup_restore_test.dart test/app_language_test.dart
powershell -NoProfile -ExecutionPolicy Bypass -File tool/test-native.ps1 test/document_editor_test.dart test/record_search_test.dart test/audio_notes_test.dart test/reminders_test.dart test/responsive_ui_test.dart test/home_navigation_test.dart
```

该 Windows 本地检查入口只接受已存在的项目测试文件，拒绝外部路径；复用项目 SDK 与依赖缓存，以同项目临时 Q:/app 联接绕过中文路径工具链问题。保留原生构建钩子，结束恢复四份生成配置并移除自建别名。若 Q: 已占用则停止，不替换已有盘符。8 项 Node 检查包含路径拒绝与配置未改动检查。

## 尚未验证

- Windows 0.2.4 已在当前开发电脑启动到锁定档案页，读取到语言 / 账号 / 恢复控件，未解锁或操作真实资料，窗口部分被另一应用遮挡。Android 安装包静态核验通过，未连接实机；未运行 Mac / iPhone。新的交付状态见 [0.2.4 入口](native-data024-delivery.md)，不以该启动检查替代完整设备验收。
- 自动对比度和点击目标检查覆盖登录页，不能代表所有页面、真实字体和全部状态达标；系统读屏、键盘焦点遍历、真实中文键盘、录音听感、通知权限和高字号全流程仍须设备验收。
- 小兔已有“减少动态效果”分支，但本轮未做真实系统开关验证。配置缺失 / 原生初始化失败时的 `SetupApp` 仍为中文；系统通知文本及个别未收录的错误不在完整双语承诺内。
- 真实同账号双设备同步、旧签名换装恢复和正式发行条件仍未通过。本次没有解锁本人档案、改服务或上传任何内容。
