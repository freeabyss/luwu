---
name: init-project
description: 将一个已有代码项目接入 luwu（陆吾）工作流。读取代码与已有文档，生成项目级 CLAUDE.md / AGENTS.md 等多平台 Agent 指令文件，按约定搭建 docs/ 文档结构，并直接产出 PRD、技术方案、测试用例的 as-built（现状）初稿。当用户说"初始化项目""接入工作流""生成 CLAUDE.md/AGENTS.md""整理项目文档""onboard 这个项目""给这个项目搭文档结构"时使用。即使用户没有明确点名，只要意图是把一个现有项目纳入 AI 辅助开发流程、补齐 Agent 配置和项目文档，也应使用本 skill。仅通过 /init-project 显式调用。
user-invocable: true
disable-model-invocation: true
---

# Init Project：项目接入初始化

把一个**已有代码的项目**一次性接入 luwu 工作流。你是"接入工"：勘测现状 → 与用户确认 → 生成配置与文档 → 汇报并交接。

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
| 约定与规范 | 已有的命名、目录、lint/format 配置、CODEOWNERS、贡献指南 |
| 版本控制状态 | 当前分支、是否有未提交改动（**只读检查，不改动**） |
| 全局知识库 | 若存在 `~/workspace/person/`，按项目类型留意可引用的全局工程规范（如 Java 项目参考 `core/engineering/Java-工程分层规范.md`）；没有就跳过，不要硬编码依赖 |

勘测结束后，在脑中（或临时笔记中）形成一份简洁结论：技术栈、构建/测试命令、入口与分层、现有文档清单、发现的约定、需要用户澄清的点。

---

## 阶段② 确认方案

向用户汇报勘测结论，并确认以下事项后再动笔。用一次提问把关键选择问清，不要逐个零碎确认：

1. **目标平台**：默认生成 `CLAUDE.md`（委托原生 `init`）+ `AGENTS.md`（Codex/OpenCode/Cursor 通用）。确认是否都需要。
2. **文档范围**：PRD、技术方案、测试用例三类 as-built 初稿，哪些要生成、哪些跳过（项目里已有成熟文档的应跳过或合并）。
3. **文档根目录**：以探测到的为准（用户指定 > `docs/README.md` > `doc/README.md` > 默认 `docs/`），让用户确认。

Agent 指令文件的处理规则固定：`CLAUDE.md`/`AGENTS.md` 已存在则**直接跳过**，不覆盖、不合并；只有不存在时才生成。这一点不需用户选择。

不要问已经能从代码确定的东西；只确认真正有歧义或需要授权的决策。

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
  ```

  路径以阶段②确认的文档根为准（若不是 `docs/` 则替换）。

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

### 3.3 as-built 文档初稿

这是本 skill 最有价值的部分：基于真实代码产出"现状文档"初稿，而不是空模板。

三类文档分别委派**独立的 subagent** 生成（可并行）。每个 subagent 的做法：

1. 读取对应 skill 的模板与规范（模板是检查清单，按现状裁剪，不保留空章节）：
   - PRD：`skills/prd/references/PRD_TEMPLATES.md`
   - 架构：`skills/architecture/references/` 下模板，结合 `skills/architecture/SKILL.md` 的 design 模式要求
   - 测试：`skills/test/SKILL.md` 的用例组织规范
2. 针对分配给它的模块/范围读取代码（subagent 自行用搜索/读文件工具，不要把整个代码库塞进主上下文）
3. 产出 as-built 初稿：描述**已实现**的功能、已落地的架构、已存在的测试覆盖；对推断但不确定的内容标注「待确认」
4. 写入对应目录：`docs/prd/README.md`、`docs/architecture/README.md`、`docs/test/README.md`（内容多可按该 skill 的拆分约定拆子文档）

对大型代码库，按模块/服务分片委派多个 subagent，最后由你汇总成主文档。告诉用户哪些模块因体量被分片处理。

**重要**：这些初稿是 as-built（现状），用来消除"代码在跑但没人说得清它做了什么"的债务；后续需求迭代的 to-be 设计仍由 `/prd`、`/architecture`、`/test` 在迭代中正式产出。在每份初稿顶部用一行注明：`> 本文档为接入时的 as-built 初稿，基于代码逆向整理，待人工核对。`

---

## 阶段④ 汇报交接

完成后向用户汇报：

- **已生成/更新的文件清单**（按指令文件、目录骨架、as-built 文档分组，带路径）
- **跳过的文件及原因**（已有成熟文档、用户选择跳过等）
- **需要用户人工核对/补充的点**（subagent 标注的「待确认」项）
- **下一步**：核对初稿后，用 `/flow` 启动第一次需求迭代；日常用 `/prd`、`/architecture`、`/test` 维护对应文档

汇报简洁、带路径，不要回传长篇文档内容。

---

## 非破坏原则

- `CLAUDE.md`、`AGENTS.md` 已存在则**直接跳过**，不覆盖、不合并、不追加（CLAUDE.md 的 luwu 文档地图增量也不追加），只在汇报中注明已跳过。
- 其他目标文件（`docs/` 下文档）写入前检查是否存在，按阶段②确认的方式处理，绝不静默覆盖。
- 发现用户有未提交改动时，不触碰、不暂存、不还原；只在自己负责的新文件上工作，有冲突立即报告并等待决定。
- 勘测阶段全程只读，不修改任何文件。
- 不创建 flow 职责范围内的东西（分支、plan.md、迭代目录、Issue、PR）。
- 不确定的命令、路径、事实标注「待确认」，不臆造。

## 参考文件

- `references/agents-md-template.md` — AGENTS.md（通用 Agent）模板，从 CLAUDE.md 转写
- `references/docs-structure.md` — docs/ 目录结构与 docs/README.md 索引模板
