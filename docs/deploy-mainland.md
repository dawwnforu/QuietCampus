# 境内部署与联调

客户端 → HTTPS 网关 → 境内自托管 Supabase（Auth / PostgreSQL / Storage / Realtime / Edge Functions）。

服务器只存加密后的业务内容。管理后台可维护账号与密文，没有档案解密入口和密钥托管入口。数据库凭据和服务器管理密钥留在服务端。

采用 [Supabase 官方 Docker 自托管配置](https://supabase.com/docs/guides/self-hosting/docker)，而不是将 CLI 的本地开发栈直接暴露到公网。服务器、域名、TLS、SMTP 及商业部署账户尚未配置；本仓库不会自动购买或发布服务。

## 部署本项目

1. 在自己的境内服务器部署官方 Docker 栈，使用自行生成的凭据配置 HTTPS 和生产 SMTP。只向客户端公开 API 网关，数据库端口、Studio、内部存储服务不直接公开。
2. 在 PostgreSQL 执行 `supabase/migrations/202610200001_private_vault.sql`，使用 Supabase 管理数据库角色执行一次。迁移建立密文表、写入 RPC、RLS、私有桶及 Realtime 发布配置。
3. 按 [官方 Edge Functions 自托管说明](https://supabase.com/docs/guides/self-hosting/functions)挂载 `supabase/functions/delete-account`。函数依赖服务端环境变量 `SUPABASE_URL`、`SUPABASE_ANON_KEY`、`SUPABASE_SERVICE_ROLE_KEY`。网关不做 JWT 预校验时，函数仍会用 `auth.getUser(token)` 验证真实用户，并要求最近十分钟内登录。客户端删除流程会重新校验邮件验证码。
4. 按 [自托管邮件模板说明](https://supabase.com/docs/guides/self-hosting/custom-email-templates)，把 `supabase/templates/otp.html` 放在仅供 Auth 服务访问的 HTTP 模板地址，将 `GOTRUE_MAILER_TEMPLATES_MAGIC_LINK` 和 `GOTRUE_MAILER_TEMPLATES_CONFIRMATION` 同时指向该地址。设置确认/登录邮件主题。正式 SMTP 与登录请求频率在服务端配置。
5. 客户端 `config.local.json` 只填入自己的 HTTPS API URL 和客户端公开密钥。运行 Windows、iOS 和 Android 客户端，用同一账号完成首次建库、保存恢复密钥及换机解锁。

写入协议：`put_vault(envelope, base_revision)` 使用条件版本更新密钥封装；`write_record(id, base_revision, mutation_id, ciphertext, deleted)` 使用账号内幂等标识与条件版本写入，返回成功或包含云端密文的冲突结果。普通客户端没有直接修改表或查询其他用户的权限。

## 正式接入时的验收

- 两个真实账号、两台设备检查数据库查询、RPC、附件上传/下载和 Realtime 订阅，跨账号读写均应失败。
- 断网编辑、断线后重复提交、同一记录同时修改、删除后另一设备提交旧内容，确认没有覆盖和自动复活。
- 使用管理员权限查看数据库和对象存储，检查测试记录、标签、原始文件名及证明内容没有明文；检查客户端和服务端日志没有口令或密钥。
- 确认 OTP 邮件送达；在真实系统上检查通知授权拒绝、重启、时区变化及 Windows MSIX 通知。
- 删除测试账号后，检查 Auth、vaults、records、record_mutations 及私有桶均完成清理；运维备份恢复不得恢复已删除账号的有效访问。

Windows 发布包可用 `dart run msix:create --build-windows false` 在完成 `flutter build windows --release --dart-define-from-file=config.local.json` 后打包，并配置自己的签名。Android 正式签名从被忽略的 `android/key.properties` 读取四项 `storeFile/storePassword/keyAlias/keyPassword`；缺少配置时不会自动使用 debug 签名。iOS 使用自己的开发者账号和签名配置。

公开发行前另行完成安全评审、隐私与数据保留政策、对应大陆备案和各应用商店要求；当前代码和本地测试不等于发行验收。
