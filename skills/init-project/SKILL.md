---
name: init-project
description: 将一个已有代码项目接入 luwu（陆吾）工作流。读取代码与已有文档，生成项目级 CLAUDE.md / AGENTS.md 等多平台 Agent 指令文件，按约定搭建 docs/ 文档结构，并直接产出 PRD、技术方案、测试用例的 as-built（现状）初稿。当用户说"初始化项目""接入工作流""生成 CLAUDE.md/AGENTS.md""整理项目文档""onboard 这个项目""给这个项目搭文档结构"时使用。即使用户没有明确点名，只要意图是把一个现有项目纳入 AI 辅助开发流程、补齐 Agent 配置和项目文档，也应使用本 skill。可通过对应 slash command 调用，也可被 flow 编排调用。
user-invocable: true
disable-model-invocation: false
---

# Init Project：项目接入初始化

把一个**已有代码的项目**接入 luwu 工作流。你是"接入工"：勘测现状 → 与用户确认 → 生成配置与文档 → 汇报并交接。

本 skill **幂等、可重复执行**：可以在同一项目上多次运行而不破坏已有成果。第二次及以后运行时，它会先识别"哪些已经接入过"，只补齐缺失项、跳过已存在的人工内容，并在确认阶段明确询问是否要刷新/重建某些产物（默认不刷新）。

## 定位与边界

本 skill 做的是**项目级一次性前置**：

- 生成 Agent 指令文件（`CLAUDE.md`、`AGENTS.md` 等，见「多平台指令文件」）
- 搭建项目文档目录骨架 `docs/`
- 读取代码与已有文档，产出 PRD / 技术方案 / 测试用例的 **as-built 初稿**（描述"这个项目现在是什么样"，而非"将来要做什么"）

本 skill **不做**的事——这些归 `flow` 阶段⓪及后续阶段负责，不要越界：

- 不创建/切换 Git 分支
- 不创建 `.claude/plan.md`
- 不创建 `docs/iterations/{date}-{version}-{slug}/` 迭代目录
- 不创建 GitHub Issue、不提交代码、不开 PR

接入完成后，第一次需求迭代由用户通过 `/flow` 启动。

## 唯一工作流程：四阶段

```text
① 勘测（只读）→ ② 确认方案 → ③ 生成（指令文件 / 目录骨架 / as-built 文档）→ ④ 汇报交接
```

不得跳过确认阶段直接写文件。已存在的文件一律非破坏处理（见「非破坏原则」）。

---

## 阶段① 勘测（只读）

目标：在写任何文件前，先搞清楚项目"是什么、怎么跑、已有些什么"。优先委派一个 `Explore` 或 `general-purpose` subagent 做广度扫描，避免把大量文件读进主上下文；你只保留结论。

勘测清单：

| 维度 | 要看什么 |
|---|---|
| 项目类型与技术栈 | 语言、框架、构建工具（看 `package.json`/`pom.xml`/`build.gradle`/`go.mod`/`Cargo.toml`/`pyproject.toml` 等） |
| 如何构建/运行/测试 | 常用命令、`Makefile`/`package.json scripts`/CI 配置（`.github/workflows/`） |
| 代码结构 | 源码目录、分层方式（controller/service/domain 等）、入口文件、模块边界 |
| 现有文档 | 有无 `README.md`、`docs/`、`doc/`、`prd.md`、`architecture.md`、`test.md`、`CLAUDE.md`、`AGENTS.md`；**文档根下若有 `README.md` 必须先读**，按其指引定位目录 |
| 已接入状态（幂等关键） | 检查本次接入会产出的东西是否已存在：`CLAUDE.md`/`AGENTS.md`、文档根及其子目录与各 `README.md`、`.claude/luwu.json`、知识库路径及其 `index.md`、CLAUDE.md 里是否已有「项目文档结构（luwu）」段。据此区分"首次接入"与"重复执行/补齐"，并判断哪些文档已经人工核对或被 `/prd`、`/architecture` 等迭代过（这些视为成熟内容，不重建） |
| 约定与规范 | 已有的命名、目录、lint/format 配置、CODEOWNERS、贡献指南 |
| 版本控制状态 | 当前分支、是否有未提交改动（**只读检查，不改动**） |
| 内置工程规范 | Java 项目注意内置的分层与编码规范 `skills/flow/references/java-engineering-standard.md`（分层边界、事务、Lombok、Repository 命名、统一分页），生成架构/代码相关文档时遵循 |

勘测结束后，在脑中（或临时笔记中）形成一份简洁结论：技术栈、构建/测试命令、入口与分层、现有文档清单、发现的约定、需要用户澄清的点、**已接入项 vs 待补齐项清单**（用于幂等执行）。

