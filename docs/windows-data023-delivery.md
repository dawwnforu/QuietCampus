# Windows 0.2.3：原生恢复测试包

2026-11-02。继续原 Flutter 项目；原生入口 `lib/main.dart`，版本 0.2.3+5，Release 模式、明确 `APP_ENVIRONMENT=test`，连接原新加坡 Free 联调服务。不是生产候选、MSIX 安装器或商店上架包。

## 下载与使用

[本人 Google Drive：静档 Windows 云同步测试版 0.2.3，完整解压](https://drive.google.com/file/d/1XEbFm4xsoGizn5GHS0fR1A1N2PNR-rdO/view?usp=drivesdk)

ZIP 回读 36,019,482 字节，shared=false，仅 owner；没有公开共享。最初上传因授权只明确覆盖安卓而被自动审批拒绝，本人随后明确许可 Windows 包私有上传，才重新调用连接器完成。

1. 完整解压到独立文件夹，保留旧版；运行其中的 `quiet_campus.exe`，不要只复制单个 EXE。
2. 在当前账号处核对邮箱，使用与手机相同的测试邮箱和独立加密口令。切换账号用保留资料的“切换账号”，不要卸载或清缓存。
3. 使用唯一的虚构标题核对两端原文与修改回传；同步提示只说明本机与服务对账，不证明另一端已经收到。

新增完整备份导入见[原生恢复说明](native-backup-restore.md)。当前只恢复同账号、相同密钥封装、64 MiB 内的备份到本机空档案；不要删除旧资料来满足条件。

## 实际构建与核验

- 调试构建 116.7 秒通过，独立保存在 `build/desktop/QuietCampus-Windows-DebugQA-0.2.3`；不作为本页下载包。
- Release 测试构建 129.6 秒通过，EXE 资源版本为 0.2.3+5。包内 53 文件，包含 Flutter、插件、4 项清单登记的原生库、数据资源、3 个官方 MSVC Release 运行库和使用说明。
- AOT `data/app.so` 核对到原生 main、恢复代码、原测试端点和客户端公开密钥，没有 DemoController；只记录布尔比较结果，不回显配置值。原生库清单不含临时 Q: 路径，登记的库均在运行目录中。
- ZIP SHA-256：`252f9808d8003f5c8049eb1b0e0ea37dba49b92d364179e8531e09eb579594c5`。
- EXE SHA-256：`78ff2e5bc8743ab70d739d958c443aae16a1832f2bc1a2ba9422019d59b4c7e6`。
- 27 项相关 Flutter 检查、7 项 Node 检查及静态分析通过；它们不是完整安装包/云端验收。

构建中保留了旧 CMake 输出；项目缓存内的目录联接解决插件链接权限，使用同一项目的非根目录别名 Q:/app 后构建通过。没有修改系统安全设置、复制成第二套项目或移除原生构建钩子。生成配置已恢复原字节，自建 Q: 盘符已移除。

## 运行库与未验项目

按实际二进制导入补入 MSVCP140.dll、VCRUNTIME140.dll、VCRUNTIME140_1.dll，来源是本人已有 Visual Studio Community 的官方 Redistributable 目录，不包含 Debug CRT。微软运行库的分发须遵守相应 Visual Studio 许可；参见[微软分发说明](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files?view=msvc-170)。

附带的 JNI 库仍引用 jvm.dll（旧包也含该库），本轮没有无开发工具的干净 Windows 运行证据，不能把静态清单检查扩大为所有运行时依赖验收。不预先要求安装 Java；如启动或文件操作出现 JVM 错误，保留原状并反馈。

没有启动此包读取本人的现有缓存，也没有实测文件选择、恢复、原声、系统权限或 Android↔Windows 同步。系统拦截或组件错误应记录后处理，不关闭系统保护。正式签名、境内生产服务、真实设备、商店认证与公开上架仍待完成。
