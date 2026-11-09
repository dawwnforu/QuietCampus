# 原生 0.2.4：SDK、权限与数据流清单

核对：2026-11-02。适用于原 Flutter `lib/main.dart` 的 Android 0.2.4+6 和 Windows 0.2.4+6 测试包；iOS 一栏仅为源码核对。用于准备商店表单和隐私说明，不是已提交的声明或检测认证。

版本取自 `pubspec.lock`；用途与触发点取自当前调用代码。组件许可由 [第三方声明](../THIRD_PARTY_NOTICES.md) 和包内“开源许可”另行列出。下面区分本机软件组件、实际联网服务和用户主动交给系统/其他应用的内容，不将每个开源作者都写成接收日记的服务商。

## 组件及本项目的调用范围

| 组件 / 锁定版本 | 本项目用途与处理数据 | 触发 / 去向 |
| --- | --- | --- |
| supabase_flutter 2.18.3；supabase 2.16.5；gotrue 2.27.3 | 邮箱验证码、认证会话；读写账号密钥封装；服务器可见账号及必要网络信息 | 启动时恢复已有认证会话、本人登录；访问编译配置指定的认证服务，客户端没有 SMTP 密码或管理员密钥 |
| postgrest 2.9.1；realtime_client 2.13.2；storage_client 2.8.1；functions_client 2.7.1 | 密文记录、附件、版本、对象 ID、删除标记、账号归属及变更订阅；账号删除须另行重新验证 | 沿原 Supabase 项目接口工作；开启会话和档案后按原同步逻辑对账，不将搜索词、原始 Delta 或解密口令作为接口参数 |
| sodium 4.1.2 / libsodium | 独立口令派生、主密钥封装、记录与附件加解密 | 本机处理；云端仅收到封装和密文。不会上传口令、恢复密钥或明文主密钥 |
| sqlite3 3.7.1 / SQLite | 本机记录密文、附件密文、待同步队列、冲突和必要元数据 | 本机分账号数据库；不是整文件 SQLCipher。SQLite 结构、必要同步元数据与封装参数不应宣传为每个字节均已加密 |
| flutter_secure_storage 11.2.0；Darwin 0.4.3 / Windows 4.2.2 | 认证会话、本人选择保存的设备密钥、语言偏好 | 系统安全存储；不作为开发者可读的云端设置表，不将密钥写入导出诊断 |
| file_picker 13.1.0；android_file_picker 2.1.1；file_selector_windows 0.9.3+6 | 本人选中的原件/名称；保存导出与备份 | 主动导入或保存时调用。Android 普通/自定义文件类型使用系统文档 URI 授权；导入附件与材料的 finally 中调用清理选择器临时文件。系统文件提供方本身可能是用户选用的云盘 |
| open_filex 5.0.0 | 用户确认后用外部应用打开部分 Office / 文本附件 | 唯一调用在 `lib/app.dart`，先将选定附件写到本应用私有预览缓存。不是扫描外部存储；外部查看器取得的是用户确认交出的明文副本 |
| record 7.1.2；Android 2.2.0 / Windows 2.3.0 / iOS 2.1.1 | 主动录制的原声 PCM 流，形成 WAV 附件 | 点击录音才检查麦克风权限；先在有上限的内存缓冲处理，再经原附件接口加密。拒绝权限可继续写字，不做识别或转写 |
| audioplayers 6.8.1；Android 5.3.0 / Windows 4.4.1 | 播放本人打开的解密音频字节 | Android 使用 BytesSource / ByteDataSource，Windows 使用内存流。iOS 改走本项目 AVAudioPlayer(data:) 桥接。源代码不使用在线音频 URL 作为原声播放入口；实际听感、释放和系统行为仍待设备验收 |
| pdfrx 2.9.0；pdfrx_engine 0.7.4；pdfium_dart / pdfium_flutter 0.4.0 | PDF 字节渲染、图片本机预览 | `PdfViewer.data` 接收已解密字节，PDF 链接回调不跳转。原生 PDFium 的构建期下载与用户运行时上传文档是不同过程 |
| flutter_quill 11.6.0；characters 1.4.1；unorm_dart 0.3.3；url_launcher 6.3.3 | 富文本、选区、用户输入与粘贴、字素及本机搜索高亮 | 仅本机文档处理；高亮不写回 Delta 或导出。Quill 超链接可能交由系统浏览器打开，不应把用户主动打开的外部链接称作静档的私有云接口 |
| flutter_local_notifications 22.3.2；Windows 3.1.1；flutter_timezone 5.1.1；timezone 0.11.2 | 本人设置的提醒时间、设备时区及泛化通知文案 | 本地系统提醒；不上传提醒正文。默认系统通知不显示用户标题/正文，精确提醒可选 |
| TableCalendar 3.3.0；本项目系统日历桥接 | 应用内日期；主动导出时提供时间、可选日程名称和提醒 | Android 打开系统日历编辑器；iOS 使用 EventKitUI；Windows 导出 .ics。系统日历可能随用户的系统账号同步，不是静档双向日历同步 |

