# Java 工程分层规范

- **规范级别**: 强制
- **更新日期**: 2026-08-03

## 1. 规范背景

DDD 分层架构的落地需要严格的模块边界。各层职责必须清晰，依赖方向只能单向（外层依赖内层），禁止反向依赖。

## 2. 分层结构

```
apps/server/
├── daerwen-server-parent/       # 父POM，统一依赖管理
├── daerwen-domain/              # 领域层（最底层，无外部依赖）
│   └── src/main/java/com/daerwen/domain/
│       ├── shared/              # 公共基础类
│       ├── member/              # 会员聚合
│       ├── product/             # 商品聚合
│       ├── service/             # 服务聚合
│       ├── entitlement/         # 权益聚合
│       ├── schedule/            # 排期聚合
│       ├── booking/             # 预约聚合
│       ├── order/               # 订单聚合
│       └── rbac/                # 权限聚合
├── daerwen-infrastructure/      # 基础设施层
│   └── src/main/java/com/daerwen/infrastructure/
│       ├── repository/          # 仓储实现 + Mapper
│       ├── persistence/         # DO数据对象 + Assembler
│       ├── cache/               # Redis缓存、分布式锁
│       ├── security/            # JWT、加密
│       └── config/              # MyBatis-Plus配置
├── daerwen-application/         # 应用层
│   └── src/main/java/com/daerwen/application/
│       ├── service/             # ApplicationService（业务编排）
│       ├── command/             # 入参命令
│       ├── dto/                 # 出参DTO
│       └── assembler/           # DTO转换器
├── daerwen-interfaces/          # 接口层
│   └── src/main/java/com/daerwen/interfaces/
│       ├── controller/          # Controller（C端+B端）
│       ├── config/              # SecurityConfig、GlobalExceptionHandler
│       ├── filter/              # JWT过滤器
│       ├── vo/                  # ViewObject
│       └── util/                # 工具类
└── daerwen-start/               # 启动模块
    └── src/main/java/com/daerwen/start/
        └── DaerwenStartApplication.java
```

## 3. 各层职责与依赖规则

### 依赖方向

```
interfaces → application → domain ← infrastructure
     ↓              ↓
  start(聚合)    (不依赖infrastructure)
```

### 各层职责

| 层级 | 职责 | 可依赖 | 禁止依赖 |
|------|------|--------|----------|
| **domain** | 聚合根、实体、值对象、领域服务、领域事件 | 无外部依赖 | infrastructure、application、interfaces |
| **infrastructure** | 仓储实现、持久化、缓存、安全、配置 | domain | application、interfaces |
| **application** | 业务编排（ApplicationService）、Command、DTO、Assembler | domain | infrastructure（通过接口解耦） |
| **interfaces** | Controller、VO、Filter、全局配置 | application | domain 直接调用（必须通过 application） |
| **start** | 启动类、聚合所有模块 | interfaces、application、infrastructure | — |

## 4. 强制规范 (Do's & Don'ts)

- ✅ **必须做**: 聚合之间的调用必须通过 ApplicationService 编排，禁止跨聚合直接调用 Repository
- ✅ **必须做**: Controller 只做参数校验和调用 ApplicationService，禁止写业务逻辑
- ✅ **必须做**: DO（数据对象）与 Domain Entity 必须通过 Assembler 转换，禁止混用
- ✅ **必须做**: 聚合之间通过领域事件或 ApplicationService 通信，禁止直接引用对方的 Repository
- ❌ **严禁做**: domain 层引用 Spring、MyBatis 等框架注解
- ❌ **严禁做**: infrastructure 层包含业务逻辑
- ❌ **严禁做**: interfaces 层直接调用 domain 层（必须经过 application 层）
- ❌ **严禁做**: 在 Controller 中直接操作数据库或缓存

## 5. 编码实现规范

### 5.1 事务使用

- ✅ **必须做**: 仅在 ApplicationService 的**写操作方法**（command）上添加 `@Transactional`
- ✅ **必须做**: 只读查询方法不加事务（除非存在多次读写一致性等特殊诉求，此时显式声明 `@Transactional(readOnly = true)` 并在注释中说明原因）
- ❌ **严禁做**: 在 ApplicationService 类上添加类级别 `@Transactional`（避免无差别地为所有查询方法开启事务）
- ❌ **严禁做**: 在 domain 层、repository 接口上声明事务

### 5.2 Lombok 使用

- ✅ **必须做**: 优先使用 Lombok 注解消除 getter/setter、构造函数、builder 等样板代码
  - 值对象/DTO/VO/Command：`@Getter` + `@RequiredArgsConstructor` 或 `@Builder`
  - 需要全参构造的装配类：`@RequiredArgsConstructor`（配合 `final` 字段做构造器注入）
- ❌ **严禁做**: 手写 getter/setter、无业务含义的构造函数
- ⚠️ **注意**: 领域实体（聚合根/实体）谨慎使用 `@Data`/`@EqualsAndHashCode`，默认按业务唯一标识（如 id）生成 equals/hashCode，避免懒加载字段引发的问题

### 5.3 Repository 接口命名（domain 层）

domain 层 repository 接口只暴露两类查询方法，统一命名：

| 方法 | 用途 | 返回 |
|------|------|------|
| `findById(...)` | 按唯一标识查询**单个**实体 | 聚合根 / `Optional<聚合根>` |
| `findAll(...)` | 按多条件查询并**分页**返回 | `PageResult<聚合根>` |

- ✅ **必须做**: 多条件批量查询一律走 `findAll(query, pageNum, pageSize)`，返回统一分页对象
- ❌ **严禁做**: 出现 `listByXxx`、`selectXxxByXxx`、`queryXxxPage` 等命名各异的查询方法
- ⚠️ **注意**: 写操作方法命名保持 `save` / `deleteById` 等语义化命名

### 5.4 统一分页返回

所有分页查询必须使用同一个泛型分页工具类，放在 `domain/shared` 下，全系统复用：

```java
package com.daerwen.domain.shared;

import lombok.Getter;
import java.util.List;

@Getter
public class PageResult<T> {
    private final long pageNum;        // 当前页码（从 1 开始）
    private final long pageSize;       // 每页大小
    private final long totalPage;      // 总页数
    private final long totalElements;  // 总记录数
    private final List<T> data;        // 当前页数据

    private PageResult(long pageNum, long pageSize, long totalElements, List<T> data) {
        this.pageNum = pageNum;
        this.pageSize = pageSize;
        this.totalElements = totalElements;
        this.totalPage = pageSize == 0 ? 0 : (totalElements + pageSize - 1) / pageSize;
        this.data = data;
    }

    public static <T> PageResult<T> of(long pageNum, long pageSize, long totalElements, List<T> data) {
        return new PageResult<>(pageNum, pageSize, totalElements, data);
    }
}
```

- ✅ **必须做**: application/domain/interfaces 各层间传递分页数据时统一使用 `PageResult<T>`
- ✅ **必须做**: infrastructure 层仓储实现负责将 MyBatis-Plus `IPage`/`Page` 转换为 `PageResult`
- ❌ **严禁做**: 各模块自定义 `PageResponse`、`PageVO`、`PageData` 等等价但重复的分页对象
