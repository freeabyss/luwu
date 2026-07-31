# CLAUDE.md

本文件为 Claude Code 提供 luwu 仓库的操作指南。

---

## 仓库概览

这是一个 Claude Code 插件仓库，沉淀了个人 AI 辅助开发的完整工作流（Leader/PRD/Architecture/TDD/Test 等），支持多平台 Agent 工具。

---

## 目录结构

```
├── .claude-plugin/    # Claude Code 插件配置
├── .codex-plugin/     # Codex 插件配置
├── agents/            # 自定义 agents（leader、prd）
├── skills/            # 自定义 skills
│   ├── architecture/
│   ├── prd/
│   ├── test/
│   ├── code-review/
│   ├── test-driven-development/
│   ├── writing-plans/
│   ├── knowledge-deposit/
│   └── vendor/        # 第三方 skills（git submodule）
├── commands/          # 自定义 slash commands
└── hooks/             # Claude Code hooks
```

---

## 开发规范

### 修改 Agents

修改 `agents/*.md` 文件时：
1. 保持 frontmatter 格式不变（name、description、model、effort、tools）
2. 修改后验证：在新会话中 `/plugin reload` 或重启 Claude Code

### 修改 Skills

修改 `skills/*/SKILL.md` 时：
1. SKILL.md 必须包含 frontmatter（name、description、user-invocable）
2. 附属文件（references、templates、docs）保持在同一 skill 目录下
3. 引用路径使用相对路径，不要硬编码绝对路径

### 第三方 Skills

第三方 skills 通过 git submodule 管理：
- 添加：`git submodule add <url> skills/vendor/<name>`
- 更新：`git submodule update --remote skills/vendor/<name>`
- **不要直接修改 vendor 目录下的文件**，应向上游提 PR 或 fork 后修改

### 添加新平台支持

复制 `.claude-plugin/plugin.json` 格式，创建 `.{platform}-plugin/plugin.json`。

---

## 测试插件

### 在 Claude Code 中加载本地插件

```bash
# 在插件目录下启动 Claude Code，它会自动识别 .claude-plugin/
cd /path/to/luwu
claude
```

或在任意项目中通过 settings.json 引用本地路径。

---

## 发布流程

1. 更新 `package.json` 和 `.claude-plugin/plugin.json` 中的版本号
2. 更新 README.md 的更新日志
3. 提交所有变更
4. 创建 git tag
5. 推送到远程仓库
