# 安卓与 Windows：Supabase 免费联调

最新已交付测试版为 [Android 0.2.3](android-data023-delivery.md) / [Windows 0.2.3](windows-data023-delivery.md)，沿用相同测试服务。下方包大小和 0.2.1 / SyncTest 下载记录保留为历史；真实双向同步仍待验收。后续[原生中英文源码](native-language-accessibility.md)已进入 [0.2.4 测试包](native-data024-delivery.md)，最新交付以该页为准。

核对日期：2026-10-23。继续原 Flutter 项目，保留本机加密、恢复密钥、离线队列和冲突处理。

## 目前进度

| 项目 | 状态 |
|---|---|
| 安卓交互预览包 | 已上传到本人 Google Drive，132,659,899 字节，未共享；重启重置，不用于长期记录 |
| 原生完整客户端 | 最新 SyncTest 包已编入真实 Free 测试服务配置；Preview 和旧 unconfigured 包不用于本次验收 |
| 数据库、附件权限、写入 RPC | 两份原迁移已在全新云测试库的事务中执行成功；8 项云端配置核查通过，尚非两账号实际联调 |
| Supabase Free 测试项目 | quiet-campus-test 已创建，状态 Healthy，新加坡 ap-southeast-1；组织仍为 Free |
| 账号删除函数 | 已部署；本人另明确授权关闭旧密钥网关检查，保留原函数用户验证及最近登录要求。GET 为 405，无登录 / 无效令牌 POST 为 401；未执行删除 |
| 发信 | QQ SMTP 与两种 OTP 模板已保存并回读；本人反馈 Windows 已收到验证码、登录成功 |
| 客户端公开配置 | config.local.json 已建立，仅 HTTPS URL 与 publishable key；实际公开 API 可达，匿名读 records 返回 401 / 42501 |
| 数据版安装包 | Windows ZIP 36,884,299 字节；安卓 APK 175,761,284 字节已上传本人 Drive、未共享，签名与预览版一致，ARM64 原生依赖齐全；登录、持久保存、跨设备同步待实测 |
| 真实安卓–Windows 同步 | 本人已澄清安卓尚未看到记录；2026-10-24 提醒手机登录邮箱未确认，可能与 Windows 不同。尚未进行同账号跨端验收 |

