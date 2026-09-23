# 开发规范

适用技术栈：Spring Boot 3.x + Spring Cloud Alibaba + MyBatis-Plus + Java 17+。
凡本文件规定的内容，视为项目既定约定，直接遵守，不再询问；与本文件冲突的写法一律不采用。

---

## 1. 工程结构

### 1.1 模块划分

- 一个业务域一个模块，模块名与业务域同名（如 `xxx-user`、`xxx-order`）。
- 公共能力（响应体、异常、工具、通用配置、注解）集中在 `xxx-common`，业务模块通过依赖引入，不复制粘贴。
- 每个业务模块独立数据库 schema，不跨模块直连他人数据库。
- 跨模块获取数据只走 HTTP 调用或消息队列，**禁止引入其他模块的 Mapper、PO、Service 实现**。

### 1.2 包结构

固定使用以下分层，不新增平行层级：

```
com.<组织>.<项目>.<模块>
├── controller          接口层
├── service             服务接口
│   └── impl            服务实现
├── mapper              数据访问
├── domain
│   ├── dto             入参（前端 → 后端）
│   ├── vo              出参（后端 → 前端）
│   └── po              数据库映射对象
├── config              模块级配置
├── constant            常量与枚举
├── convert             对象转换（存在转换逻辑时才建）
└── client              调用其他模块的 HTTP 客户端（存在跨模块调用时才建）
```

- 类名后缀与所在包一致：`XxxController`、`XxxService`、`XxxServiceImpl`、`XxxMapper`、`XxxDTO`、`XxxVO`、`XxxPO`。
- 不放 `utils` 这类无边界包。工具类若只服务本模块，放在使用它的包内；跨模块共用的工具放 `xxx-common`。

---

## 2. 分层职责

### 2.1 Controller

Controller 只做三件事：**接收参数 → 调用 Service → 包装返回值**。

```java
@RestController
@RequestMapping("/api/xxx")
@Tag(name = "xxx接口")
@AllArgsConstructor
public class XxxController {

    private final XxxService xxxService;

    @GetMapping("/{id}")
    @Operation(summary = "查询xxx详情")
    public Result<XxxVO> detail(@PathVariable Long id) {
        return Result.success(xxxService.getDetail(id));
    }

    @PostMapping
    @Operation(summary = "新增xxx")
    public Result<Void> save(@RequestBody @Valid XxxSaveDTO dto) {
        xxxService.save(dto);
        return Result.success();
    }
}
```

禁止在 Controller 中出现：
- 业务判断（`if` 分支决定业务走向）
- 直接调用 Mapper
- 手动拼装复杂响应对象
- try-catch 业务异常（交给全局异常处理器）
- 在方法体内做对象转换以外的数据处理

身份信息通过方法参数注入（如 `@RequestHeader("X-User-Id") Long userId`），不要在每个方法里重复解析 Token。

### 2.2 Service

- **业务逻辑全部集中在这一层**，包括：业务校验、状态机流转、多表/多服务编排、事务边界。
- 接口与实现分离：`XxxService` 定义在 `service` 包，`XxxServiceImpl` 在 `service.impl` 包。
- 事务注解加在 **ServiceImpl 的公开方法**上，不要在 Controller 或 Mapper 上加。
- 抛出业务异常用统一异常类，不要返回 `null` 表示失败，也不要返回 `Result.fail()`（Controller 层才包装响应）。

```java
@Service
@AllArgsConstructor
public class XxxServiceImpl implements XxxService {

    private final XxxMapper xxxMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void save(XxxSaveDTO dto) {
        if (xxxMapper.existsByName(dto.getName())) {
            throw new BusinessException(ResultCode.PARAM_ERROR, "名称已存在");
        }
        xxxMapper.insert(convert(dto));
    }
}
```

`@Transactional` 必须显式写 `rollbackFor = Exception.class`，因为默认只回滚运行时异常。