---

## 阶段② 确认方案

向用户汇报勘测结论，并确认以下事项后再动笔。用一次提问把关键选择问清，不要逐个零碎确认。

**幂等原则**：先用勘测得到的"已接入项 vs 待补齐项"向用户说明现状。对已经存在的产物，默认**保持不动**，只把它作为本次确认的预填值；对确实缺失的产物，才询问是否生成。提问应让用户一眼看出"哪些已存在会被保留、哪些将新建"。

1. **目标平台**：默认生成 `CLAUDE.md`（委托原生 `init`）+ `AGENTS.md`（Codex/OpenCode/Cursor 通用）。已存在的文件默认跳过；确认是否都需要、是否为缺失的那个生成。
2. **文档范围**：PRD、技术方案、测试用例三类 as-built 初稿，哪些要生成、哪些跳过。已存在的文档默认视为成熟内容而**保留不重建**（尤其是已经人工核对或被 `/prd`、`/architecture`、`/test` 迭代过的）；仅当用户明确要求"重新生成/刷新某类 as-built 初稿"时才重建，且刷新前必须确认会覆盖。
3. **文档根目录**：以探测到的为准（用户指定 > `docs/README.md` > `doc/README.md` > 默认 `docs/`），让用户确认。已存在文档根时沿用，不另起炉灶。
4. **知识库路径**：个人通用知识库（`01_global/` 通用知识 + `00_template/` 自定义模板，`index.md` 索引）的位置。若 `.claude/luwu.json` 已记录路径，则沿用并展示当前值；否则默认 `~/.luwu/knowledge-base/`（即环境变量 `LUWU_KB_PATH` 或全局默认）。用户可指定另一个绝对路径、保持沿用、或选择"本项目不使用知识库"。路径解析与结构规则见 `skills/flow/references/knowledge-base-loading.md`。

Agent 指令文件的处理规则固定：`CLAUDE.md`/`AGENTS.md` 已存在则**直接跳过**，不覆盖、不合并、不追加；只有不存在时才生成。这一点不需用户选择。

不要问已经能从代码或已有配置确定的东西；只确认真正有歧义、需要授权、或涉及覆盖已有内容的决策。重复执行时，对所有保持不动的已存在项也要在汇报中列出，让用户确认"保留"是知情的。

---

## 阶段③ 生成

按顺序产出三类产物。

### 3.1 Agent 指令文件

#### CLAUDE.md：委托原生 `init` skill 生成

**不要自己手写或用自带模板生成 CLAUDE.md**——调用原生 `init` skill 来做，它会分析代码库并产出高质量的项目说明（技术栈、构建/测试命令、代码结构、约定等）。

- 生成前检查项目根是否已存在 `CLAUDE.md`：**已存在则跳过**——不覆盖、不合并、不追加，直接进入下一步，并在汇报中注明"CLAUDE.md 已存在，已跳过"。
- 不存在时，调用原生 `init` skill 让其生成。生成后，把本项目接入 luwu 所需的**文档结构、文档地图与工作流说明**补充进去，用 Edit 追加到 init 新生成的文件末尾，不重写 init 已写好的内容（仅对本次新建的文件追加，已存在的文件一律不动）。追加内容包含：

  ```markdown
  ## 项目文档结构（luwu）

  docs/
  ├── prd/            # 产品需求：功能清单、用户流程、非功能需求（/prd 维护）
  ├── architecture/   # 技术方案、ADR、架构图（/architecture 维护）
  ├── test/           # 测试用例与测试报告（/test 维护）
  └── iterations/     # 各次迭代的过程文档与归档（/flow 启动迭代时创建）

  - 产品需求：@docs/prd/README.md
  - 技术方案：@docs/architecture/README.md
  - 测试用例：@docs/test/README.md

  新需求/迭代用 /flow 编排完整生命周期；日常用 /prd、/architecture、/test 维护对应文档。

  ## 个人知识库（luwu）

  本项目接入的个人知识库路径见 `.claude/luwu.json` 的 `knowledgeBasePath`
  （未配置时回退到 `$LUWU_KB_PATH` 或 `~/.luwu/knowledge-base/`）。
  Agent 在执行 PRD/架构/开发/审查/测试等任务前，先读 `<kb>/index.md`，按「适用场景/阶段」
  按需加载 `01_global/` 中的通用知识；文档模板优先用 `00_template/` 中的自定义模板，
  未命中再用插件内置模板。加载规则遵循插件内的知识库加载规范。
  ```

  路径以阶段②确认的文档根为准（若不是 `docs/` 则替换）；知识库路径以阶段②确认的为准，
  追加时把 `<kb>`/具体路径替换为实际值。

