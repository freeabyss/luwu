# Java API 接口测试示例

## 概述

> **重要原则**：API 接口测试**不使用 Spring Boot Test 框架启动服务**，而是：
> 1. 手动启动项目服务（`java -jar` 或 IDE 启动）
> 2. 测试代码通过 HTTP 客户端发送真实请求到已启动的服务
> 3. 使用独立的测试数据库环境
> 4. 每个接口对应一个独立测试类

---

## 测试框架选择

推荐使用 **REST Assured** 框架，比 `TestRestTemplate` 更易用、功能更强大。

```xml
<!-- pom.xml 依赖 -->
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <version>5.3.0</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <version>5.10.0</version>
    <scope>test</scope>
</dependency>
```

---

## 测试基类封装

```java
// ApiTestBase.java - 所有 API 测试的基类
package com.example.api;

import io.restassured.RestAssured;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import static io.restassured.RestAssured.given;

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
public abstract class ApiTestBase {

    protected JdbcTemplate jdbcTemplate;
    protected String authToken;

    @BeforeAll
    void globalSetup() {
        // 配置 API 基础地址（从环境变量或配置文件读取）
        RestAssured.baseURI = System.getProperty("api.base.url", "http://localhost");
        RestAssured.port = Integer.getInteger("api.port", 8080);
        RestAssured.basePath = "/api";
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();

        // 初始化数据库连接
        DriverManagerDataSource dataSource = new DriverManagerDataSource();
        dataSource.setUrl(System.getProperty("db.url", "jdbc:mysql://localhost:3306/testdb"));
        dataSource.setUsername(System.getProperty("db.username", "test"));
        dataSource.setPassword(System.getProperty("db.password", "test"));
        jdbcTemplate = new JdbcTemplate(dataSource);
    }

    @BeforeEach
    void baseSetUp() {
        // 每个测试前清理关键表数据
        cleanDatabase();
        // 如果需要认证，先登录获取 token
        if (requireAuthentication()) {
            authToken = loginAndGetToken();
        }
    }

    /**
     * 子类可重写此方法，控制是否需要认证
     */
    protected boolean requireAuthentication() {
        return true;
    }

    /**
     * 登录获取认证 Token
     */
    protected String loginAndGetToken() {
        // 先创建测试用户
        String createUserJson = """
            {
                "username": "tester",
                "email": "tester@example.com",
                "password": "Test@123456"
            }
            """;
        given()
                .contentType(ContentType.JSON)
                .body(createUserJson)
                .when()
                .post("/users")
                .then()
                .statusCode(org.apache.http.HttpStatus.SC_CREATED);

        // 登录获取 token
        String loginJson = """
            {
                "username": "tester",
                "password": "Test@123456"
            }
            """;
        return given()
                .contentType(ContentType.JSON)
                .body(loginJson)
                .when()
                .post("/auth/login")
                .then()
                .statusCode(org.apache.http.HttpStatus.SC_OK)
                .extract()
                .path("token");
    }

    /**
     * 清理数据库（根据项目调整）
     */
    protected void cleanDatabase() {
        jdbcTemplate.update("DELETE FROM order_items");
        jdbcTemplate.update("DELETE FROM orders");
        jdbcTemplate.update("DELETE FROM user_role");
        jdbcTemplate.update("DELETE FROM users");
    }

    /**
     * 获取带认证的请求规范
     */
    protected io.restassured.specification.RequestSpecification givenAuth() {
        return given()
                .contentType(ContentType.JSON)
                .header("Authorization", "Bearer " + authToken);
    }
}
```

---

## 示例一：创建用户接口（POST /api/users）

