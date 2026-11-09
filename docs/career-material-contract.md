# 静档 → 履历胶囊：求职素材契约对照与接入条件

更新：2026-11-02。首发不依赖该联动。当前只定义契约和虚构样例，未增加界面、服务器、账号映射或真实传输。

本人已提供仓库：[dawwnforu/resume-capsule](https://github.com/dawwnforu/resume-capsule)，以及可读本机源码 `C:/Users/Dawn/Documents/ChatGPT/简历更新系统/resume-capsule`。2026-11-02 已只读核对该目录的 README、C01/C04、认证、D1/R2 存储、导入与在线 AI 路由、契约纯函数及测试源码。`.git/HEAD` 指向 `codex/resume-workflow-fixes`；以下依据本机工作区，不代表 GitHub main 或线上版本。没有运行接收端脚本、读取配置秘密或个人数据库，也没有修改接收端。

## 已确认的差异

| 项目 | 静档现状 | 履历胶囊现状与源码依据 | 接入结论 |
| --- | --- | --- | --- |
| 认证 | Supabase 账号与独立档案解锁 | `lib/auth/workspace-user.ts` 验证 resume_session；localhost 可回退 local-user | 两套账号；同邮箱不构成配对，local-user 不能作为生产身份 |
| 内容存储 | 本机及 Supabase 保存密文 | `db/schema.ts`、`lib/workspace/d1-repository.ts` 直接存取 extractedText、summary、sourceQuotes；`lib/files/r2-object-store.ts` 将文件 bytes 写入 R2 | 接收端服务器可读内容，当前不满足静档选定素材的端到端保护要求 |
| 在线 AI | 私人记录不自动发往在线 AI | `app/api/workspace/ai/organize/route.ts` 可把 source 传给已配置供应商 | 当前路由未提供静档来源的隔离规则；禁止复用作素材接收入口 |
| 普通导入 | quiet-campus-notes-v1 可包含全部日记与 Delta | `app/api/workspace/import/route.ts` 接收文件、服务端解析并保存 | 不把全随笔导出传给现有导入接口 |
| 专用关联 | 本文旧草案，无适配器 | `lib/integrations/quiet-materials-contract.ts` 仅 strict schema 和纯函数预览；app/lib 引用检索未见真实路由调用 | 双方没有可用的关联链路；合成演练不是账号配对或加密传输 |

接收端 C04 同样将客户端加密存储、私有缓存/索引、认证配对/撤回、全部在线调用点禁止静档来源列为前置条件。服务器加密 API 凭据、账号权限隔离、HTTPS 都不能替代内容的端到端加密。本轮保持真实关联关闭，不为接入而降低静档的隐私边界。

## 范围与授权

默认无关联。只接受用户选定的经历/项目及明确选择的证明摘要；日记、证件、原声、个人情绪和全材料库不自动共享。`grant` 字段只表达产品内授权范围，不是认证令牌或服务器可直接信任的凭据；接收端必须独立验证已认证的本人、源和目标账号及实际授权。

不直接共用数据库或管理员权限，不共享静档档案主密钥，不按邮箱自动合并账号。接收端客户端保护与真实配对完成之前，不用私人内容做联调；小兔生成内容也不随素材自动流转。

## 双方字段尚不兼容

下方保留静档最初的 `quiet-campus-career-materials / 1` 草案及样例，作为历史设计，不是已支持的接口。接收端 C04 实际使用另一套 **`dawwn-quiet-materials / 1` 提案**，尚未获得双方实现支持；不能因为 version 同为 1 就互相导入。

| 静档旧草案 | 接收端纯函数提案 | 后续适配要求 |
| --- | --- | --- |
| sourceApp / targetApp、grant、items[] | transferId / pairingId / grantId、sourceAccountId / targetAccountId、单个 record | 每条记录独立预览；UUID 及账号绑定来自真实已认证上下文，不能接受调用方自行声明 |
| sourceRevision / sourceUpdatedAt | record.sourceRevision / sourceMutationId / updatedAt | 从同一份本机 SealedRecord 与已解锁 Entry 快照取值；revision 不能区分同 revision 的离线变化。已有 mutationId 可用，缺失时不伪造 |
| selectedFields、description | record.fields 中实际存在的 title / summary / role / organization | 字段白名单；description 映射为经本人确认的 summary，不直接把正文或小兔回应当成事实；organization 在 Entry 中无独立字段，未确认就省略 |
| eventDate / sourceCreatedAt | record.occurredOn / createdAt | Entry 没有通用经历事件日期；默认 null，经本人确认后才填，禁止套用记录创建日、提醒日或截止日。时间戳使用 UTC，事件日期按本人确认的本地日 |
| experience / project | experience / project / award / proof | 静档先只考虑 experience / project；接收端枚举不等于静档已有 award / proof 类型，不将材料分类直接改成新记录类型 |
| evidenceRefs（ID、名称） | originals（UUID、fileName、contentType、bytes、sha256） | Attachment 只有 id/name/size，不足以生成接收端描述符；MIME/哈希及原件选择需单独校验，不能伪造或隐含授权。原件字节、URL 均不在该纯函数载荷内 |
| 无请求有效期 | issuedAt / expiresAt，最长 10 分钟 | 认证层还须验证授权期限、请求期限、签名与防重放；布尔 authenticated/unlocked 只用于合成演练 |

接收端已有四项测试源码，覆盖合成预览、字段/原件独立选择、重复/版本变化、拒绝越权和无网络/持久化依赖。本轮只阅读，没有运行，不将其计为本轮测试通过；没有真实身份、加密缓存或双进程验收证据。

## 接下来的最小流程

1. 先在履历胶囊任务中完成接收端私密存储及来源隔离：正文、文件名、原件、索引/缓存均不能经现有 D1/R2 明文通路，静档来源不能进入任一在线 AI 或其他外发路径；独立测试失败、中断和旧数据兼容。该目录本轮只读，不跨项目擅自实施。
2. 双方确定一个契约后，静档在解锁状态下读取明确选择的经历/项目，生成独立事实预览，字段和原件分开选择，保持原 Delta、附件及本机库不变。先只用合成资料，未同步/冲突/缺失版本身份的记录暂不发送，不伪造版本。
3. 实现两侧已认证配对、短期授权与加密传输，再验证重复、乱序、过期、撤回、跨账号和来源更新。接收端先展示差异，由本人确认进入求职素材；不覆盖简历或投递历史。源更新不能自动扩大字段范围。

上述是实施顺序，不是已启用功能。静档发行不依赖该联动，继续沿用独立安装包与数据层。

## 历史草案：最小载荷（已发现与接收端不兼容）

| 字段 | 意义 |
| --- | --- |
| format / version | 固定 quiet-campus-career-materials / 1；未知版本拒绝，保留输入包 |
| sourceApp / targetApp | quiet-campus / resume-capsule；不能由此推断身份可信 |
| grant.id / selectedRecordIds | 本次授权标识与明确选定的源记录，扩大范围需再次确认 |
| items[].sourceRecordId | 稳定源记录 ID；接收端以已验证的源账号映射 + 该 ID 去重，不按标题去重 |
| sourceRevision / sourceUpdatedAt | 已确认的源修订号与更新时间；离线待同步版本须另定版本策略，不能伪造服务端确认号 |
| kind | 本版只允许 experience / project；获奖可先以本人选定经历与证明表达，不推断新类型已实现 |
| selectedFields | 本人明确选择的字段；不列出的字段不得偷偷带上 |
| title / description / role | 本人确认的事实摘录，不能直接取小兔回应作为事实，也不自动补数字 |
| eventDate | 实际事件日期；不知道则 null，不能用 createdAt 冒充 |
| sourceCreatedAt | 原始写入时间，与事件日期分开 |
| evidenceRefs | 明确选择的材料引用 ID 和本人确认的展示名称；不含原件和下载 URL，不默认授予文件访问 |

原始 Delta 不修改；选定描述作为独立素材，不把高亮或 AI 结果写回源内容。传输封装、接收端加密缓存、密钥授权和安全失效机制尚未实现；本样例是合成明文结构，不是可以直接上传私人材料的生产格式。

## 同步、版本和撤回

同源同修订重复传入不新增副本；较新修订展示变化供本人确认，用户改写的简历与历史投递版本不被覆盖。版本倒退、源冲突或未同步状态进入待处理，不用客户端时间替代并发控制。

源删除、授权过期或撤回后停止新增读取，明确提示接收端副本的保留/删除选择；不能自动撤回已导出或已投递简历。离线和中断保留当前资料，不静默回滚或删除已有求职素材。

未来实现必须验：无授权/跨账号拒绝、少字段/额外字段、未知格式、重复和乱序、源删除、字段扩权、断网中断、撤回后停止读取、本人编辑优先及导出原文不被污染。静档尚未实现验证器或接收 API；接收端只有另一格式的合成预览纯函数，不能把样例存在算作真实连接测试通过。

## 合成结构示例

```json
{
  "format": "quiet-campus-career-materials",
  "version": 1,
  "sourceApp": "quiet-campus",
  "targetApp": "resume-capsule",
  "grant": {
    "id": "fictional-grant-001",
    "selectedRecordIds": ["fictional-project-001"]
  },
  "items": [{
    "sourceRecordId": "fictional-project-001",
    "sourceRevision": 2,
    "sourceUpdatedAt": "2026-11-02T09:00:00Z",
    "sourceCreatedAt": "2026-10-20T09:00:00Z",
    "kind": "project",
    "selectedFields": ["title", "description", "role", "eventDate", "evidenceRefs"],
    "title": "虚构课程项目",
    "description": "完成课堂演示并整理使用说明。",
    "role": "负责界面与演示文档",
    "eventDate": null,
    "evidenceRefs": []
  }]
}
```

示例没有真实账号、证件、密钥、人物或下载地址。已有 quiet-campus-notes-v1 全随笔导出不包含材料库元数据和原件，也没有上述授权语义，不能直接当作此契约的生产接入。
