# Java 领域层单元测试示例

## 概述

> **单元测试仅适用于领域层代码**，包含：
> - 领域实体（Entity）的业务方法
> - 领域服务（Domain Service）
> - 值对象（Value Object）
> - 规格（Specification）模式实现

---

## 示例：订单领域实体测试

### 领域实体代码

```java
// Order.java - 领域实体
public class Order {
    private Long id;
    private OrderStatus status;
    private BigDecimal totalAmount;
    private List<OrderItem> items;

    public static Order createNew() {
        Order order = new Order();
        order.status = OrderStatus.DRAFT;
        order.totalAmount = BigDecimal.ZERO;
        order.items = new ArrayList<>();
        return order;
    }

    public void addItem(OrderItem item) {
        if (status != OrderStatus.DRAFT) {
            throw new IllegalStateException("只能在草稿状态添加商品");
        }
        if (item == null || item.getQuantity() <= 0) {
            throw new IllegalArgumentException("商品数量必须大于0");
        }
        items.add(item);
        recalculateTotal();
    }

    public void removeItem(String productId) {
        if (status != OrderStatus.DRAFT) {
            throw new IllegalStateException("只能在草稿状态移除商品");
        }
        items.removeIf(item -> item.getProductId().equals(productId));
        recalculateTotal();
    }

    public void confirm() {
        if (items.isEmpty()) {
            throw new IllegalStateException("订单无商品，无法确认");
        }
        if (totalAmount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalStateException("订单金额必须大于0");
        }
        this.status = OrderStatus.CONFIRMED;
    }

    public void cancel(String reason) {
        if (status == OrderStatus.CANCELLED) {
            throw new IllegalStateException("订单已取消");
        }
        if (reason == null || reason.trim().isEmpty()) {
            throw new IllegalArgumentException("取消原因不能为空");
        }
        this.status = OrderStatus.CANCELLED;
    }

    private void recalculateTotal() {
        this.totalAmount = items.stream()
                .map(OrderItem::getSubtotal)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // Getters...
}
```

### 单元测试代码

```java
// OrderTest.java
package com.example.domain;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("订单领域实体测试")
class OrderTest {

    @Nested
    @DisplayName("创建订单测试")
    class CreateOrderTests {

        @Test
        @DisplayName("新建订单状态为草稿，金额为0")
        void shouldCreateDraftOrderWithZeroAmount() {
            // When
            Order order = Order.createNew();

            // Then
            assertEquals(OrderStatus.DRAFT, order.getStatus());
            assertEquals(BigDecimal.ZERO, order.getTotalAmount());
            assertTrue(order.getItems().isEmpty());
        }
    }

    @Nested
    @DisplayName("添加商品测试")
    class AddItemTests {

        @Test
        @DisplayName("草稿状态下正常添加商品")
        void shouldAddItemSuccessfullyWhenDraft() {
            // Given
            Order order = Order.createNew();
            OrderItem item = new OrderItem("PROD-001", new BigDecimal("99.00"), 2);

            // When
            order.addItem(item);

            // Then
            assertEquals(1, order.getItems().size());
            assertEquals(new BigDecimal("198.00"), order.getTotalAmount());
        }

        @Test
        @DisplayName("已确认状态添加商品抛出异常")
        void shouldThrowExceptionWhenAddItemToConfirmedOrder() {
            // Given
            Order order = Order.createNew();
            order.addItem(new OrderItem("PROD-001", new BigDecimal("99.00"), 1));
            order.confirm();

            // When & Then
            OrderItem newItem = new OrderItem("PROD-002", new BigDecimal("50.00"), 1);
            IllegalStateException exception = assertThrows(
                    IllegalStateException.class,
                    () -> order.addItem(newItem)
            );
            assertEquals("只能在草稿状态添加商品", exception.getMessage());
        }

        @Test
        @DisplayName("添加数量为0的商品抛出异常")
        void shouldThrowExceptionWhenItemQuantityIsZero() {
            // Given
            Order order = Order.createNew();
            OrderItem invalidItem = new OrderItem("PROD-001", new BigDecimal("99.00"), 0);

            // When & Then
            assertThrows(IllegalArgumentException.class, () -> order.addItem(invalidItem));
        }

        @Test
        @DisplayName("添加空商品抛出异常")
        void shouldThrowExceptionWhenItemIsNull() {
            // Given
            Order order = Order.createNew();

            // When & Then
            assertThrows(IllegalArgumentException.class, () -> order.addItem(null));
        }
    }

    @Nested
    @DisplayName("确认订单测试")
    class ConfirmOrderTests {

        @Test
        @DisplayName("有商品的订单确认成功")
        void shouldConfirmSuccessfullyWithItems() {
            // Given
            Order order = Order.createNew();
            order.addItem(new OrderItem("PROD-001", new BigDecimal("99.00"), 1));

            // When
            order.confirm();

            // Then
            assertEquals(OrderStatus.CONFIRMED, order.getStatus());
        }

        @Test
        @DisplayName("空订单确认抛出异常")
        void shouldThrowExceptionWhenConfirmEmptyOrder() {
            // Given
            Order order = Order.createNew();

            // When & Then
            assertThrows(IllegalStateException.class, () -> order.confirm());
        }

        @Test
        @DisplayName("零金额订单确认抛出异常")
        void shouldThrowExceptionWhenConfirmZeroAmountOrder() {
            // Given
            Order order = Order.createNew();
            OrderItem freeItem = new OrderItem("FREE-001", BigDecimal.ZERO, 1);
            order.addItem(freeItem);

            // When & Then
            assertThrows(IllegalStateException.class, () -> order.confirm());
        }
    }

    @Nested
    @DisplayName("取消订单测试")
    class CancelOrderTests {

        @Test
        @DisplayName("正常取消订单成功")
        void shouldCancelOrderSuccessfully() {
            // Given
            Order order = Order.createNew();
            order.addItem(new OrderItem("PROD-001", new BigDecimal("99.00"), 1));
            order.confirm();

            // When
            order.cancel("用户主动取消");

            // Then
            assertEquals(OrderStatus.CANCELLED, order.getStatus());
        }

        @Test
        @DisplayName("取消原因不能为空")
        void shouldThrowExceptionWhenCancelReasonEmpty() {
            // Given
            Order order = Order.createNew();
            order.addItem(new OrderItem("PROD-001", new BigDecimal("99.00"), 1));
            order.confirm();

            // When & Then
            assertThrows(IllegalArgumentException.class, () -> order.cancel(""));
        }

        @Test
        @DisplayName("已取消订单不能重复取消")
        void shouldThrowExceptionWhenCancelAlreadyCancelledOrder() {
            // Given
            Order order = Order.createNew();
            order.addItem(new OrderItem("PROD-001", new BigDecimal("99.00"), 1));
            order.confirm();
            order.cancel("第一次取消");

            // When & Then
            assertThrows(IllegalStateException.class, () -> order.cancel("重复取消"));
        }
    }
}
```

---

## 最佳实践

1. **命名规范**
   - 测试类名：`{领域对象名}Test`
   - 测试方法名：`should{期望行为}When{场景条件}`

2. **结构组织**
   - 使用 `@Nested` 按业务场景分组测试
   - 使用 `@DisplayName` 提供可读的测试描述

3. **测试覆盖**
   - 正常流程（Happy Path）
   - 边界条件（Boundary）
   - 异常场景（Exception）
   - 业务规则校验

4. **断言原则**
   - 断言具体的异常消息，而非仅断言异常类型
   - 金额比较使用 `compareTo()` 而非 `equals()`
