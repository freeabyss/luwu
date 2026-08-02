# AGENTS.md 模板

> 这是给 `init-project` 填充 `AGENTS.md`（Codex / OpenCode / Cursor 等通用 Agent 指令）的模板。
> 内容应与 CLAUDE.md **核心一致**，但：
> - 不使用 Claude 专属语法（`@路径` 注入、斜杠命令等），改用普通 Markdown 链接和文字说明
> - 用面向"任何 AI 编码 Agent"的中立措辞
> - 工作流一节，把 luwu 的 slash command 描述为"若当前环境支持该插件/命令则使用"，因为并非所有 Agent 都加载了 luwu

---

```markdown
# AGENTS.md

> 本文件为在本仓库工作的 AI 编码 Agent（Codex、OpenCode、Cursor 等）提供项目上下文。

## Project Overview

{One sentence: what this project is and what problem it solves.}

- Language / Framework: {e.g. Java 17 + Spring Boot 3}
- Build tool: {Maven / Gradle / pnpm ...}
- Package manager: {...}

## Common Commands

{Only commands that actually work in this repo. Verify them. Mark uncertain ones as TBC.}

```bash
# Install dependencies
{cmd}

# Run locally
{cmd}

# Build
{cmd}

# Run tests
{cmd}

# Lint / format
{cmd}
```

## Code Structure

{Source layout and layering. List key directories and responsibilities.}

```
{key dirs only}
├── src/...        # {what}
└── ...
```

{Layering / architectural conventions.}

## Documentation

```text
docs/
├── prd/            # Product requirements (features, user flows, NFRs)
├── architecture/   # Technical design, ADRs, architecture diagrams
├── test/           # Test cases and test reports
└── iterations/     # Per-iteration docs and archives (created by /flow)
```

- Product requirements: [docs/prd/README.md](docs/prd/README.md)
- Architecture & technical design: [docs/architecture/README.md](docs/architecture/README.md)
- Test cases & reports: [docs/test/README.md](docs/test/README.md)
- Iteration records: `docs/iterations/` (created per iteration by `/flow`)

Read these before making non-trivial changes so your work matches the existing design and test coverage.

## Conventions & Constraints

{Naming, branching model, commit message format, directories/files not to touch,
engineering rules that must be followed. Only list real, enforced conventions.}

- {e.g. commit messages follow Conventional Commits: feat/fix/...}
- {e.g. do not edit generated code under .../}

## Workflow (if the luwu plugin is available)

If your environment loads the luwu（陆吾）workflow plugin, prefer these commands:

- Start a new requirement/iteration: `/flow` (end-to-end: requirement → architecture → plan → TDD → test → PR)
- Product requirements: `/prd`
- Architecture design / review: `/architecture`
- Task breakdown: `/writing-plans`
- TDD development: `/test-driven-development`
- Code review: `/code-review`
- Testing: `/test`

Without the plugin, follow the same intent: clarify requirements first, write a short design,
break work into small tasks, add tests, and keep changes reviewable.
```

---

## 填写要点

- 与 CLAUDE.md 共享同一份事实来源（命令、结构、约定），避免两份文件漂移。
- 不写 `@` 注入、Claude 斜杠命令等专属语法；斜杠命令放到"if available"一节。
- 对不加载 luwu 的 Agent，仍要给出可独立遵循的通用工作流指引（最后一段）。
- 若项目同时存在 CLAUDE.md 和 AGENTS.md，维护时保持二者核心信息同步。
