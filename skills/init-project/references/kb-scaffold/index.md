# 知识库索引

> 本文件是陆吾（luwu）知识库的入口。Agent 工作前先读本文件，按「适用场景/阶段」
> 筛选，只 Read 命中的文件，不要全量加载整个知识库。模板以 `00_template/` 为优先，
> 命中即替代对应内置模板；未命中则用插件内置的 `references/`。
>
> 加载规则的权威说明见插件内 `skills/flow/references/knowledge-base-loading.md`。

## 通用知识 01_global/

放跨项目复用的通用知识：编码红线、架构原则、领域术语、API 约定、业务规则等。
只存最终态和提炼后的资产，不存流水账。

示例行（启用时删掉本说明行、把示例改成你的真实文件）：
`01_global/coding-style.md` ｜ 编码红线与命名规范 ｜ ⑥开发、⑥代码审查

| 文件 | 作用 | 适用场景/阶段 |
|---|---|---|
| _（在此登记；未登记的文件不会被加载）_ | _待填_ | _待填_ |

## 模板 00_template/

放用户自定义文档模板，用来覆盖插件内置模板。「覆盖的内置模板」列填写被替代的
内置模板相对路径（相对插件 skill 根），例如 `architecture/references/architecture-template.md`。

示例行：`00_template/architecture.md` ｜ `architecture/references/architecture-template.md` ｜ architecture

| 文件 | 覆盖的内置模板 | 适用 skill |
|---|---|---|
| _（在此登记）_ | _待填_ | _待填_ |