#### AGENTS.md：从 CLAUDE.md 转写

读取 `references/agents-md-template.md` 和**刚生成（或已存在）的 `CLAUDE.md`**，把核心事实转写为通用 Agent 指令：

- 内容与 CLAUDE.md **核心一致**，但去掉 Claude 专属语法（`@路径` 注入、Claude 斜杠命令），改用普通 Markdown 链接；用面向"任何 AI 编码 Agent"的中立措辞。
- 斜杠命令移到"if the luwu plugin is available"一节；不加载 luwu 的 Agent 也应有可独立遵循的通用工作流指引。
- 同样：若根目录已存在 `AGENTS.md` 则跳过，不覆盖。

转写时以 CLAUDE.md 为事实来源，保持两份文件信息同步；命令不确定就标注「待确认」，不要编造。

### 3.2 文档目录骨架

在确认的文档根（默认 `docs/`）下创建：

```text
docs/
├── README.md            # 文档索引与目录说明（见 references/docs-structure.md）
├── prd/                 # 产品需求（as-built 初稿 + 后续迭代 PRD）
├── architecture/        # 技术方案、ADR、架构图
└── test/                # 测试用例与测试报告
```

`docs/README.md` 作为文档地图，说明每个子目录放什么、由哪个 skill 维护。`iterations/` 目录**不要在这里创建**——它由 flow 阶段⓪在迭代启动时建立。

**幂等处理**：目录用"存在即保留"的方式创建（等价于 `mkdir -p`，不删除、不移动已有内容）；`docs/README.md` 已存在则跳过不覆盖，仅当不存在时按 `references/docs-structure.md` 的索引模板新建。子目录里已有的 `README.md` 或其他文档一律不动。

### 3.3 as-built 文档初稿

这是本 skill 最有价值的部分：基于真实代码产出"现状文档"初稿，而不是空模板。

三类文档分别委派**独立的 subagent** 生成（可并行）。每个 subagent 的做法：

1. 读取对应 skill 的模板与规范（模板是检查清单，按现状裁剪，不保留空章节）：
   - PRD：`skills/prd/references/PRD_TEMPLATES.md`
   - 架构：`skills/architecture/references/` 下模板（`architecture-template.md` 等），结合 `skills/architecture/SKILL.md` 的 design 模式要求；Java 项目另读 `skills/flow/references/java-engineering-standard.md` 按内置规范描述分层现状
   - 测试：`skills/test/SKILL.md` 的用例组织规范
2. 针对分配给它的模块/范围读取代码（subagent 自行用搜索/读文件工具，不要把整个代码库塞进主上下文）
3. 产出 as-built 初稿：描述**已实现**的功能、已落地的架构、已存在的测试覆盖；对推断但不确定的内容标注「待确认」
4. 写入对应目录：`docs/prd/README.md`、`docs/architecture/README.md`、`docs/test/README.md`（内容多可按该 skill 的拆分约定拆子文档）

**幂等写入规则（重要）**：委派 subagent 前，先检查三类目标文件是否已存在：

- **不存在**：正常生成并写入。
- **已存在**：默认**跳过、不覆盖**（该文档可能已被人工核对或被 `/prd`、`/architecture`、`/test` 迭代为正式内容）。只有在阶段②用户明确要求"刷新/重建"该类文档时才重新生成；重新生成时：
  - 若文件顶部仍带 as-built 标记（`> 本文档为接入时的 as-built 初稿…`），可原地覆盖（它从未被人工接管）；
  - 若文件已无该标记或检测到后续迭代痕迹，先把旧文件备份为 `{name}.bak-asbuilt-{YYYY-MM-DD}.md` 再写新稿，并在汇报中提示用户对比合并，绝不静默丢弃已有内容。
- 给 subagent 的指令必须明确：对已存在文件是"跳过"还是"重建（含备份）"，不要让 subagent 自行决定覆盖。

对大型代码库，按模块/服务分片委派多个 subagent，最后由你汇总成主文档。告诉用户哪些模块因体量被分片处理。

**重要**：这些初稿是 as-built（现状），用来消除"代码在跑但没人说得清它做了什么"的债务；后续需求迭代的 to-be 设计仍由 `/prd`、`/architecture`、`/test` 在迭代中正式产出。在每份初稿顶部用一行注明：`> 本文档为接入时的 as-built 初稿，基于代码逆向整理，待人工核对。`

### 3.4 个人知识库

把阶段②确认的知识库路径接入本项目（路径解析、index.md 结构、模板映射以
`skills/flow/references/knowledge-base-loading.md` 为准）：

