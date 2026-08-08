# Luwu 陆吾 - 个人开发流程插件

> 陆吾（Luwu）——个人开发流程与经验沉淀插件，适用于 Claude Code、OpenCode、Codex 等 AI Agent 工具。

## 简介

本插件沉淀了个人 AI 辅助开发的完整工作流，包含：

- **Flow 全流程编排 skill**：从需求到 PR 的完整项目生命周期管理
- **PRD 撰写**：逐条提问+方案对比+分段确认，多文档结构输出
- **架构设计/评审**：技术方案设计与独立评审双模式
- **任务拆解**：Write Plan 细粒度任务拆分
- **TDD 开发**：测试驱动开发规范
- **代码审查**：独立 subagent 代码审查
- **测试全流程**：用例生成、评审、执行、报告
- **Obsidian 笔记**：安装时自动拉取 Obsidian 创始人官方 skills（Markdown / CLI / Bases / Canvas）
- **UI/UX Design**：安装时自动拉取 ui-ux-pro-max 设计技能

## 目录结构

```
luwu/
├── .claude-plugin/          # Claude Code 插件配置
│   ├── plugin.json          # 插件 manifest
│   └── marketplace.json     # Marketplace 配置
├── .codex-plugin/           # Codex 插件配置
│   └── plugin.json
├── skills/                  # Skills 集合
│   ├── flow/                # 全流程编排 skill
│   ├── architecture/        # 架构设计与评审
│   ├── prd/                 # PRD 撰写（多文档输出到 docs/prd/）
│   ├── test/                # 测试全流程助手
│   ├── code-review/         # 代码审查
│   ├── test-driven-development/  # TDD 规范
│   ├── writing-plans/       # 任务拆解
│   └── init-project/        # 项目初始化（含个人知识库脚手架）
├── commands/                # 自定义 Slash Commands
├── hooks/                   # Claude Code Hooks
├── dependencies.json        # 第三方依赖声明（plugin/mcp/skill，安装时自动拉取）
├── install.sh               # 一键安装脚本
├── package.json             # NPM 包元信息（跨平台）
└── README.md                # 本文件
```

