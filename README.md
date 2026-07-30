# Abyss DevFlow Plugin

> 个人开发流程与经验沉淀插件，适用于 Claude Code、OpenCode、Codex 等 AI Agent 工具。

## 简介

本插件沉淀了个人 AI 辅助开发的完整工作流，包含：

- **Leader 全流程编排**：从需求到 PR 的完整项目生命周期管理
- **PRD 撰写**：结构化产品需求文档生成
- **架构设计/评审**：技术方案设计与独立评审双模式
- **任务拆解**：Write Plan 细粒度任务拆分
- **TDD 开发**：测试驱动开发规范
- **代码审查**：独立 subagent 代码审查
- **测试全流程**：用例生成、评审、执行、报告
- **知识沉淀**：自动提炼和归档开发经验
- **UI/UX Design**：通过 vendor 集成 ui-ux-pro-max 设计技能

## 目录结构

```
abyss-plugin/
├── .claude-plugin/          # Claude Code 插件配置
│   ├── plugin.json          # 插件 manifest
│   └── marketplace.json     # Marketplace 配置
├── .codex-plugin/           # Codex 插件配置
│   └── plugin.json
├── agents/                  # 自定义 Agents
│   ├── leader.md            # 项目生命周期总指挥
│   └── prd.md               # PRD 撰写专家
├── skills/                  # Skills 集合
│   ├── architecture/        # 架构设计与评审
│   ├── prd/                 # PRD 生成器
│   ├── test/                # 测试全流程助手
│   ├── code-review/         # 代码审查
│   ├── test-driven-development/  # TDD 规范
│   ├── writing-plans/       # 任务拆解
│   ├── knowledge-deposit/   # 知识沉淀
│   └── vendor/              # 第三方 Skills（git submodule）
│       └── ui-ux-pro-max/   # UI/UX 设计智能
├── commands/                # 自定义 Slash Commands
├── hooks/                   # Claude Code Hooks
├── package.json             # NPM 包元信息（跨平台）
└── README.md                # 本文件
```

## 安装

### 前置条件

- Claude Code CLI 已安装
- Git 已安装

### Claude Code 安装（本地路径方式）

1. 克隆本仓库（含 submodule）：

```bash
git clone --recurse-submodules <repo-url> abyss-devflow
cd abyss-devflow
```

如果已经克隆了仓库但没有 submodule，执行：

```bash
git submodule update --init --recursive
```

2. 在 Claude Code 中安装本地插件：

```bash
# 方法一：通过 /plugin 命令（在 Claude Code 中）
/plugin install ./abyss-devflow

# 方法二：手动配置 settings.json
# 在 ~/.claude/settings.json 中添加：
{
  "plugins": {
    "abyss-devflow@local": [
      {
        "scope": "user",
        "installPath": "/path/to/abyss-devflow",
        "version": "1.0.0"
      }
    ]
  }
}
```

3. 重启 Claude Code，执行 `/leader` 验证安装成功。

### 更新插件

```bash
git pull
git submodule update --remote --merge
```

## 快速开始

### 使用 Leader 全流程编排（推荐）

在项目根目录下启动 Claude Code，然后输入：

```
/leader
```

Leader agent 会自动执行完整流程：

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
| `/knowledge-deposit` | 知识沉淀 |
| `/ui-ux-pro-max` | UI/UX 设计 |

## Agents 说明

### Leader Agent

项目生命周期总指挥，只负责编排和验收，不亲自执行阶段工作。每个阶段委派独立 subagent，确保：

- 设计与评审分离（阶段③④必须不同 subagent）
- 开发与审查分离（阶段⑥每个任务开发后独立审查）
- 测试设计与执行分离（阶段⑦⑧必须不同 subagent）
- Stage Gate 机制：PRD/架构/任务拆分/测试完成后等待用户确认

### PRD Agent

PRD 撰写专家，使用 prd skill 完成：

- 逐条提问对齐需求（一次一个问题）
- UI/UX 设计决策自动联动 ui-ux-pro-max skill
- 数据可视化需求联动 dataviz skill
- 已有 PRD 的版本维护和变更记录

## Skills 说明

### Architecture Skill

支持双模式：
- **design**：基于 PRD 输出技术方案
- **review**：独立评审已有方案

核心特性：
- 五类批量术语澄清（冲突/模糊/缺失/重复/矛盾）
- DDD 启发式判断
- 全局 ADR/工程规范对齐
- 多方案对比推荐
- 文档拆分（design-api.md / design-database.md 等）

### Test Skill

测试全流程助手：

- 用例生成（Happy Path/Boundary/Exception/Performance/Security 五维度）
- 用例评审
- 测试执行
- 测试报告
- 多语言/框架支持（Java/Vitest/Playwright/pytest/Go/Rust）
- 按迭代目录组织

### Knowledge Deposit Skill

自动知识沉淀：

- 扫描 inputs/ 目录增量内容
- 按知识类型自动分类到对应目录
- 质量等级评估（A/B/C）
- 自动归档已处理文件
- 自动提交推送到 GitHub

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

本插件使用以下第三方 skill，通过 git submodule 管理：

- [ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) - UI/UX 设计智能
  - 84 UI 风格、192 色板、74 字体组合、98 UX 准则、25 图表类型
  - 支持 22 种技术栈（React、Vue、Svelte、Flutter、SwiftUI 等）

## 自定义配置

### 添加新的 Agent

在 `agents/` 目录下创建新的 `.md` 文件，格式：

```markdown
---
name: agent-name
description: Agent 描述
model: inherit
effort: high
tools: Read, Write, Edit, Glob, Grep, AskUserQuestion, Skill
---

# Agent 标题

具体 prompt 内容...
```

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

### 添加第三方 Skill 作为 Submodule

```bash
git submodule add <git-url> skills/vendor/<skill-name>
```

## 更新日志

### v1.0.0 (2026-07-30)

- 初始版本
- Leader 全流程编排 agent
- PRD agent
- Architecture、PRD、Test、Code Review、TDD、Writing Plans、Knowledge Deposit skills
- 集成 ui-ux-pro-max 第三方 skill

## License

MIT
