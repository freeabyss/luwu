---
name: code-review
description: 代码审查。派发独立 reviewer subagent 对变更进行审查，按严重程度分级问题（阻塞/应修/建议）。可通过对应 slash command 调用，也可被 flow 编排调用。
user-invocable: true
disable-model-invocation: false
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Get git SHAs:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
```

**2. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `{DESCRIPTION}` - Brief summary of what you built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit

**Language standards (important):**

Check whether the diff touches `.java` files. If it does, the reviewer prompt MUST include the team's mandatory Java/DDD engineering standard (layering, transactions, Lombok, Repository naming, unified `PageResult`), under a section titled `## 团队 Java/DDD 工程规范（强制遵循）`:

- **If flow already injected that section into your prompt** (you were dispatched by flow stage ⑥): pass its exact content through into the reviewer prompt verbatim — do not re-read or summarize it.
- **If invoked independently** (no injected section): read the canonical copy at `../flow/references/java-engineering-standard.md` (relative to this SKILL.md) yourself and append its full contents under that section.

The template instructs the reviewer to enforce these rules; without the actual content in its prompt the independent subagent cannot see it. For non-Java diffs, skip this step.

**Personal knowledge base:** A local knowledge base may provide cross-project conventions (`01_global/`) indexed by `<kb>/index.md`. The canonical loading rules live in `../flow/references/knowledge-base-loading.md`.

- **If flow injected a `## 团队通用知识（来自知识库，强制遵循）` section into your prompt** (you were dispatched by flow stage ⑥): pass that content through into the reviewer prompt verbatim under the same section, and tell the reviewer to enforce it — do not re-read the knowledge base.
- **If invoked independently**: resolve the KB path per that file (project `.claude/luwu.json` → `LUWU_KB_PATH` → `~/.luwu/knowledge-base/`); if `<kb>/index.md` exists, read it and load the `01_global/` entries whose "适用场景/阶段" matches code review / ⑥, appending their full contents under that same section.
- If no knowledge base is configured, skip silently and rely on built-in guidance only.

**3. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from docs/superpowers/plans/deployment-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: Missing progress indicators
    Minor: Magic number (100) for reporting interval
  Assessment: Ready to proceed

You: [Fix progress indicators]
[Continue to Task 3]
```

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "I'll just review the diff myself instead of dispatching a reviewer" | You're the coordinator — reviewing the diff inline burns the context window you need to keep driving the work. Dispatch a reviewer subagent: the diff and the evaluation live in its context, and only the findings come back to you. |
| "The reviewer needs my whole session history to understand the change" | Hand it precisely crafted context, never your session's history. That keeps the reviewer on the work product, not your thought process. |

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)
