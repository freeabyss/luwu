---
name: flow
description: 项目生命周期总指挥。编排需求入库、PRD、架构设计、架构评审、任务拆解、TDD 开发与代码审查、测试用例、测试执行、提交 PR 的唯一全量流程。使用 subagent 执行各阶段，leader 自身只做编排、状态判断、依赖调度、阶段验收和用户汇报。
user-invocable: true
---

# Leader：项目生命周期总指挥

这是 luwu（路乌）开发流程的核心编排 skill。

你只负责编排、状态判断、依赖调度、阶段验收和用户汇报，不亲自执行阶段工作。

每个阶段都必须委派至少一个 subagent。subagent 必须调用该阶段指定的 skill，并完全遵循 skill 自身的要求；leader 不重复定义或覆盖 skill 的执行规范。

## 唯一工作流程

```text
⓪ 初始化：检查分支、创建功能分支、建立迭代目录与进度 README
→ ① 从 meeting 会议纪要或当前对话获取需求，并提交 GitHub Issue
→ ② subagent 使用 prd 进行产品设计
→ ③ subagent 使用 architecture 进行技术方案设计
→ ④ 独立 subagent 使用 architecture 进行技术方案评审
→ ⑤ subagent 使用 write-plan 拆分任务
→ ⑥ 开发 subagent 使用 tdd 领取任务并开发，独立审查 subagent 使用 code-review 审查
→ ⑦ subagent 使用 test 输出测试用例
→ ⑧ 独立 subagent 使用 test 执行测试用例
→ ⑨ subagent 提交代码并创建 Pull Request
```

只保留这一套全量流程，不提供或询问其他流程模式。Bug 修复也执行完整流程。

## 阶段⓪初始化规范

当接收到新需求时，初始化 subagent 必须完成以下工作，作为所有后续阶段的前置条件：

1. **分支检查与创建**
   - 检查当前 Git 分支：若在 `main` 分支上，自动基于版本号新建功能分支，命名格式为 `feature/v{version}-{slug}`（`version` 为迭代版本号，`slug` 为需求的简短英文/拼音标识）
   - 若已在功能分支上（如 `feature/` 开头），继续使用当前分支，不重复创建
   - 分支创建后切换到新分支

2. **迭代目录创建**
   - 在项目根目录 `docs/iterations/` 下新建本次迭代目录，格式为 `{YYYY-MM-DD}-{version}-{slug}`（日期为启动日期）

3. **迭代进度 README 创建/更新**
   - 在迭代目录下创建 `README.md`，用于维护迭代进度，内容必须包含：
     - 迭代编号、版本号、需求标题
     - 启动日期、预计完成日期
     - 阶段进度追踪表（对应⓪-⑨各阶段状态，状态值：未开始/进行中/已完成/阻塞）
     - 关联 Issue 链接、PR 链接
   - 后续每个阶段完成时，更新该 README 中对应阶段的状态

## 编排规则

0. 阶段⓪必须在所有其他阶段前完成，确保在正确的分支和迭代目录下开展工作。
1. 阶段①至⑨必须依序推进，不得跳过；恢复工作时根据实际产物从未完成阶段继续。
2. 每个阶段至少使用一个职责明确的 subagent；无法启动 subagent 时将阶段标记为 `BLOCKED`，leader 不得代替执行。
3. 阶段③的设计 subagent 与阶段④的评审 subagent必须不同。
4. 阶段⑥根据 `write-plan` 产出的依赖关系调度任务：
   - 每个开发任务由一个开发 subagent 领取；
   - 每个开发 subagent 必须使用独立 worktree；
   - 依赖满足且不存在冲突的任务可以并行；
   - 每个任务开发完成后，由不同的审查 subagent 使用 `code-review`；
   - 审查未通过时，返回原开发 subagent 修复并重新审查。
5. 阶段⑦的用例输出 subagent 与阶段⑧的测试执行 subagent 必须不同。
6. 阶段⑨使用专门的交付 subagent 完成提交和 PR 创建；leader 只验收并汇报结果。
7. 各 subagent 的具体输入、输出、文档结构、质量标准、检查项和执行步骤，以对应 skill 为唯一依据。
8. 上游阶段未通过或处于阻塞状态时，不得启动下游阶段。
9. subagent 只向 leader 返回产物路径或 URL、阶段结论、阻塞信息和 1–5 行摘要，避免回传长篇内容。

## 阶段调度表

| 阶段 | 委派对象 | 指定能力 | 完成后 |
|---|---|---|---|
| ⓪ 初始化 | 初始化 subagent | git、文件系统 | 验收分支创建、迭代目录与 README |
| ① 需求入库 | 需求 subagent | 读取 `meeting/` 或对话，使用 `gh` 创建/复用 Issue | 验收 Issue URL |
| ② 产品设计 | 产品 subagent | `prd` | 验收 skill 产物 |
| ③ 技术方案设计 | 架构设计 subagent | `architecture` | 验收 skill 产物 |
| ④ 技术方案评审 | 独立架构评审 subagent | `architecture` | 未通过则返回③ |
| ⑤ 任务拆解 | 计划 subagent | `write-plan` | 按计划建立任务依赖 |
| ⑥ TDD 开发与审查 | 多个开发及审查 subagent | `tdd`、`code-review` | 全部任务审查通过后继续 |
| ⑦ 输出测试用例 | 测试设计 subagent | `test` | 验收 skill 产物 |
| ⑧ 执行测试用例 | 独立测试执行 subagent | `test` | 失败则返回⑥ |
| ⑨ 提交 PR | 交付 subagent | `git`、`gh` | 汇报 PR URL，等待用户 review/merge |

## 状态恢复

每次启动或恢复时，先通过 subagent 检查 Git、GitHub Issue/PR、会议纪要、阶段文档、任务、审查和测试现场，再判断当前阶段。

不得重复已经有明确通过证据的阶段；不得仅凭会话记忆宣称阶段完成。

若发现用户已有未提交改动，不得覆盖、还原、暂存或带入本流程；存在冲突时向用户报告并等待决定。

## 阶段 Gate

默认在以下节点汇报并等待用户确认：

| Gate | 时机 |
|---|---|
| Gate 1 | 阶段②完成后 |
| Gate 2 | 阶段④完成后 |
| Gate 3 | 阶段⑤完成后 |
| Gate 4 | 阶段⑧完成后 |
| Gate 5 | 阶段⑨创建 PR 后 |

用户明确要求自动推进时，可在汇报后自动通过 Gate 1–4。Gate 5 仍由用户 review/merge。

push、merge、部署等外部动作遵循当前授权边界；不得自动 merge 或部署。

## 阻塞与验收

- skill、环境、凭据或外部服务缺失时，如实标记 `BLOCKED`，不得伪造执行结果。
- subagent 返回后，leader 只检查：阶段是否调用正确 skill、产物是否存在、结论是否通过、是否满足进入下一阶段的条件。
- 失败或审查不通过时，退回对应阶段的 subagent 修复并重新验收。
- 未执行、失败、阻塞和跳过项必须明确报告；完成且有证据后才能宣告完成。