### 2.3 Mapper

- 只做数据访问，**不含任何业务判断**。
- 单表 CRUD 优先用 MyBatis-Plus 提供的方法，不手写等价 SQL。
- 条件较多时用 `LambdaQueryWrapper`，避免字符串列名，防止字段改名后静默失效。
- 复杂查询（多表关联、聚合、动态条件）写 XML 或注解 SQL，放在 `resources/mapper/` 下保持可读。
- 批量操作使用 `saveBatch` / `insertBatch`，禁止在 for 循环里逐条 insert。

### 2.4 领域模型

| 类型 | 用途 | 约定 |
|---|---|---|
| DTO | 接收前端入参 | 加 `@Valid` 校验注解；字段只包含必要项 |
| VO | 返回给前端 | 隐藏敏感字段（密码、内部状态、成本价） |
| PO | 数据库映射 | 与表结构一一对应，不直接对外暴露 |

- **禁止把 PO 直接返回给前端**。VO 必须显式定义，即使字段暂时与 PO 完全一致——这是为了后续演进时不破坏接口契约。
- **禁止把 DTO 直接当 PO 入库**。即使字段一致，也通过转换方法隔离，避免前端能写到不该写的列。
- 对象转换优先用显式赋值方法；字段多于 10 个或转换点多时，引入 MapStruct 并在团队内统一（需先确认项目是否已引入）。

### 2.5 跨模块调用

- 优先使用 HTTP 客户端（OpenFeign 或 RestTemplate + 负载均衡）。
- 调用方在自己模块内定义 DTO 接收响应，**不依赖被调用方的领域对象**。
- 所有远程调用必须处理失败：设置超时、捕获异常、给出降级或明确报错，不允许裸调用后假定成功。
- 内部接口路径统一加前缀（如 `/internal/**`），与对外接口物理隔离，并在服务端校验内部调用凭证。

---

## 3. 统一响应与异常

### 3.1 统一响应体

所有接口返回统一结构，不要出现裸对象、裸字符串、`Map`：

```java
public class Result<T> {
    private Integer code;
    private String message;
    private T data;

    public static <T> Result<T> success(T data) { ... }
    public static <T> Result<T> success() { ... }
    public static <T> Result<T> fail(ResultCode resultCode) { ... }
}
```

- 成功统一 `code = 200`，失败按错误码枚举返回。
- HTTP 状态码一律返回 200，业务成败通过 `code` 表达（若项目已有其他约定，遵循现有约定，不自行改动）。
- 增删改成功时 `data` 可为 `null`，用 `Result<Void>` 而非 `Result<Object>`。

### 3.2 错误码

- 错误码集中定义为枚举 `ResultCode`，不在业务代码里硬编码数字。
- 枚举项包含：码值 + 默认提示语。
- 新增错误码时追加，不复用、不改动已有码值的含义。

```java
@Getter
@AllArgsConstructor
public enum ResultCode {
    SUCCESS(200, "操作成功"),
    PARAM_ERROR(400, "参数错误"),
    UNAUTHORIZED(401, "未登录或登录已过期"),
    FORBIDDEN(403, "无权限"),
    NOT_FOUND(404, "资源不存在"),
    SYSTEM_ERROR(500, "系统繁忙，请稍后重试"),
    ;
    private final Integer code;
    private final String message;
}
```

### 3.3 异常处理

- 业务异常统一抛 `BusinessException`，携带错误码与提示语。
- 全局异常处理器统一兜底，集中处理以下类型：

| 异常类型 | 处理方式 |
|---|---|
| `BusinessException` | 返回其携带的错误码与提示语 |
| 参数校验异常（`MethodArgumentNotValidException`、`ConstraintViolationException`） | 取第一条校验失败信息，返回 `PARAM_ERROR` |
| 认证异常 | 返回 `UNAUTHORIZED` |
| 兜底 `Exception` | 记录完整堆栈日志，返回统一提示，**不向前端泄露堆栈或 SQL** |

