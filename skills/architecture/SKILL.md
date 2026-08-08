---
name: architecture
description: 架构设计与技术方案评审。支持 design（设计）与 review（评审）双模式，涵盖术语澄清、DDD 启发式判断、多方案对比、文档拆分。可通过对应 slash command 调用，也可被 flow 编排调用。
user-invocable: true
disable-model-invocation: false
---

# 架构设计与评审

两种模式：
- **design**：基于 PRD 输出技术方案（leader 阶段③、独立调用默认）
- **review**：对已有方案做独立评审（leader 阶段④，必须不同 subagent）

被编排时通过参数/上下文告知模式；独立调用时根据用户意图判断（含"评审/审查/review"→ review），判断不清直接问。

---

## 路径约定

**模板已内置在本 skill 的 `references/` 目录下**（与 SKILL.md 同目录），随插件分发，优先使用，不依赖用户本机路径：

| 资源 | 内置路径（references/） |
|---|---|
| 技术方案模板 | `references/architecture-template.md` |
| ADR 模板 | `references/adr-template.md` |
| CONTEXT 模板 | `references/context-template.md` |
| Mermaid 示例 | `references/mermaid-examples.md` |

**Java 工程分层规范**由 flow skill 统一持有（唯一副本 `../flow/references/java-engineering-standard.md`）：

- **被 flow 编排时**：flow 探测到 Java 项目后，会把该规范完整内联进本 skill 的 prompt（见「## 团队 Java/DDD 工程规范」一节），直接按其执行，无需自行读文件。
- **独立调用 `/architecture` 时**：若判定为 Java 项目，自行读取 `../flow/references/java-engineering-standard.md` 并对照执行。

**个人知识库（通用知识 + 自定义模板）**：用户可配置本地知识库，加载规则的唯一权威副本在 `../flow/references/knowledge-base-loading.md`。要点：

- **被 flow 编排时**：flow 阶段⓪探测知识库，按阶段把命中的 `01_global/` 通用知识内联进 prompt，并告知是否有 `00_template/` 模板覆盖。直接按注入内容执行，**不要自行再读知识库**。
- **独立调用 `/architecture` 时**：按该规范解析 KB 路径（项目 `.claude/luwu.json` → `LUWU_KB_PATH` → `~/.luwu/knowledge-base/`）；若存在则读 `<kb>/index.md`，加载「适用场景/阶段」命中架构设计/评审的 `01_global/` 条目；模板优先用 index.md 中登记的 `00_template/architecture.md`、`00_template/adr.md` 等，未命中再用上表内置模板。
- 未配置知识库时静默回退，只用内置 `references/`，行为与之前一致。

**项目文档目录自动探测**（不硬编码 `doc/`）：用户指定 > `docs/README.md` > `doc/README.md` > `prd.md` 所在目录。

**必须先读文档根下的 `README.md`**，按其指引定位 PRD、架构文档、ADR 目录、迭代目录；不凭猜测写文件。

---

## design 模式流程

```
1 读 README.md → 2 加载 PRD/现有架构/ADR/CONTEXT → 3 按类别批量术语澄清
→ 4 启发式判断 DDD → 5 对齐 ADR/工程规范
→ 6 多方案对比(2-3种) → 7 输出技术方案+ADR+CONTEXT → 8 自评审 → 返回
```

### 1. 加载文档
- **首次**：PRD + 项目规范 +（Java 项目）工程规范：优先用 flow 注入的「团队 Java/DDD 工程规范」一节；独立调用时读 `../flow/references/java-engineering-standard.md`
- **调整/重构**：PRD + 现有架构 + CONTEXT + ADR + 相关代码（读关键模块，不通读）

### 2. 按类别批量术语澄清

**不要一次问一个**。一次性输出五类表格，每条带推荐答案：

```markdown
## 术语澄清（请一次性确认）

### A. 冲突术语（同一术语在不同位置定义不同）
| # | 术语 | 出处A | 出处B | 推荐统一 |
### B. 模糊语言（"高并发""高可用""支持"等）
| # | 原文 | 模糊点 | 推荐具体化 |
### C. 缺失术语（关键概念无定义，如订单状态机）
| # | 概念 | 为何需要 | 推荐定义 |
### D. 重复概念（不同词指同一事物）
| # | 术语A | 术语B | 建议统一 |
### E. 需求矛盾（需求间冲突）
| # | 矛盾点 | 出处A | 出处B | 推荐取舍 |
```

澄清后：
- 确认的术语写入 `CONTEXT.md`（参考 `references/context-template.md`）
- 量化指标回填到技术方案"需求分析"章节
- 用户表示"你定"时按推荐值执行，标注"架构师建议值，实现前二次确认"

### 3. 启发式判断 DDD

**不默认上 DDD**，按信号判断后告知用户结论和理由，等确认。

建议用 DDD 的信号（满足 ≥3 条）：有清晰领域术语表 / 业务规则复杂（状态机、多角色协作、不变式）/ 长期演进 / 团队 ≥3 人 / 明显限界上下文。

不用 DDD 的信号：纯 CRUD / 工具系统 / 一次性项目 / 团队不熟悉且周期紧。

确认用 DDD 后，按注入/持有的 Java 工程规范中的 DDD 分层与包结构执行；不用则走经典分层。