[安卓预览包（本人 Drive）](https://drive.google.com/file/d/1XA4aa_54_gO32SXsHyrrZZeJMnR5yKWp/view?usp=drivesdk)。手机使用同一个 Google 账号下载。不需要开启公开共享。

**历史数据版入口（0.2.1）：** [安卓 AccountFix（本人 Drive）](https://drive.google.com/file/d/1xKKr42VxEqFGxdA4qFpkg9k-qsLrmix8/view?usp=drivesdk) · [Windows AccountFix ZIP](../build/desktop/QuietCampus-Windows-AccountFix-0.2.1.zip)。它们是原 lib/main.dart 客户端，服务配置已编入，增加当前邮箱和保留资料的账号切换；两端需确认同邮箱后验收同步。旧 SyncTest / Preview 包仍保留，不要继续用重启重置的 Preview 包做持久保存测试。安卓上传后元数据回读为 135,824,559 字节、shared=false。

## 这次免费测试的范围

选择官方 Free 云项目，不购买服务器、域名、SMTP 或其他服务，不绑定付款方式、不升级套餐。这是设备联调环境，大陆正式发行仍按 [境内部署说明](deploy-mainland.md) 单独准备。

官方当前列出的托管区域没有中国大陆；测试项目可选明确的 Singapore / Southeast Asia (Singapore)。即使档案密文在境外，账号邮箱与同步元数据仍由该服务处理。只输入虚构日记、虚构证件附件，不导入真实个人档案。

Free 当前提供 500 MB 数据库、1 GB 文件存储；闲置一周会暂停，不能承诺长期可用性。以创建项目时控制台和[官方价格页](https://supabase.com/pricing)为准；出现付费选项时停下，不自动升级。

未配置自有 SMTP 的平台默认邮件仅发送到项目组织的团队邮箱，限每小时 2 封。本项目现已配置 QQ SMTP，不再要求收件邮箱是组织成员；两端请选择同一个本人测试邮箱，不反复点击发送验证码，也不要为了发信授予他人管理权限。见[官方 SMTP 说明](https://supabase.com/docs/guides/auth/auth-smtp)。

**本次控制台发现的实际限制：** 2026-06-03 后新建 Free 项目使用默认邮件服务时，不能修改邮件主题和正文；当前默认模板只有登录链接，不能直接满足现有应用的数字验证码流程。该项目必须先配置自有 SMTP 才能编辑 OTP 模板；不升级 Pro，也不绕过邮箱验证。依据[官方变更公告](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier)。此前“直接在 Free 默认发信中改模板”的准备步骤在此项目不适用。

### QQ SMTP 配置步骤（本人已完成，留作操作记录）

1. 登录 [QQ 邮箱](https://mail.qq.com/)，在“设置 → 账户”或新版“账号与安全 → 第三方服务”开启 SMTP，按网页要求生成授权码。验证和授权码生成由本人完成，不将授权码发给协作者。
2. 返回已经打开的 [Supabase SMTP 页](https://supabase.com/dashboard/project/eeeeisvdrcvjgmjtobgp/auth/smtp)：Sender email address、Username 都填完整的 QQ 邮箱；Password 填该邮箱的 SMTP 授权码，而非邮箱登录密码。已预填 Sender name 为“静档测试”、Host 为 smtp.qq.com、Port 为 465，保持加密连接。原先准备的 163 字段须由本人替换，不混用两家的授权码。
3. 本人点击 Save changes，成功后回复“SMTP 已保存”。这会让本人的 Supabase 测试项目通过该邮箱发送登录邮件；只用于少量联调，不承诺正式公开发信容量。出现收费或错误时停下反馈。

本人截图确认两个完整 QQ 邮箱字段相同，smtp.qq.com / 465 正确；此前“缺少 @”判断已撤回。本人随后确认 Save changes 成功，本轮独立新开模板页不再显示 SMTP 配置限制，source 可编辑，证明自有 SMTP 配置已生效。未读取 Password 或代本人提交凭据。配置生效不等于邮件送达通过。

SMTP 启用提示的默认额度为每小时 30 封，本轮未提高。QQ 邮箱仍可能限流或拒绝连接，需要邮件实测。Confirm sign up 主题为“创建静档账号的验证码”，Magic link or OTP 主题为“静档登录验证码”；两者均使用原 `supabase/templates/otp.html`，显示 `{{ .Token }}`，保存后刷新核对全文一致。8 位、600 秒设置沿用；预览中的占位符不是实际验证码。保留邮箱确认与禁用匿名登录。

### 当前实测进度（本人操作与云端核查分开记录）

Windows 已交互启动最新数据版 `build/desktop/QuietCampus-Windows-SyncTest/quiet_campus.exe`，检查到窗口标题 quiet_campus、非零窗口句柄及 Responding=true；启动日志仅见渲染器信息。尚未观察或代输入登录凭据。当前 `adb devices -l` 没有连接设备，安卓请用上方 Drive 的 SyncTest 包正常更新，不卸载、不清数据。

本人反馈 Windows 已收到验证码、登录并显示“已同步”；随后澄清安卓并未看到记录，先前选择的跨端成功选项不作为验收结果。2026-10-24 本人补充手机登录邮箱未确认，可能与 Windows 不同。协作者此前两次通过同一测试项目 SQL Editor 执行只读汇总，均得到 accounts=1、vaults=1、records=0、active_records=0、max_revision=NULL；未读取账号邮箱、原文、密文值或密钥。没有记录时 envelope 聚合 false 不能解释为存在明文或加密失效。

因此先用 [0.2.1 账号入口](account-auth-ux.md) 核对两端“当前登录邮箱”；如不同使用保留本机资料的“切换账号”，不要清缓存、卸载或重新建库。确认同账号后，再新建带独特标题的虚构日记并核对另一端原文与修改回传。暂不宣称完整同步通过；重启保留、离线和附件等场景尚未实测。验证码、口令、恢复密钥只在客户端输入，不发聊天。

## 第一步：本人注册（约 5–10 分钟）

1. 打开 [Supabase 注册页](https://supabase.com/dashboard/sign-up)，可通过 GitHub 登录；如使用邮箱注册，则自行设置独立密码。本人本次已使用 GitHub 登录成功，无需另设 Supabase 登录密码。
2. 本人阅读条款并提交，按邮件提示完成验证。密码、验证码不发到聊天。
3. 进入控制台后告诉协作者“已进入控制台”。先不填写银行卡、不购买套餐；如果没有进入控制台，描述页面提示即可。

成功标志：进入 Supabase 的组织或项目控制台。它与将来在静档里使用的加密口令是不同的凭据。

## 第二步：建立全新、空的测试项目（本人，约 5–10 分钟）

1. 如果需要组织，建立个人组织，套餐明确选 Free。
2. 建立项目 `quiet-campus-test`，明确选择 Singapore；数据库密码由本人生成并存在自己的密码管理器，不发聊天。
3. 等待项目就绪，告诉协作者项目名和“全新空项目已就绪”。若页面收费或选择不了 Free，停下反馈。

成功标志：项目健康状态正常，组织显示 Free。这个项目专门联调，不指向已有真实用户数据库。建立项目后的配置由协作者按下述清单逐步处理；本人不需要自行猜测 SQL。

本次实际进展：本人已创建 `quiet-campus-test`，项目标识 `eeeeisvdrcvjgmjtobgp`，组织为 `Quiet Campus 测试`（Free），区域 ap-southeast-1，检查时健康。保留 Data API，关闭 Automatically expose new tables，通过原迁移显式授予访问权限。控制台仍提示平台有技术问题；遇到平台错误时先核对[官方状态页](https://status.supabase.com/)，不删除重建。

## 后续由协作者完成的配置清单

每一步分别报告实际结果；需要控制台登录、权限确认或提交时让本人接手。以下为待办，不代表已经执行。

### 数据结构

- 先确认目标 URL、项目名及数据库为空，检查平台 Auth / Storage 结构。
- 对照实际数据库预检后，在事务中按顺序执行原迁移 `supabase/migrations/202610200001_private_vault.sql`、`202610200002_daily_tasks.sql`。不在已有数据库盲目重跑；这两个文件不是可随意重复执行的脚本。
- 不运行 `db reset`，不删库、不清应用数据。迁移失败先确认事务回滚及残留状态，再处理错误。
- 检查 `vaults`、`records`、`record_mutations`、`account_deletions`、`daily_tasks` 的 RLS；客户端只经授权 RPC 写入档案。共享每日任务保持空且未发布，不写个人答案。
- 检查 `vault-attachments` 为私有桶，桶大小上限 21 MiB，MIME 为 `application/octet-stream`；客户端原始文件上限仍为 20 MiB。核对 `records` 的 Realtime 发布。不能只凭“表存在”宣称权限正确。

### 邮箱验证码

- 保留邮箱注册与确认，不改成匿名登录，也不绕过验证码。
- 在 Authentication 的 Email Templates 中，将 Confirm signup 与 Magic Link 两种模板都设为原文件 `supabase/templates/otp.html`，正文显示 `{{ .Token }}`。
- 云项目已保存有效期 600 秒，保留平台默认 OTP 长度 8；现有客户端没有硬编码六位限制，可接收八位。原本地 `supabase/config.toml` 仍是六位本地开发设置，两者独立，云控制台不会自动读取该文件。
- 先检查额度，再由本人在真实客户端请求邮件。两台设备分别登录会消耗邮件次数；超过额度先等恢复，不开付费邮件服务。
- 此流程是在客户端输入数字验证码，不靠点击邮件链接回跳应用。模板依据[官方 OTP 文档](https://supabase.com/docs/guides/auth/auth-email-passwordless)。

### 账号删除函数

- 在同一测试项目部署原 `supabase/functions/delete-account/index.ts`，函数名 `delete-account`。可以使用 Dashboard 或官方 CLI；不为此开放数据库公网端口。
- 核对网关与函数的身份验证方式。本项目 `verify_jwt=false` 必须与函数内 `auth.getUser(token)` 和十分钟内重新登录验证一起保留；不能只关闭验证而缺少原函数校验。
- 服务端管理密钥只存在函数服务端环境，不填入客户端、不发聊天。核对所需服务端变量是否由平台提供；缺少时在控制台安全配置，不打印变量值。
- 只删除明确指定的虚构测试账号，并由本人确认；不触碰已有真实账号。

### 客户端配置与重新打包

在本机 `config.local.json` 只填写下面两个值，文件已由 Git 忽略。本人可在控制台的 Connect / API Keys 页面找到；URL 和 publishable key 是客户端公开配置，仍优先保存在本机文件。

```json
{
  "SUPABASE_URL": "https://实际项目标识.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "实际客户端公开密钥"
}
```

不要照抄占位符，不用 `127.0.0.1`，不填 `service_role` / Secret Key / 数据库密码。旧式项目如果只有 `anon` 客户端公开密钥，先核对兼容性再使用，不选管理密钥。

- 保留已有配置；文件若存在先确认其指向，不覆盖其他服务配置。
- 使用 `lib/main.dart` 和 `--dart-define-from-file=config.local.json` 重建安卓、Windows 完整客户端。继续原加密机制；不用 `lib/demo.dart`。
- 现有 APK 与 EXE 不会自动从旁边的 JSON 获取配置。编译完成后给出新的包名、位置、版本与 Drive 入口。
- 保持 Android 原签名连续性。若系统报告冲突，先核对签名和旧资料；不通过卸载、清缓存、删除本机数据库解决。

## 真正同步的验收（待两端安装数据版）

每轮只让本人做最多三个动作，先进行第一组：

1. Windows 用本人测试邮箱登录，建立独立加密口令（至少 12 个字符），离线保存恢复密钥。不要发送口令或恢复密钥。
2. 写一条虚构记录，等待同步状态正常；退出程序再打开，确认还在。
3. 安卓安装同一服务的数据版，用同一个邮箱登录、同一个加密口令解锁，确认看到相同原文。

第一组通过后，再逐组验证：

- 安卓修改 → Windows 出现修改；Windows 修改 → 安卓出现修改。
- 断网记录、重启保留、恢复网络补传；附件及原声录音上传后跨端下载与播放。
- 两端同时改同一篇保留冲突副本；一端删除后旧设备离线修改不得静默复活。
- 错误口令、恢复密钥换机解锁、完整加密备份导出。备份保存在本人离线位置，不上传聊天。
- 第二测试账号隔离：数据库查询、RPC 写入、订阅及附件下载均不能获取另一账号数据。
- 检查云端只有密文和必要元数据，日志没有测试正文、原文件名、口令或密钥。不能用嵌入式数据库测试代替以上网络验收。

## 目前已验证与待验证

本轮本机运行 `node --test test/backend.test.mjs test/backup.test.mjs`，3 项通过：模拟 Auth / Storage 的 PostgreSQL 权限与写入协议、材料备份兼容、离线备份解密及篡改拒绝。

云测试项目和迁移已完成：5 张表开启 RLS、6 条本人归属策略、私有桶 21 MiB / application/octet-stream、records Realtime 发布、匿名不能读取 records、authenticated 只能通过 RPC 写入；records 和 daily_tasks 均为 0。首次核查输入时 SQL 编辑器保留了前一份代码，重复执行被“表已存在”拒绝；已改用全选删除编辑草稿，再独立执行只读核查，无删表重建。上述不是实际两账号隔离验收。

delete-account 已按本人新增明确授权部署，不执行删除。项目公开 JWKS 为 ES256；本人另外明确授权关闭仅适用旧密钥的网关检查，配置与原 config.toml 一致，函数内部仍使用 auth.getUser 和最近十分钟登录检查。实际 GET 返回 405、无登录 POST 返回 401、无效令牌 POST 返回 401；无效令牌检查走到 Auth 验证，未进入删除逻辑。尚未验证真实用户的完整删除流程，不把拒绝测试当作全部功能通过。

OTP 模板已完成并刷新回读；本人反馈 Windows 实际收信及登录成功。安卓当前账号尚待核对，暂不计同步验收通过。Free 测试不等于正式上架；暂停或故障时保留本机密文和待同步队列，不删除后重拉。

官方参考：[Free 计费说明](https://supabase.com/docs/guides/platform/billing-on-supabase)、[区域](https://supabase.com/docs/guides/platform/regions)、[Edge Functions 部署](https://supabase.com/docs/guides/functions/deploy)。
