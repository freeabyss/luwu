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
├── skills/            # 自定义 skills
│   ├── architecture/
│   ├── prd/
│   ├── test/
│   ├── code-review/
│   ├── test-driven-development/
│   ├── writing-plans/
│   └── vendor/        # 第三方 skills（git submodule）
├── commands/          # 自定义 slash commands
└── hooks/             # Claude Code hooks
```

---

## 开发规范

### 修改 Skills

修改 `skills/*/SKILL.md` 时：

1. SKILL.md 必须包含 frontmatter（name、description、user-invocable）
2. 附属文件（references、templates、docs）保持在同一 skill 目录下
3. 引用路径使用相对路径，不要硬编码绝对路径

### 第三方依赖

第三方 skill / 插件**不放入仓库**（不再使用 `skills/vendor` submodule），统一在根目录 `dependencies.json` 中声明：

- 添加：在 `dependencies.json` 的 `dependencies` 数组追加一条（`name`、`type`=plugin/mcp/skill、`platforms`、`marketplace`、`repo`）
- `install.sh` 安装/更新时会检查依赖是否存在，缺失则通过官方方式（`claude plugin marketplace add` + `claude plugin install`）自动拉取
- 当前第三方依赖的自动安装仅支持 Claude Code 平台；Codex/OpenCode 暂不自动处理

### 添加新平台支持

复制 `.claude-plugin/plugin.json` 格式，创建 `.{platform}-plugin/plugin.json`。

### 其他

修改skill、agent、command后，同步修改README.md文档，使其保持一致

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