- 兜底日志必须打印完整堆栈（`log.error("...", e)`），不要只打印 `e.getMessage()`。

### 3.4 参数校验

- 入参校验用 Jakarta Validation 注解（`@NotNull`、`@NotBlank`、`@Min`、`@Size`、`@Pattern`），在 Controller 参数上加 `@Valid`。
- 简单格式校验放注解，业务规则校验放 Service（如「余额是否充足」）。
- 不接受在 Service 里手写 `if (dto.getName() == null) throw ...` 代替注解校验。
- 分页参数统一用分页查询基类，页码从 1 开始，每页数量设上限（如 100），防止恶意大分页。

---

## 4. 鉴权与身份透传

- Token 校验与身份解析在网关统一完成，下游服务不重复解析 Token。
- 网关解析后通过请求头向下游透传身份（如 `X-User-Id`、`X-User-Role`），下游直接读取，不再自行解析 JWT。
- 需要放行的接口（登录、注册、公开查询）通过注解或白名单声明，集中管理，不在 Controller 里逐方法判断。
- **下游服务必须假定请求头可能被伪造**：涉及权限判断时，结合服务端数据校验（如「订单归属用户是否为当前用户」），不能只信任 `X-User-Id` 就放行。
- 内部接口（`/internal/**`）不经网关暴露，并校验内部调用凭证；Feign 拦截器统一携带该凭证。
- 权限判断遵循最小必要：普通用户接口不额外加管理员校验，管理员接口显式声明角色要求。

---

## 5. 数据访问

- 实体基类统一继承 `BaseEntity`，包含创建时间、更新时间、创建人、更新人等公共字段，由 MyBatis-Plus 自动填充，不在业务代码里手动 `set`。
- 主键统一使用雪花 ID 或自增，全项目保持一致，不混用。
- 逻辑删除统一用 `deleted` 字段 + MyBatis-Plus 逻辑删除配置，查询自动过滤，不手写 `where deleted = 0`。
- 分页统一返回 `Page` / 自定义分页 VO，包含 `total`、`pages`、`current`、`records`，字段名前后端保持一致。
- 金额统一用 `BigDecimal`，禁止 `double` / `float`；金额比较用 `compareTo`，不用 `equals`。
- 时间统一用 `LocalDateTime`，不用 `Date`；数据库与时区配置保持一致。
- 查询必须走索引字段，禁止 `like '%xxx'` 前置模糊；确需模糊搜索时使用搜索引擎。
- 禁止在循环中查询数据库（N+1），改为批量查询后在内存组装。

---

## 6. 依赖管理

- 版本统一由父 `pom.xml` 的 `dependencyManagement` 或 BOM 管理，子模块不写版本号。
- **新增依赖前必须确认**：是否已有等价能力（如已有 Hutool 就不再引入 Guava）；是否与现有版本冲突；引入体积是否合理。
- 不引入与项目技术栈重复的框架（如已用 MyBatis-Plus 就不引入 JPA）。
- 删除依赖前确认无引用，使用 `mvn dependency:tree` 检查传递依赖影响。

---

## 7. 中间件使用约定

### 7.1 Redis

- **Key 命名**：`业务:模块:标识`，如 `cart:{userId}`、`auth:token:{userId}`。统一在常量类中定义，禁止在业务代码里散落字符串。
- 使用 `StringRedisTemplate` 存储 JSON，避免默认序列化器带来不可读的二进制内容。
- 所有 Key 必须设置过期时间（除非是明确要求常驻的数据），并在常量类中标注。
- 缓存更新采用 **先更新数据库、再删除缓存**；不要先删缓存再更新数据库。
- 缓存穿透：空结果缓存短 TTL；缓存击穿：热点 Key 加互斥锁或逻辑过期；缓存雪崩：TTL 加随机偏移。
- 不把 Redis 当数据库用。需要持久化、关系查询、事务的数据必须落 MySQL。

