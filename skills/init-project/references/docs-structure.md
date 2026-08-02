# docs/ 目录结构约定

> `init-project` 按此结构搭建项目文档骨架。文档根目录以探测结果为准
> （用户指定 > `docs/README.md` > `doc/README.md` > 默认 `docs/`）。下文以 `docs/` 为例。

## 目录结构

```text
docs/
├── README.md            # 文档地图（本模板）——索引、目录职责、维护者
├── prd/                 # 产品需求文档
│   └── README.md        # as-built 初稿（init-project 生成）→ 后续 /prd 维护
├── architecture/        # 技术方案、ADR、架构图
│   └── README.md        # as-built 初稿 → 后续 /architecture 维护
└── test/                # 测试用例与测试报告
    └── README.md        # as-built 初稿 → 后续 /test 维护
```

`docs/iterations/` **不在此处创建**：它由 `flow` 阶段⓪在每次迭代启动时建立
（命名 `{YYYY-MM-DD}-{version}-{slug}/`），与项目级文档分轨。init-project 不碰它。

## docs/README.md 索引模板

```markdown
# {项目名} 文档

本目录是 {项目名} 的项目文档中心。

## 目录

| 目录 | 内容 | 维护方式 |
|---|---|---|
| [prd/](prd/) | 产品需求：功能清单、用户流程、非功能需求 | `/prd` 生成与更新 |
| [architecture/](architecture/) | 技术方案、架构决策（ADR）、架构图 | `/architecture` design/review |
| [test/](test/) | 测试用例与测试报告 | `/test` 生成/执行 |
| `iterations/` | 各次迭代的过程文档与归档（迭代启动时由 `/flow` 创建） | `/flow` |

## 文档状态说明

`prd/`、`architecture/`、`test/` 下的 README 初始为接入时生成的 **as-built 初稿**
（基于代码逆向整理），用于记录项目现状。后续需求迭代中，由对应 skill 正式产出
to-be 设计并更新这些文档。

## 约定

- 文档根目录下的文件以"最终态"为准：记录结论与设计，不记流水账。
- 新增子目录时在本索引登记其职责与维护方式。
```

## 搭建规则

- `docs/README.md` 必须创建：它是各 skill 自动探测文档目录时的锚点
  （prd/architecture/test 都会"先读文档根下的 README.md"再定位子目录）。
- 三个子目录的 `README.md` 由阶段 3.3 的 as-built subagent 填充实质内容；
  若某类文档用户选择跳过，则创建一个仅含一行说明（"待 /prd 生成"）的占位 README，
  保证目录与索引完整。
- 项目里已存在成熟文档时，不重复创建：在 `docs/README.md` 索引里指向已有位置即可，
  并在汇报中说明。
- 不创建全局知识库（`~/workspace/person/...`）里的文件；那是跨项目资产，由知识沉淀流程维护。
