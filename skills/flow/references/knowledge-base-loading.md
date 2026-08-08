# 知识库加载规范（Knowledge Base Loading）

> 本文件是陆吾知识库机制的**唯一权威副本**，被 `flow`、`prd`、`architecture`、
> `test`、`code-review`、`test-driven-development`、`writing-plans`、`init-project`
> 共同引用。修改本文件即同时改变所有 skill 的加载行为。

陆吾的个人知识沉淀在一个**本地知识库目录**（下文简称 KB）中，与插件随附的内置
`references/` 分离：KB 放用户自己的通用知识和自定义模板，跨项目复用；内置
`references/` 随插件分发，是兜底默认。

---

## 1. 知识库结构

```
<kb-root>/
├── index.md            # 知识索引：路径 + 作用 + 适用场景/阶段
├── 00_template/        # 用户自定义文档模板（覆盖内置 references 模板）
└── 01_global/          # 通用知识：编码规范、架构原则、领域术语、业务规则等
```

`00_template/` 与 `01_global/` 可按需要继续分子目录，但 `index.md` 必须列出所有
需要被 agent 加载的条目。未在 `index.md` 登记的文件，agent 不会主动加载。

---

## 2. 路径解析顺序

KB 根目录按以下优先级解析，**先命中先用**：

1. **项目指针**：读取项目根 `.claude/luwu.json` 的 `knowledgeBasePath` 字段。
2. **环境变量**：`LUWU_KB_PATH`。
3. **全局默认**：`~/.luwu/knowledge-base/`。

项目指针文件格式（支持 `~` 展开，支持绝对路径）：

```json
{ "knowledgeBasePath": "~/my-luwu-kb" }
```

- `knowledgeBasePath` 显式为 `null` 表示本项目禁用知识库（即使环境变量/默认路径
  存在也不加载，只用内置 references）。
- 解析出的路径不存在、不是目录、或其中没有 `index.md`，视为"未配置 KB"，
  **静默回退到仅用内置 references**——不报错、不告警、不阻断流程。

---

## 3. index.md 契约

`index.md` 是按需加载的入口，agent **先读它，再决定加载哪些文件**，禁止一上来
递归读取整个 KB。它包含两张表：

```markdown
# 知识库索引

> Agent 工作前先读本文件，按"适用场景/阶段"筛选，只 Read 命中的文件，不要全量加载。
> 模板以 00_template/ 为优先，命中即替代对应内置模板；未命中用内置。

## 通用知识 01_global/
| 文件 | 作用 | 适用场景/阶段 |
|---|---|---|
| 01_global/coding-style.md | 编码红线与命名规范 | ⑥开发、⑥代码审查 |
| 01_global/api-conventions.md | API 设计约定 | ③架构设计、⑥开发 |
| 01_global/domain-glossary.md | 业务领域术语表 | ②PRD、③架构设计 |

## 模板 00_template/
| 文件 | 覆盖的内置模板 | 适用 skill |
|---|---|---|
| 00_template/prd.md            | prd/references/PRD_TEMPLATES.md         | prd |
| 00_template/architecture.md   | architecture/references/architecture-template.md | architecture |
| 00_template/adr.md            | architecture/references/adr-template.md | architecture |
```

字段说明：

- **通用知识表 ·「适用场景/阶段」**：用 flow 的阶段编号（⓪–⑨）或场景关键词
  （如"代码审查""开发""测试设计""测试执行"）标注。这是 flow/skill 筛选的依据。
  一条知识可标注多个阶段。
- **模板表 ·「覆盖的内置模板」**：必须显式写出被替代的内置模板相对路径
  （相对插件 skill 根），避免文件名不一致造成歧义。
- 条目路径相对 KB 根；可指向子目录（如 `01_global/team/api-style.md`）。

agent 读 index.md 后：按当前 skill / 当前 flow 阶段筛出命中行，**只 Read 命中的
文件**；未命中的文件不要加载（省 token）。命中文件读取失败时跳过该行继续，不阻断。

---

## 4. 模板映射：用户优先、内置兜底

各 skill 产出文档时，模板来源按以下顺序确定：

1. 若 KB 已配置且 `index.md` 模板表中有对应条目，Read 该 `00_template/` 文件，
   **用它替代**内置模板。
2. 否则使用 skill 自带 `references/`（或 `reference/`）模板。

可被覆盖的内置模板（用户在 index.md「覆盖的内置模板」列直接引用这些路径）：