## 安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh)
```

安装脚本会自动检测已安装的 AI agent 工具并配置（Claude Code 写入 settings.json；Codex symlink skills 并写入 config.toml）。前置条件：Git、jq（或 python3）。

## 快速开始

### 使用 Flow 全流程编排 skill（推荐）

在项目根目录下启动 Claude Code，然后输入：

```
/flow
```

flow skill 会自动执行完整流程：

1. **⓪ 初始化** - 创建功能分支、迭代目录
2. **① 需求入库** - 从会议纪要或对话创建 GitHub Issue
3. **② 产品设计** - 生成 PRD 文档
4. **③ 技术方案设计** - 架构设计
5. **④ 架构评审** - 独立评审
6. **⑤ 任务拆解** - 细粒度任务拆分
7. **⑥ TDD 开发 + 审查** - 开发并独立审查
8. **⑦ 测试用例** - 生成测试用例
9. **⑧ 测试执行** - 执行测试
10. **⑨ 提交 PR** - 创建 Pull Request

### 独立使用 Skill

也可以独立调用各个 skill：

| Slash Command | 功能 |
|--------------|------|
| `/prd` | 生成/维护 PRD 文档 |
| `/architecture` | 架构设计或评审 |
| `/test` | 生成测试用例或执行测试 |
| `/code-review` | 代码审查 |
| `/tdd` | TDD 开发流程 |
| `/writing-plans` | 任务拆解 |
| `/obsidian-markdown` | 创建/编辑 Obsidian 笔记（wikilinks、callouts、frontmatter 等） |
| `/obsidian-cli` | 通过 Obsidian CLI 读写/搜索/管理 vault（需 Obsidian 开启） |
| `/obsidian-bases` | 创建/编辑 Obsidian Bases（`.base`） |
| `/json-canvas` | 创建/编辑 JSON Canvas（`.canvas`） |
| `/ui-ux-pro-max` | UI/UX 设计 |

## Skills 说明

### Flow Skill

项目生命周期总指挥，只负责编排和验收，不亲自执行阶段工作。每个阶段委派独立 subagent，确保：

- 设计与评审分离（阶段③④必须不同 subagent）
- 开发与审查分离（阶段⑥每个任务开发后独立审查）
- 测试设计与执行分离（阶段⑦⑧必须不同 subagent）
- Stage Gate 机制：PRD/架构/任务拆分/测试完成后等待用户确认


### PRD Skill

PRD 撰写 skill，融合 brainstorming 的设计确认流程：

- 逐条提问对齐需求（一次一个问题，带推荐选项）
- 需求存在多种实现路径时，提供 2-3 方案对比与 trade-off
- 分段确认 HARD-GATE：关键决策未确认不得进入文档编写
- 多文档输出到 `docs/prd/` 目录：
  - `README.md`：主文档（背景、目标、范围总纲、索引表）
  - `features.md`：功能需求详情（必建）
  - `user-stories.md` / `prototype.md` / `non-functional.md` / `data-model.md` / `risks.md`：按需创建
- 自审清单（占位符/一致性/范围/歧义）
- 用户 review 门：书面确认后才能进入架构阶段

### Architecture Skill

支持双模式：
- **design**：基于 PRD 输出技术方案
- **review**：独立评审已有方案

核心特性：
- 五类批量术语澄清（冲突/模糊/缺失/重复/矛盾）
- DDD 启发式判断
- 多方案对比推荐
- 文档拆分（design-api.md / design-database.md 等）

**内置知识资产**（随插件分发，不依赖用户本机路径）：技术方案模板、ADR/CONTEXT 模板、Mermaid 示例位于 `skills/architecture/references/`；强制的 **Java/DDD 工程分层规范**（分层边界、事务使用、Lombok、Repository 命名、统一分页 `PageResult`）唯一副本位于 `skills/flow/references/java-engineering-standard.md`。

`/flow` 在阶段⓪/①探测到 Java 项目后，会把该规范完整内联注入到架构设计(③)、架构评审(④)、开发与代码审查(⑥)、测试(⑦⑧)各阶段 subagent 的 prompt 中强制对照；独立调用 `/architecture`、`/code-review` 时则各自从该唯一副本读取。

### Test Skill

测试全流程助手：

- 用例生成（Happy Path/Boundary/Exception/Performance/Security 五维度）
- 用例评审
- 测试执行
- 测试报告
- 多语言/框架支持（Java/Vitest/Playwright/pytest/Go/Rust）
- 按迭代目录组织

## 个人知识库

陆吾支持一个**本地个人知识库**，跨项目沉淀通用知识和自定义文档模板，与插件随附的内置模板分离：

```
<kb-root>/
├── index.md            # 知识索引：路径 + 作用 + 适用场景/阶段，agent 据此按需加载
├── 00_template/        # 用户自定义文档模板（覆盖插件内置 references 模板）
└── 01_global/          # 通用知识：编码规范、架构原则、领域术语、业务规则等
```

- **指定位置**：`/init-project` 接入项目时确认知识库路径，写入项目 `.claude/luwu.json` 的 `knowledgeBasePath`。
- **路径解析**：项目 `.claude/luwu.json` → 环境变量 `LUWU_KB_PATH` → 全局默认 `~/.luwu/knowledge-base/`；显式设为 `null` 可在某项目禁用。
- **按需加载**：agent 先读 `<kb>/index.md`，按「适用场景/阶段」只加载命中的 `01_global/` 条目，不全量读取。
- **模板覆盖**：`00_template/` 中在 index.md 登记的自定义模板优先于插件内置 `references/` 模板，未命中则回退内置。
- **flow 注入**：`/flow` 在阶段⓪探测知识库，按阶段把命中的通用知识内联注入各阶段 subagent（与内置 Java 规范注入同构）。
- 路径不存在或无 `index.md` 时静默回退到仅用内置模板，不报错、不阻断。

加载规则的权威说明见 `skills/flow/references/knowledge-base-loading.md`；`/init-project` 在知识库目录为空时会自动脚手架 `index.md` 与两个子目录（只补不盖）。

## 多平台支持

本插件遵循跨平台插件规范，理论上支持：

- Claude Code
- Codex
- OpenCode
- Cursor
- Windsurf
- GitHub Copilot
- Kiro
- Roo Code
- Kilo Code
- Qoder
- Gemini
- Trae
- Continue
- CodeBuddy
- Warp
- Augment

不同平台的安装方式请参考对应平台的插件文档。核心目录结构兼容：
- Claude Code: `.claude-plugin/`
- Codex: `.codex-plugin/`
- Cursor: `.cursor-plugin/`
- 其他平台类似，可按需添加对应 `.xxx-plugin/` 目录

## 第三方依赖

第三方 skill / 插件**不随仓库分发**，而是在根目录的 `dependencies.json` 中声明。`install.sh` 安装或更新时会检查依赖是否存在，缺失则通过各平台官方方式自动安装。

当前声明的依赖（均为 Claude Code marketplace 插件，官方途径安装）：

- [obsidian-skills](https://github.com/kepano/obsidian-skills) — Obsidian 创始人 Steph Ango (kepano) 官方维护，提供 `obsidian-markdown`、`obsidian-cli`、`obsidian-bases`、`json-canvas`、`defuddle`
- [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) — UI/UX 设计智能（84 UI 风格、192 色板、74 字体组合、98 UX 准则、25 图表类型，22 种技术栈）

`dependencies.json` 的每条依赖包含 `name`、`type`（`plugin` / `mcp` / `skill`，后两者为预留类型）、`platforms`、`marketplace`、`repo` 等字段。安装失败时仅告警不阻断，可按提示手动执行 `claude plugin marketplace add <repo>` 与 `claude plugin install <name>@<marketplace>`。

> 说明：第三方依赖目前只在 **Claude Code** 平台自动安装。Obsidian vault 本质是本地 Markdown 文件夹，`obsidian-markdown` / `json-canvas` 直接读写文件，无需 Obsidian 常驻；`obsidian-cli` 需要 Obsidian 运行并安装 Obsidian CLI。

## 自定义配置

### 添加新的 Skill

在 `skills/` 目录下创建新目录，包含 `SKILL.md`：

```markdown
---
name: skill-name
description: Skill 描述
user-invocable: true
---

