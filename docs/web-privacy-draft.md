# 浏览器本地版数据说明 / Local edition data notes

**预发布草案，适用于本交付包的浏览器本地版。尚未公开运营，不是原生账号同步版的隐私政策。**

## 中文

你写下的标题、正文、标签、活动、材料原件和原声使用现有档案格式在本机加密，保存在当前浏览器、当前站点来源的 IndexedDB。独立口令和恢复密钥不发送给账户后台；本地版不连接 Supabase，不要求注册。

解锁后的内容与解密能力会存在当前页面内存中，供编辑、搜索和预览使用；锁定后需要重新解锁。界面语言偏好是单独的非敏感本地设置。不会把日记、提示词或小兔讲述发送给在线AI，也没有自动云端推理回退。

应用不设置广告统计或日记内容日志。网页仍会向提供它的服务器请求程序、字体和预览资源；未来实际托管者可能处理IP地址、访问时间和请求路径，须在选定运营主体、托管地区及服务后补充说明。当前本机启动器只绑定127.0.0.1，不接收其他设备访问，不记录访问日志。

浏览器清理、存储回收、隐私模式、换浏览器/设备/域名可能造成资料不可访问。请定期导出完整加密备份，并在隔离环境核对恢复。自动备份和跨设备云同步不在本地版范围内。开发者无法在所有解锁途径丢失后恢复内容。

“导出全部随笔”和单篇文本是明文，由本人选择保存；它们不含完整材料原件。系统日历导出可能交给本人使用的日历云服务；原声录制只在主动操作并允许麦克风后开始，不转写。向其他应用打开文件时会产生解密副本，须自行管理该应用保留的内容。

删除记录使用本地墓碑，现有密文和已导出备份不会自动物理擦除；在正式使用前须理解这个范围。不把清空浏览器或删除全部资料作为修复方案。

公开运营前，需要本人确认运营者身份、联系方式、部署地区、数据保留/删除说明和适用的投诉处理入口。当前没有用户招募、公开发布或收款，也没有凭空设置客服邮箱。

## English

**Pre-release draft for the local browser package. This is not the privacy policy for the native account-and-sync clients. No public operation has begun.**

Titles, writing, tags, activities, original materials and voice recordings use the existing encrypted archive format in IndexedDB, tied to this browser and site origin. The local edition does not connect to Supabase or require an account. Archive passphrases and recovery keys are not sent to an account backend.

Unlocked content and keys are available in page memory for editing, searching and previewing. Unlock again after locking. The interface language is a separate, non-sensitive local preference. Writing, prompts and rabbit responses are not sent to online AI, and there is no automatic cloud inference fallback.

The app does not add advertising analytics or journal-content logs. Browsers still request program files, fonts and preview resources from the server providing the site. A future host may process IP addresses, times and request paths; those details must be stated once the operator, host and region are selected. The current local launcher binds only to 127.0.0.1 and does not keep access logs.

Browser cleanup, eviction, private mode or a change of browser, device or domain can make data unavailable. Export complete encrypted backups regularly and verify a restore in isolation. Automatic backups and cross-device cloud sync are not included. If all unlock methods are lost, the developer cannot recover the archive.

Notes JSON and single-note text exports are unencrypted and do not include all original material files. You choose where to save them. Calendar export may reach your calendar provider’s cloud. Recording starts only on your action and microphone permission, with no transcription. Opening files in another app can leave decrypted copies that you must manage there.

Deleting a record writes a local tombstone; existing ciphertext and exported backups are not automatically physically erased. Understand this scope before relying on deletion. Clearing the browser or deleting all data is not a repair procedure.

Before public operation, the owner must confirm the operator identity, contact, hosting region, retention/deletion terms and complaint channel. No public launch, recruitment or payment has taken place, and no support address has been invented.
