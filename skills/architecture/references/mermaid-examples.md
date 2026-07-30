# Mermaid 架构图示例

## 1. 分层架构图

```mermaid
graph TD
    A[用户层<br>Web/App] --> B[网关层<br>Nginx/API Gateway]
    B --> C[应用层<br>Application Service]
    C --> D[领域层<br>Domain Service]
    D --> E[基础设施层<br>Repository/DAO]
    E --> F[(数据库)]
    
    style A fill:#e1f5fe
    style B fill:#b3e5fc
    style C fill:#81d4fa
    style D fill:#4fc3f7
    style E fill:#29b6f6
    style F fill:#0288d1,color:white
```

## 2. 微服务架构图

```mermaid
graph TB
    Client[客户端] --> Gateway[API网关]
    
    subgraph 业务服务
        Gateway --> Order[订单服务]
        Gateway --> User[用户服务]
        Gateway --> Product[商品服务]
        Gateway --> Pay[支付服务]
    end
    
    subgraph 基础服务
        Order --> MQ[消息队列]
        Pay --> MQ
        Order --> Cache[(Redis缓存)]
        User --> Cache
    end
    
    subgraph 数据层
        Order --> DB1[(订单DB)]
        User --> DB2[(用户DB)]
        Product --> DB3[(商品DB)]
    end
    
    style Gateway fill:#ffccbc
    style Client fill:#f5f5f5
```

## 3. 部署架构图

```mermaid
graph LR
    subgraph 互联网
        User[用户]
    end
    
    subgraph 公有云
        LB[负载均衡<br>SLB/ALB]
        User --> LB
        
        subgraph K8s集群
            LB --> Pod1[Pod A]
            LB --> Pod2[Pod B]
            LB --> Pod3[Pod C]
        end
        
        subgraph 数据存储
            Pod1 --> RDS[(RDS MySQL)]
            Pod2 --> Redis[(Redis)]
            Pod3 --> OSS[对象存储]
        end
    end
```

## 4. 时序图 - 用户下单

```mermaid
sequenceDiagram
    participant U as 用户
    participant F as 前端
    participant G as API网关
    participant O as 订单服务
    participant P as 支付服务
    
    U->>F: 提交订单
    F->>G: 创建订单请求
    G->>O: 创建订单
    O->>O: 生成订单号
    O-->>G: 订单创建成功
    G-->>F: 返回订单ID
    F->>U: 跳转到支付页
    
    U->>F: 确认支付
    F->>G: 发起支付
    G->>P: 调用支付接口
    P->>P: 处理支付逻辑
    P-->>G: 支付结果
    G-->>F: 支付成功
    F-->>U: 支付完成
```

## 5. C4模型 - Container图

```mermaid
graph TB
    subgraph "电商系统"
        Web[Web应用<br>React/Vue]
        App[移动App<br>iOS/Android]
        API[API服务<br>Spring Boot]
        Worker[后台Worker<br>异步任务]
        
        Web --> API
        App --> API
        API --> DB[(关系数据库)]
        API --> Cache[(Redis)]
        API --> MQ[消息队列]
        Worker --> MQ
        Worker --> DB
    end
```

## 6. DDD 领域模型图

```mermaid
classDiagram
    class 订单 {
        +订单ID
        +用户ID
        +订单金额
        +订单状态
        +创建时间
        +创建订单()
        +取消订单()
        +支付()
    }
    
    class 订单项 {
        +商品ID
        +商品名称
        +单价
        +数量
        +小计
    }
    
    class 用户 {
        +用户ID
        +用户名
        +手机号
        +余额
    }
    
    class 商品 {
        +商品ID
        +商品名称
        +价格
        +库存
    }
    
    订单 "1" --> "*" 订单项 : 包含
    订单 "*" --> "1" 用户 : 属于
    订单项 "*" --> "1" 商品 : 对应
```

## 使用建议

1. **优先使用文字描述**：复杂架构先用文字说明，再考虑画图
2. **保持简洁**：一张图不要超过10个节点，否则可读性差
3. **分层清晰**：使用不同颜色区分不同层级
4. **粒度适中**：根据文档目的选择合适的抽象级别
5. **配合说明**：图下必须有文字说明，不要只放图