### 7.2 消息队列（RabbitMQ）

- **交换机与队列名统一定义在常量类**，包含交换机名、队列名、路由键。
- 生产者：消息体用 JSON，包含业务唯一标识（如订单号）以便消费端幂等；发送前确认消息已持久化。
- 消费者：
  - **必须幂等**——同一消息重复投递不得产生副作用，通过业务状态判断或唯一索引保证。
  - 手动 ACK，处理成功后再确认；处理失败按策略重试或投递死信队列。
  - 不吞异常（`catch` 后不 ACK 也不抛），会导致消息堆积。
- 需要延迟消费时使用延迟队列插件或 TTL + 死信组合，不用 `Thread.sleep`。
- 关键消息采用 **本地消息表**：业务操作与消息记录在同一事务落库，再由定时任务或后台线程投递，保证不丢。
- 消息消费不影响主流程时，考虑加降级：MQ 不可用不应导致主链路失败。

### 7.3 分布式锁（Redisson）

- 加锁粒度尽可能小：锁定具体资源 ID（如 `lock:stock:{skuId}`），不用全局锁。
- 必须设置等待时间与持有时间，避免无限等待；使用看门狗时确保业务执行时间可控。
- **加锁后必须校验业务状态**（双重检查），锁只解决并发进入，不解决状态正确性。
- 锁的释放放在 `finally`，并确认锁归属当前线程。
- 能不使用分布式锁就不使用：能通过数据库原子操作（如 `update ... where stock >= num`）解决的，优先用原子 SQL。

### 7.4 分布式事务（Seata）

- 只在**真正跨服务写操作**时启用，单库事务用本地 `@Transactional` 即可。
- 全局事务方法上标 `@GlobalTransactional`，且方法内应尽量减少远程调用次数与执行时间。
- 参与方（被调用方）的数据库必须接入同一 TC 集群，且数据源代理配置正确，否则回滚无效。
- 注意 AT 模式局限：不支持非事务型存储（如 Redis、MQ）的自动回滚，涉及这些资源时改用最终一致性方案（本地消息表 + 补偿）。
- 回滚失败要有补偿任务与人工处理入口，不能只依赖框架。

### 7.5 限流熔断（Sentinel）

- 限流规则配置在热点接口（下单、秒杀、发券），阈值依据压测结果设定，不凭感觉填。
- 使用 `@SentinelResource` 时**必须指定 `blockHandler` 与 `fallback`**，返回对用户友好的降级响应，不能抛异常给前端。
- 降级逻辑要明确业务语义（「当前人数过多，请稍后再试」），而不是笼统的「系统错误」。

---

## 8. API 文档

- 每个 Controller 加 `@Tag`，每个方法加 `@Operation(summary = "...")`，说明用中文短句。
- 需要说明的入参加 `@Parameter`，复杂对象在 DTO 字段上加 `@Schema`。
- 接口路径遵循 RESTful 风格：资源用名词复数，动作用 HTTP 方法表达；特殊动作用子路径（如 `/api/order/{id}/cancel`）。
- 路径统一加前缀（如 `/api`），版本变更时通过路径版本或头信息区分，不直接破坏已有路径语义。

---

## 9. Git 提交

使用 Conventional Commits，一个提交只做一件事：

```
feat(order): 新增订单取消接口
fix(cart): 修复购物车合并时数量覆盖问题
refactor(auth): 抽取 token 校验逻辑到独立方法
docs(readme): 补充本地启动说明
chore(deps): 升级 MyBatis-Plus 到 3.5.x
```

- 类型：`feat` / `fix` / `refactor` / `docs` / `style` / `test` / `chore`。
- 范围写模块名，不带项目前缀。
- 描述用中文或英文均可，但同一仓库保持一致，动词开头，不加句号。
