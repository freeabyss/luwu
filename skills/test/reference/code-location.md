# 测试代码存放位置约定

> `iterations/vX.Y.Z/test/` 只放**文档**（用例 + 报告）。测试**代码**跟随源码，按各语言/框架的官方约定就近存放。硬拆到迭代目录会破坏 IDE 索引、测试运行器发现机制和 CI 构建流程。

## Java（Maven / Gradle）

沿用 Maven 标准目录：

```
src/
├── main/java/com/example/
└── test/java/com/example/
    ├── domain/                # 领域层单元测试（贴近被测代码包路径）
    │   ├── UserTest.java
    │   └── OrderTest.java
    └── api/                   # API 接口测试（独立运行，服务外部启动）
        ├── ApiTestBase.java
        └── UsersCreateApiTest.java
```

- 测试类与被测类**同包名**（便于访问 package-private），文件在 `src/test/java` 下同路径
- API 接口测试可以放独立包（如 `api/`），因为它们不依赖具体产品代码的包结构

## 前端 / Node.js（Vitest / Jest）

两种主流约定二选一，团队保持统一：

**A. 共置（推荐用于组件级）**：测试文件紧挨源码
```
src/
├── components/
│   ├── UserCard.vue
│   └── UserCard.test.ts      # 就在旁边
└── utils/
    ├── format.ts
    └── format.test.ts
```

**B. 集中（推荐用于集成/E2E）**：单独 `__tests__/` 或 `tests/`
```
src/
├── components/UserCard.vue
└── __tests__/
    └── components/UserCard.test.ts
```

文件后缀：`*.test.ts` / `*.spec.ts`（Vitest / Jest 默认识别）。

## Playwright / Cypress（E2E）

E2E 独立于源码，放项目根下的独立目录：

```
project/
├── src/
└── tests/                    # 或 e2e/
    ├── login.spec.ts
    ├── checkout.spec.ts
    └── fixtures/
```

配置文件（`playwright.config.ts` / `cypress.config.ts`）在项目根。

## Python（pytest）

两种主流方式：

**A. 顶层 `tests/`**（推荐）：
```
project/
├── src/mypackage/
└── tests/
    ├── test_user.py
    └── test_order.py
```

**B. 包内 `tests/`**（适合库项目）：
```
project/
└── src/mypackage/
    ├── user.py
    └── tests/test_user.py
```

## Go

Go 强制约定：测试文件与被测文件**同目录同包**：

```
project/
└── internal/user/
    ├── user.go
    └── user_test.go          # 必须以 _test.go 结尾
```

## Rust

Cargo 约定：

- 单元测试写在被测文件末尾 `#[cfg(test)] mod tests {}`
- 集成测试放 `tests/` 目录：
```
project/
├── src/lib.rs
└── tests/
    └── integration_test.rs
```

## 通用原则

1. **就近**：测试代码贴近被测代码，IDE 一键跳转，重构不失联
2. **约定优先**：遵循语言/框架官方约定，测试运行器自动发现，无需额外配置
3. **测试数据独立**：夹具（fixtures）、mock 数据、样例文件放对应测试目录下的 `fixtures/`、`__fixtures__/`、`testdata/` 等子目录
4. **CI 配置在根**：`Makefile`、`.github/workflows/`、`vitest.config.ts` 等运行配置留在项目根，不进 `iterations/`

## 什么该进 `iterations/vX.Y.Z/test/`

只有两类：

| 类型 | 位置 | 格式 |
|------|------|------|
| **测试用例文档** | `cases/{module}-testcases.md` | Markdown，写给人看 |
| **测试报告** | `report/test-report-YYYYMMDD-HHmm.md` | Markdown，一次执行一份 |

**不进的**：`.java`、`.ts`、`.py`、`.go` 源码；`pom.xml`、`package.json`、`playwright.config.ts` 等构建配置；截图、录屏等运行产物（若需归档，报告里贴相对路径引用）。