```java
// UsersCreateApiTest.java
package com.example.api;

import io.restassured.http.ContentType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.api.MethodOrderer;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
@DisplayName("创建用户接口 - POST /users")
class UsersCreateApiTest extends ApiTestBase {

    @Override
    protected boolean requireAuthentication() {
        return false;  // 注册接口不需要认证
    }

    @Nested
    @DisplayName("正常场景")
    class HappyPathTests {

        @Test
        @Order(1)
        @DisplayName("创建用户成功 - 返回201和用户信息")
        void shouldCreateUserSuccessfully() {
            String requestBody = """
                {
                    "username": "zhangsan",
                    "email": "zhangsan@example.com",
                    "password": "Test@123456"
                }
                """;

            given()
                    .contentType(ContentType.JSON)
                    .body(requestBody)
                    .when()
                    .post("/users")
                    .then()
                    .statusCode(201)
                    .body("id", notNullValue())
                    .body("username", equalTo("zhangsan"))
                    .body("email", equalTo("zhangsan@example.com"))
                    .header("Location", notNullValue());

            // 验证数据库写入
            Integer count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM users WHERE username = ?",
                    Integer.class,
                    "zhangsan"
            );
            assert count != null && count == 1 : "用户未写入数据库";
        }
    }

    @Nested
    @DisplayName("参数校验场景")
    class ValidationTests {

        @Test
        @DisplayName("用户名为空 - 返回400")
        void shouldFailWhenUsernameIsEmpty() {
            String requestBody = """
                {
                    "username": "",
                    "email": "zhangsan@example.com",
                    "password": "Test@123456"
                }
                """;

            given()
                    .contentType(ContentType.JSON)
                    .body(requestBody)
                    .when()
                    .post("/users")
                    .then()
                    .statusCode(400)
                    .body("message", containsString("用户名不能为空"));
        }

        @Test
        @DisplayName("邮箱格式错误 - 返回400")
        void shouldFailWhenEmailInvalid() {
            String requestBody = """
                {
                    "username": "zhangsan",
                    "email": "invalid-email",
                    "password": "Test@123456"
                }
                """;

            given()
                    .contentType(ContentType.JSON)
                    .body(requestBody)
                    .when()
                    .post("/users")
                    .then()
                    .statusCode(400);
        }

        @Test
        @DisplayName("密码强度不足 - 返回400")
        void shouldFailWhenPasswordTooWeak() {
            String requestBody = """
                {
                    "username": "zhangsan",
                    "email": "zhangsan@example.com",
                    "password": "123"
                }
                """;

            given()
                    .contentType(ContentType.JSON)
                    .body(requestBody)
                    .when()
                    .post("/users")
                    .then()
                    .statusCode(400);
        }
    }

    @Nested
    @DisplayName("业务异常场景")
    class BusinessExceptionTests {

        @Test
        @DisplayName("用户名已存在 - 返回409")
        void shouldFailWhenUsernameDuplicate() {
            // Given - 先创建一个用户
            String firstUser = """
                {
                    "username": "existing",
                    "email": "existing@example.com",
                    "password": "Test@123456"
                }
                """;
            given()
                    .contentType(ContentType.JSON)
                    .body(firstUser)
                    .when()
                    .post("/users")
                    .then()
                    .statusCode(201);

            // When - 尝试创建同名用户
            String duplicateUser = """
                {
                    "username": "existing",
                    "email": "another@example.com",
                    "password": "Test@123456"
                }
                """;

            // Then
            given()
                    .contentType(ContentType.JSON)
                    .body(duplicateUser)
                    .when()
                    .post("/users")
                    .then()
                    .statusCode(409)
                    .body("message", equalTo("用户名已存在"));
        }
    }
}
```

---

## 示例二：查询用户接口（GET /api/users/{id}）