正文/标题/标签/原始文件名在解锁内存中可见，保存到档案和同步前使用原加密层。用户明确导出的明文 JSON、文本、日历文件以及确认交给其他应用的预览副本是例外，不宣称它们仍受原档案加密保护。导入和预览缓存处理见下方边界。

## 最终 Android APK 的实际权限

本轮再次用 aapt 读取最终 APK：包名 `cn.quietcampus.quiet_campus`，versionCode 6 / versionName 0.2.4。不是仅查看源 Manifest。

| 最终声明 | 用途 / 来源 | 用户触发 |
| --- | --- | --- |
| INTERNET | 邮箱认证与原密文同步 | 已配置服务的原生客户端联网；与账号/解锁状态相关 |
| RECORD_AUDIO | 原声录制 | 点击开始录音后请求；可拒绝 |
| POST_NOTIFICATIONS | 本地待办通知 | 主动开启提醒时请求；可拒绝 |
| RECEIVE_BOOT_COMPLETED | 设备重启后由通知组件重新安排已有提醒 | 不用于后台持续录音；实际厂商限制待实测 |
| SCHEDULE_EXACT_ALARM | 可选安卓精确提醒 | 另行系统授权；未授权时采用普通提醒 |
| VIBRATE | 通知组件合入的提醒振动能力 | 不用于采集个人资料；实际通知配置和系统设置影响效果 |
| cn.quietcampus.quiet_campus.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | AndroidX Core 1.18.0 合入、signature 级内部接收器保护 | 无需用户开启，不是读取通讯录/媒体库的权限 |

最终包没有 READ_EXTERNAL_STORAGE / READ_MEDIA_IMAGES / READ_MEDIA_VIDEO / READ_MEDIA_AUDIO。这四项原由 open_filex 合入，0.2.4 已在应用 Manifest 移除并重建核验。没有为移除权限更换文件库或修改加密层；真实手机选择器和外部预览仍待检查。

Android 日历采用 ACTION_INSERT，无 READ_CALENDAR / WRITE_CALENDAR 声明；返回“已打开编辑器”不代表已保存事件。iOS 17+ 源码直接展示 EventKitUI，旧版本调用 requestAccess(to: .event)，不能把所有 iOS 版本都描述成相同的“仅写入权限”。应用代码不枚举用户其他日历，旧系统授权范围及实际弹窗需在 iPhone 核对。iOS 有麦克风/日历用途说明，最终合并隐私清单尚待 Xcode 构建。Windows MSIX 配置只有 internetClient / microphone，但当前交付为 ZIP，不是已签名 MSIX。

## 联网服务与明文例外

| 场景 | 交出什么 | 当前状态 |
| --- | --- | --- |
| 原生认证 / 密文同步 | 账号邮箱、认证请求、密文和必要对象/版本/网络元数据 | 0.2.4 编入原新加坡 Free 测试项目，只用虚构资料；正式境内服务商、域名、地域、日志与保留期尚未确定 |
| 验证邮件 | 收件邮箱、验证码及验证邮件内容 | 联调曾由本人配置 QQ SMTP；授权码只由服务端配置保存，客户端包不包含。正式发信方案及接收方披露待运营者确认 |
| 外部文档预览 | 本人选择的单份解密文件 | 先确认，再写本应用临时目录并交给系统查看器；本应用预览目录下次启动时清理，不会自动撤回第三方查看器另存的副本 |
| 系统日历 / 文件导出 / 外部链接 | 用户确认的时间、可选名称、选定文件或点击的 URL | 交由系统或用户选择的应用；这些副本和外部服务依各自设置处理 |

小兔讲述和搜索仍在本机处理。本项目没有接入在线 AI、广告或统计服务；不能据此把真实表单中的账号、云存储和已传输数据都预填为“无”。正式填写以实际生产配置、候选包、表单定义和真机流量检查为准。

## 供复核的源码与剩余项

调用依据：[main.dart](../lib/main.dart)、[cloud.dart](../lib/cloud.dart)、[controller.dart](../lib/controller.dart)、[audio_notes.dart](../lib/audio_notes.dart)、[calendar_export.dart](../lib/calendar_export.dart)、[material_preview.dart](../lib/material_preview.dart)、[Android Manifest](../android/app/src/main/AndroidManifest.xml)、[iOS AppDelegate](../ios/Runner/AppDelegate.swift)。权限合并报告确认 VIBRATE 来自通知插件、内部接收器权限来自 AndroidX。

本轮核对源码、锁定版本和实际 APK，没有读取本人日记、导出数据库或捕获真实用户流量。正式提交前仍需：真机检查拒绝权限与文件/原声操作；确认 iOS 最终隐私清单和平台日志/缓存行为；填实运营主体、服务商/域名、保留期限及联系渠道。SDK 的异常日志也需用虚构内容检查，不能把本清单当成完整运行时隐私审计。