### 4. 决策对齐

设计前扫项目已有 ADR。与已有决策冲突时：记录为矛盾点，不私自改，在方案中显式说明偏离原因并建议更新 ADR。

### 5. 多方案对比

需求极明确（如"按既有架构加 CRUD 模块"）可跳过。否则提供 2-3 个方案（保守/平衡/激进），每个含核心思路、架构图（参考 mermaid-examples.md）、模块拆分、数据流、优缺点、适用场景、成本。末尾给出推荐 + 理由 + 不推荐其他方案原因 + 风险缓解。

### 6. 输出文档

位置按 README.md 指引。主架构文档参考 `references/architecture-template.md` 的章节结构，但**不要为了凑模板章节强行填写**——模板是检查清单不是填空题，按实际需求保留相关章节，不涉及的直接省略（如无消息队列则不写消息章节，单机房部署则不写多活灾备）。

**技术方案里不出现代码**——只写设计（架构图、模块职责、表结构、接口定义、状态机、数据流、选型理由等），不写 Java/TS/SQL 等具体实现代码。代码是开发阶段的产物，不是架构文档的内容。伪代码、SQL 建表语句、API 路径参数这些算设计，可以写；但完整的类定义、方法体、业务逻辑实现代码不要出现在方案里。

**主文档膨胀时必须拆分**——design.md 不是越长越好，当某一部分内容相对独立或篇幅较大时，拆成子文档独立维护。尤其是：
- 接口/API 设计（接口清单、错误码、鉴权细节通常很长）→ `design-api.md`
- 数据库设计（表结构、索引、DDL）→ `design-database.md`

其他按需拆分：部署方案、前端架构、领域模型、安全设计、性能方案等。主文档 `design.md` 保留架构总纲、选型说明、架构图、模块划分、跨章节决策，各子文档聚焦单一主题深入展开。

主文档末尾维护"详细方案索引"表格，把所有子文档链接进来：
```markdown
## 详细方案索引
| 文档 | 说明 | 最后更新 |
| design-api.md | 接口设计 | 202X-XX-XX |
| design-database.md | 数据库设计 | 202X-XX-XX |
```

ADR 按 `references/adr-template.md` 记录到项目 ADR 目录。

所有文档末尾维护"变更记录"（追加式，不覆盖历史）。

### 7. 自评审

写完后通读自查：需求是否全覆盖、术语是否一致、选型是否合理、风险是否有缓解、图文是否一致。发现问题立即修正。

### 8. design 模式返回值

被 leader 编排时**不回传全文**，只返回：
```
产物路径：
- 主架构：docs/architecture/design.md
- ADR：docs/architecture/adr/...
- CONTEXT：docs/CONTEXT.md
模式：design
结论：可进入 review
摘要（≤5行）：
- ...
```
独立调用时把摘要和路径告知用户即可。

---

## review 模式流程

```
1 读 README.md → 2 加载被评审方案+PRD+CONTEXT+ADR+工程规范
→ 3 按维度逐项评审 → 4 输出分级问题清单+修订建议+结论 → 返回
```

### 1. 加载材料
被评审方案 + 对应 PRD + CONTEXT + 项目 ADR +（Java 项目）工程规范（优先 flow 注入，独立调用读 `../flow/references/java-engineering-standard.md`）。

### 2. 评审
reviewer **不 redesign**，只挑问题、给修订方向。问题按严重程度分级（阻塞/应修/建议）。

### 3. 评审报告
输出到 `architecture/review.md`，核心结构：

```markdown
# {项目名} 技术方案评审报告

## 评审信息
| 项 | 内容 |
| 评审日期 | |
| 评审文档 | |
| 需求依据 | |

## 一、评审结论
**结论：通过 / 有条件通过 / 不通过**
一段总体评价。

## 二、问题清单（按严重程度）
### 🔴 高严重（阻塞）
| 序号 | 问题 | 位置 | 影响 |
### 🟡 中严重（应修）
### 🟢 低严重（建议）

## 三、修订建议
按问题顺序给出具体修订方案。

## 四、优势与亮点
≥2-3 条。

## 五、结论与后续动作
- 是否需要复审 / 复审触发条件 / 下一步
```

### 4. review 模式返回值
```
产物路径：docs/architecture/review.md
模式：review
结论：通过 / 有条件通过 / 不通过
摘要（≤5行）：
- 🔴X / 🟡Y / 🟢Z
- 主要问题：...
- 亮点：...
- 建议：...
```

---

## 独立调用 vs 被编排

| 维度 | 独立调用 | 被 leader 编排 |
|---|---|---|
| 模式判断 | 根据用户意图判断/问 | 由参数/上下文给出 |
| 术语澄清 | 直接与用户对话 | 把清单结构化返回给 leader，由 leader 转交 |
| 返回 | 摘要+路径给用户 | 严格按返回值格式，长篇不回传 |
| Gate 推进 | 完成后询问下一步 | 不碰 Gate，交给 leader |
| 阻塞 | 直接问用户 | 返回 `BLOCKED:原因`，不硬做 |

---

## 可提炼到知识库（标注，不自动同步）

项目中产生的通用经验，在文档中以"【可提炼到 xxx/】"标注，由架构师审核后决定是否写入知识库。