| skill | 内置模板路径 | 用途 |
|---|---|---|
| prd | `prd/references/PRD_TEMPLATES.md` | PRD 文档结构 |
| architecture | `architecture/references/architecture-template.md` | 技术方案主文档 |
| architecture | `architecture/references/adr-template.md` | 架构决策记录 ADR |
| architecture | `architecture/references/context-template.md` | 架构上下文/背景 |
| architecture | `architecture/references/mermaid-examples.md` | Mermaid 图表示例 |
| init-project | `init-project/references/agents-md-template.md` | AGENTS.md 转写模板 |
| init-project | `init-project/references/docs-structure.md` | docs/ 目录结构说明 |

用户也可以在 `00_template/` 放未在上表中的额外模板文件并在 index.md 登记，agent
按 index.md 的「适用 skill」列决定何时使用；这类新增模板不影响内置兜底。

> 注意：`test` 的 `reference/`（单数）目录多为**分层测试规则**而非可填空模板，
> 通常通过 `01_global/` 知识条目补充/覆盖测试约定，而不是覆盖这些文件。

---

## 5. 独立调用 skill 时的加载步骤

当某个 skill（如 `/architecture`、`/prd`）被用户直接调用、不在 flow 编排中时，
该 skill 自行：

1. 按第 2 节顺序解析 KB 路径；未配置则跳到第 5 步。
2. Read `<kb>/index.md`。
3. 按当前 skill 名称与当前任务类型，筛选「通用知识」表中「适用场景/阶段」命中的
   行，逐个 Read 对应 `01_global/` 文件，把其内容作为本任务的约束/背景。
4. 模板：查「模板」表中「适用 skill」命中本 skill 的行，命中则 Read 用户模板并
   替代内置；否则用内置 references。
5. 未配置 KB 时，完全按 skill 原有方式使用内置 references，行为与引入 KB 前一致。

---

## 6. flow 编排时的注入步骤

flow 是唯一掌握"当前在哪个阶段、下游 subagent 做什么"的编排者。为避免每个
subagent 各自定位/筛选 KB（且 subagent 在项目工作目录下不一定能可靠定位路径），
由 **leader 统一探测并内联注入**，与现有「技术栈探测与内置规范注入」同构：

1. **阶段⓪探测**：按第 2 节解析 KB 路径；若配置了 KB，Read `<kb>/index.md`。
   把 KB 路径与命中清单写入 `.claude/plan.md`（「输入概况」或「注意事项」）。
2. **派发前注入**：派发每个阶段 subagent 前，leader 根据该 subagent 的阶段编号
   /职责，从 index.md「通用知识」表筛出命中的 `01_global/` 文件，Read 后把内容
   **完整内联**到 subagent prompt 的独立一节，例如：

   ```markdown
   ## 团队通用知识（来自知识库，强制遵循）
   <01_global/coding-style.md 全文>
   <01_global/api-conventions.md 全文>

   ## 模板覆盖
   本阶段产出的架构文档使用用户自定义模板：<kb>/00_template/architecture.md
   （若存在）；否则用内置 architecture/references/architecture-template.md。
   ```

3. **subagent 侧**：prompt 已内联知识时**直接遵循，不要再去读 KB**；leader 未
   注入（说明未配置 KB 或该阶段无命中）则 subagent 无需尝试加载 KB。
4. 未配置 KB 时本节整体跳过，不影响其他流程。

flow 阶段到「适用场景/阶段」的对应关系（用于筛选 index.md 命中行）：

| flow 阶段 | 匹配的阶段/场景关键词 |
|---|---|
| ② 产品设计 | ② / PRD / 产品设计 / 需求 |
| ③ 架构设计 | ③ / 架构设计 / 技术方案 |
| ④ 架构评审 | ④ / 架构评审 |
| ⑤ 任务拆解 | ⑤ / 任务拆解 / 计划 |
| ⑥ 开发（tdd） | ⑥ / 开发 / TDD / 编码 |
| ⑥ 代码审查 | ⑥ / 代码审查 / code-review |
| ⑦ 测试用例 | ⑦ / 测试设计 / 测试用例 |
| ⑧ 测试执行 | ⑧ / 测试执行 / 测试 |

标注为"全局/所有阶段"的条目在②–⑧每个阶段都注入（⓪初始化、⑨提交PR一般不注入，
除非条目明确点名）。

---

## 7. 非破坏与回退原则

- KB 是用户的个人资产，任何 skill/flow **只读取，不写入、不修改、不删除** KB
  内文件。初始化/脚手架由 `init-project` 负责，且只补不盖。
- index.md 中某条文件读不到、格式损坏、或路径越出 KB 根目录：跳过该条，继续处理
  其余条目，不阻断任务。
- 用户模板内容与内置模板冲突时，以用户模板为准（用户优先是本机制的明确意图）。
- 知识库缺失不应让任何 skill 失败：内置 references 始终是完整可用的兜底。