```java
// UsersGetApiTest.java
package com.example.api;

import io.restassured.http.ContentType;
import org.junit.jupiter.api.*;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@DisplayName("查询用户接口 - GET /users/{id}")
class UsersGetApiTest extends ApiTestBase {

    private Long existingUserId;

    @Override
    protected boolean requireAuthentication() {
        return false;
    }

    @BeforeEach
    void setUpTestData() {
        // 创建测试用户
        String requestBody = """
            {
                "username": "testuser",
                "email": "testuser@example.com",
                "password": "Test@123456"
            }
            """;
        existingUserId = given()
                .contentType(ContentType.JSON)
                .body(requestBody)
                .when()
                .post("/users")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    @Test
    @DisplayName("用户存在 - 返回200和用户信息")
    void shouldReturnUserWhenExists() {
        given()
                .contentType(ContentType.JSON)
                .when()
                .get("/users/{id}", existingUserId)
                .then()
                .statusCode(200)
                .body("id", equalTo(existingUserId.intValue()))
                .body("username", equalTo("testuser"))
                .body("email", equalTo("testuser@example.com"));
    }

    @Nested
    @DisplayName("异常场景")
    class ExceptionTests {

        @Test
        @DisplayName("用户不存在 - 返回404")
        void shouldReturn404WhenUserNotFound() {
            long notExistUserId = 99999L;

            given()
                    .contentType(ContentType.JSON)
                    .when()
                    .get("/users/{id}", notExistUserId)
                    .then()
                    .statusCode(404)
                    .body("message", containsString("用户不存在"));
        }
    }
}
```

---

## 示例三：创建订单接口（需要认证）

```java
// OrdersCreateApiTest.java
package com.example.api;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.hamcrest.Matchers.*;

@DisplayName("创建订单接口 - POST /orders")
class OrdersCreateApiTest extends ApiTestBase {

    @Override
    protected boolean requireAuthentication() {
        return true;  // 订单接口需要认证
    }

    @Nested
    @DisplayName("正常场景")
    class HappyPathTests {

        @Test
        @DisplayName("创建订单成功 - 返回201和订单信息")
        void shouldCreateOrderSuccessfully() {
            String requestBody = """
                {
                    "productId": "PROD-001",
                    "quantity": 2,
                    "addressId": 1
                }
                """;

            givenAuth()  // 使用基类封装的带认证请求
                    .body(requestBody)
                    .when()
                    .post("/orders")
                    .then()
                    .statusCode(201)
                    .body("id", notNullValue())
                    .body("status", equalTo("PENDING"))
                    .body("totalAmount", equalTo("198.00"));
        }
    }

    @Nested
    @DisplayName("异常场景")
    class ExceptionTests {

        @Test
        @DisplayName("未登录创建订单 - 返回401")
        void shouldReturn401WhenNotAuthenticated() {
            String requestBody = """
                {
                    "productId": "PROD-001",
                    "quantity": 2
                }
                """;

            // 故意不携带 token
            given()
                    .contentType(io.restassured.http.ContentType.JSON)
                    .body(requestBody)
                    .when()
                    .post("/orders")
                    .then()
                    .statusCode(401);
        }

        @Test
        @DisplayName("商品库存不足 - 返回409")
        void shouldReturn409WhenStockInsufficient() {
            String requestBody = """
                {
                    "productId": "PROD-001",
                    "quantity": 99999  // 超大数量
                }
                """;

            givenAuth()
                    .body(requestBody)
                    .when()
                    .post("/orders")
                    .then()
                    .statusCode(409)
                    .body("message", containsString("库存不足"));
        }
    }
}
```

---

## 测试执行方式

### 1. 手动启动服务

```bash
# 启动项目（根据实际启动方式）
java -jar target/your-app.jar --spring.profiles.active=test
```

### 2. 运行 API 测试

```bash
# 使用 Maven 运行测试
mvn test -Dtest=**/api/*Test \
    -Dapi.base.url=http://localhost \
    -Dapi.port=8080 \
    -Ddb.url=jdbc:mysql://localhost:3306/testdb \
    -Ddb.username=test \
    -Ddb.password=test
```

### 3. IDE 运行
- 在 IDEA 中直接运行测试类
- 配置 VM options 设置环境变量

---

## 最佳实践

1. **每个接口一个独立测试类**，命名：`{资源}{操作}ApiTest`
2. **测试场景分组**：正常场景、参数校验、业务异常
3. **双重断言**：HTTP 响应断言 + 数据库状态校验
4. **数据隔离**：`@BeforeEach` 清理测试数据
5. **配置外部化**：API 地址、数据库配置不硬编码
6. **失败日志**：请求响应失败时自动打印日志（RestAssured 内置）