1. **确保项目指针**：在项目根写/更新 `.claude/luwu.json`，写入 `knowledgeBasePath`。
   - 用户指定了路径：写该路径（绝对路径或 `~/...`）。
   - 用户选择默认：可写默认路径 `~/.luwu/knowledge-base/`，也可省略该字段让运行时回退
     到环境变量/全局默认（省略更干净；仅当用户明确要求固定时才写）。
   - 用户选择"不使用"：写 `"knowledgeBasePath": null`（显式禁用，即使全局有默认也不加载）。
   - 该文件已存在时，**合并**更新 `knowledgeBasePath` 字段，不覆盖其他已有键。
2. **脚手架 KB 目录**：解析出的路径若不存在、或虽存在但为空（无 `index.md`），则把
   `references/kb-scaffold/` 下的三份种子文件复制过去：
   - `index.md` → `<kb>/index.md`
   - `00_template/README.md` → `<kb>/00_template/README.md`
   - `01_global/README.md` → `<kb>/01_global/README.md`

   已存在的文件**一律不覆盖**（只补缺失项），保护用户已沉淀的内容。复制方式用文件
   写入工具按种子文件内容创建，不要执行破坏性 shell 命令。
3. **知识库与 as-built 初稿独立**：知识库是跨项目的个人资产，init-project **只搭骨架和
   写指针，不往 `01_global/` 写业务内容**；项目现状文档仍写到项目 `docs/` 下。

阶段②选择"不使用知识库"时，跳过脚手架步骤，但仍写入 `.claude/luwu.json` 的禁用标记。

---

## 阶段④ 汇报交接

完成后向用户汇报：

- **本次新建的文件清单**（按指令文件、目录骨架、as-built 文档、知识库分组，带路径）
- **保留未改动的已存在项**（重复执行时列出：已存在而跳过的 CLAUDE.md/AGENTS.md、沿用的文档根、已有的 as-built 文档、已存在的知识库与 `.claude/luwu.json` 等，让用户确认保留是知情的）
- **跳过的文件及原因**（用户选择跳过、选择不生成等）
- **刷新/重建与备份**（若用户要求重建某类文档，列出被覆盖的文件及其备份路径）
- **知识库状态**：使用的路径、是新建脚手架还是复用已有、`.claude/luwu.json` 是否写入；若选择不使用也要注明
- **需要用户人工核对/补充的点**（subagent 标注的「待确认」项，以及知识库中待用户填充的模板/知识条目）
- **下一步**：核对初稿后，用 `/flow` 启动第一次需求迭代；日常用 `/prd`、`/architecture`、`/test` 维护对应文档；向知识库 `01_global/` 沉淀通用规范、`00_template/` 自定义模板

汇报简洁、带路径，不要回传长篇文档内容。

---

## 非破坏原则与幂等保证

- 本 skill 可安全重复执行：第二次运行只补齐缺失项，已存在的产物默认保留不动；任何覆盖/重建都必须在阶段②得到用户明确同意。
- `CLAUDE.md`、`AGENTS.md` 已存在则**直接跳过**，不覆盖、不合并、不追加（CLAUDE.md 的 luwu 文档地图增量也不追加），只在汇报中注明已跳过。
- `docs/` 下文档与 as-built 初稿：已存在默认跳过、不覆盖；仅当用户明确要求刷新时才重建，且对已脱离 as-built 状态（无 as-built 标记或有迭代痕迹）的文件先备份为 `*.bak-asbuilt-{日期}.md` 再写。
- 文档目录骨架用 `mkdir -p` 语义创建（存在即保留），不删除、不移动已有内容。
- 知识库目录内的文件**只补不盖**：脚手架只创建缺失的 `index.md`/`README.md`，已存在的文件（尤其是用户已沉淀的 `01_global/`、`00_template/` 内容）一律不动。
- `.claude/luwu.json` 已存在时合并更新 `knowledgeBasePath`，不覆盖文件中其他键；值与现有一致时不改动文件。
- 发现用户有未提交改动时，不触碰、不暂存、不还原；只在自己负责的新文件上工作，有冲突立即报告并等待决定。
- 勘测阶段全程只读，不修改任何文件。
- 不创建 flow 职责范围内的东西（分支、plan.md、迭代目录、Issue、PR）。
- 不确定的命令、路径、事实标注「待确认」，不臆造。

## 参考文件

- `references/agents-md-template.md` — AGENTS.md（通用 Agent）模板，从 CLAUDE.md 转写
- `references/docs-structure.md` — docs/ 目录结构与 docs/README.md 索引模板
- `references/kb-scaffold/` — 个人知识库脚手架种子（`index.md` + `00_template/README.md` + `01_global/README.md`），知识库目录为空时复制（只补不盖）