# Skill 标题

具体工作流...
```

### 添加第三方依赖

不要把第三方代码拷进仓库。在根目录 `dependencies.json` 的 `dependencies` 数组中追加一条，安装/更新脚本会自动拉取：

```json
{
  "name": "<plugin-name>",
  "type": "plugin",
  "platforms": ["claude"],
  "marketplace": "<marketplace-name>",
  "repo": "<owner>/<repo>",
  "description": "可选说明"
}
```

## 更新日志

### v1.1.0 (2026-08-08)

- 新增**个人知识库**机制：`/init-project` 指定本地知识库目录（`.claude/luwu.json` 的 `knowledgeBasePath`，回退 `$LUWU_KB_PATH` / `~/.luwu/knowledge-base/`），目录为空时自动脚手架 `index.md` + `00_template/` + `01_global/`；各 skill 先读 `index.md` 按需加载通用知识、模板用户优先内置兜底；`/flow` 阶段⓪探测并按阶段内联注入下游 subagent（权威规范 `skills/flow/references/knowledge-base-loading.md`）
- `/init-project` 改为**幂等、可重复执行**：先探测已接入状态，已存在的文件/目录/配置默认保留，只补缺失项；重复执行不覆盖已核对或迭代过的文档，重建需用户明确同意且先备份
- 移除 `skills/vendor` submodule 方式，改为根目录 `dependencies.json` 声明第三方依赖；`install.sh` 安装/更新时检查并按官方方式自动拉取
- 新增 [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) 官方 skill 集作为依赖：obsidian-markdown、obsidian-cli、obsidian-bases、json-canvas、defuddle

### v1.0.0 (2026-07-30)

- 初始版本
- Flow 全流程编排 skill
- Architecture、PRD、Test、Code Review、TDD、Writing Plans skills
- 集成 ui-ux-pro-max 第三方 skill

## License

MIT
