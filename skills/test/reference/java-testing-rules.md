# Java 测试规范

## 单元测试范围：仅限领域层

Java 项目采用 DDD 四层架构时，**单元测试只覆盖领域层（Domain Layer）**，其余层用集成测试或 API 测试覆盖。

**需要单元测试**：
- 领域实体（Entity）的业务方法
- 领域服务（Domain Service）
- 值对象（Value Object）
- 领域枚举的转换逻辑
- 规格（Specification）模式实现

**不需要单元测试**：
- Controller 层 → 用 API 接口测试
- Application Service 的编排逻辑 → 用集成测试
- Repository / DAO 层 → 用集成测试（真实数据库）
- DTO、VO 等纯数据载体
- 配置类、常量类

**为什么**：领域层是纯 Java（无 Spring 依赖），单元测试运行快、断言集中于业务规则；其他层的价值在于"接线是否正确"，用集成测试更能反映真实行为。给 DTO / 配置类写单测是投入产出比极低的动作。

代码示例见 `java-domain-unit-test.md`。

## API 接口测试规范

### 核心原则：测试代码与服务启动分离

不使用 `@SpringBootTest`，不在测试进程内启动应用。改为：

1. **手动独立启动服务**（`java -jar` / IDE / `./start.sh`）
2. **测试代码用 HTTP 客户端发真实请求**到已启动的服务
3. **测试代码可独立运行**，不依赖 Spring Test 上下文
4. **每个接口一个独立测试类**

**为什么**：`@SpringBootTest` 每次跑测试都要拉起整个上下文，慢且脆；把测试当"外部客户端"看，天然接近真实调用链，也能验证部署产物本身是好的。

### 命名约定

按 REST 动作命名测试类，一个接口一个类：

| 接口 | 测试类 |
|------|--------|
| `POST /api/users` | `UsersCreateApiTest` |
| `GET /api/users/{id}` | `UsersGetApiTest` |
| `PUT /api/users/{id}` | `UsersUpdateApiTest` |
| `DELETE /api/users/{id}` | `UsersDeleteApiTest` |
| `GET /api/users` (列表/查询) | `UsersListApiTest` / `UsersSearchApiTest` |

测试方法按场景命名：`shouldXxxWhenYyy()`。

### 推荐技术栈

- **HTTP 客户端**：REST Assured（DSL 直观）
- **测试框架**：JUnit 5
- **断言**：AssertJ 或 Hamcrest
- **数据校验**：直接连测试库校验最终状态

### 编写要点（10 条）

1. 不使用 `@SpringBootTest`
2. 服务独立启动，测试只发 HTTP 请求
3. 用 REST Assured 发真实请求
4. 每个接口一个独立 Test 类
5. 测试方法按 `shouldXxxWhenYyy` 命名
6. 覆盖三类场景：正常路径 + 参数校验 + 业务异常
7. 用 `@DisplayName` 标注测试意图（中文可读）
8. **双重断言**：HTTP 响应断言 + 数据库状态断言
9. 用测试数据库，`@BeforeEach` 清理和准备数据
10. 认证走真实登录接口拿 Token，不 mock 用户上下文

代码示例（基类封装、认证流程、双重断言）见 `java-api-test.md`。
