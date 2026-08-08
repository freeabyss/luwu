# 00_template/ — 用户自定义模板

本目录存放你自己的文档模板，用来覆盖陆吾插件内置的 `references/` 模板。

## 使用方式

1. 把自定义模板放进本目录（可建子目录）。
2. 在知识库根的 `../index.md`「模板」表登记一行，写明：
   - 本目录内的相对路径
   - 覆盖哪个内置模板（相对插件 skill 根的路径，如 `prd/references/PRD_TEMPLATES.md`）
   - 适用的 skill（prd / architecture / test …）
3. Agent 加载时优先用本目录的模板；未登记或未命中时回退到插件内置模板。

## 可覆盖的内置模板

| skill | 内置模板 |
|---|---|
| prd | `prd/references/PRD_TEMPLATES.md` |
| architecture | `architecture/references/architecture-template.md` |
| architecture | `architecture/references/adr-template.md` |
| architecture | `architecture/references/context-template.md` |
| architecture | `architecture/references/mermaid-examples.md` |
| init-project | `init-project/references/agents-md-template.md` |
| init-project | `init-project/references/docs-structure.md` |

完整加载与映射规则见插件内 `skills/flow/references/knowledge-base-loading.md`。
