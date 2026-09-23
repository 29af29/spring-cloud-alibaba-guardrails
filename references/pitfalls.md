# 高频坑与正确做法

收录并发、事务、消息、缓存场景中真实会出错的写法。**这些坑的共同特点是：本地测试全过，线上才炸。**

写代码遇到相关场景时对照本文；审查代码时优先按本文比对。

---

## 1. 超卖：先查库存再扣库存

**现象**：并发下单时，库存被扣成负数，或卖出数量超过实际库存。

**错误写法**

```java
Stock stock = stockMapper.selectBySkuId(skuId);
if (stock.getNum() >= num) {
    stock.setNum(stock.getNum() - num);
    stockMapper.updateById(stock);
}
```

两个并发请求都可能在第一行读到相同库存，都通过判断，然后各自扣减。

**正确做法**

在 SQL 层做条件更新，把「判断」和「扣减」合成一个原子操作：

```xml
<update id="deductStock">
    update sku_stock
    set stock = stock - #{num}
    where sku_id = #{skuId} and stock >= #{num}
</update>
```

```java
int rows = skuStockMapper.deductStock(skuId, num);
if (rows == 0) {
    throw new BusinessException(ResultCode.STOCK_NOT_ENOUGH);
}
```

**为什么**：数据库的 `update ... where` 在行锁保护下执行，是原子的。应用层的「查了再写」中间存在时间窗口，锁不住。

**补充**：如果业务需要更复杂的判断（限购、按用户维度限流），再叠加分布式锁，并做双重检查。**不要用锁代替原子 SQL，而是用原子 SQL 兜底。**

---

## 2. 幂等：重复请求产生重复数据

**现象**：用户连点提交、网关重试、MQ 重投导致同一笔业务被处理两次（重复下单、重复扣款、重复加分）。

**错误写法**

```java
// 靠前端防重复是不够的
@PostMapping("/order")
public Result<Void> createOrder(@RequestBody OrderCreateDTO dto) {
    orderService.create(dto);  // 没有幂等保护
    return Result.success();
}
```

**正确做法**

分三层，至少做到第一层：

1. **数据库唯一约束（必做）**——为业务唯一键建唯一索引，让重复插入直接失败：

```sql
alter table order_info add unique key uk_order_no (order_no);
```

2. **业务状态判断**——执行前判断状态是否允许该操作：

```java
Order order = orderMapper.selectByOrderNo(orderNo);
if (order.getStatus() != OrderStatus.PENDING_PAY) {
    log.warn("订单状态已变更，忽略重复支付回调 orderNo={}", orderNo);
    return;  // 幂等：直接返回成功，不重复处理
}
```

3. **状态条件更新**——把状态判断放进 SQL，避免并发穿透：

```xml
<update id="markPaid">
    update order_info set status = 2, pay_time = now()
    where order_no = #{orderNo} and status = 1
</update>
```

判断 `rows == 0` 说明已被处理过。

**为什么**：分布式环境下「至少一次投递」是常态，幂等不是可选项，是必须项。唯一索引是最后一道防线，应用层判断会被并发穿透。

---

## 3. `@Transactional` 自调用失效

**现象**：方法上明明加了 `@Transactional`，出错时数据却没回滚。

**错误写法**

```java
@Service
public class OrderServiceImpl {

    public void createOrder(OrderDTO dto) {
        this.saveOrder(dto);   // 自调用，事务不生效
    }

    @Transactional(rollbackFor = Exception.class)
    public void saveOrder(OrderDTO dto) { ... }
}
```

**为什么**：Spring 事务基于 AOP 代理，自调用走的是 `this` 引用，不经过代理对象。

**正确做法**

- 拆到另一个 Bean 中，通过注入调用；
- 或注入自身代理（`AopContext.currentProxy()`，需开启 `exposeProxy`）；
- 或直接把事务加在入口方法 `createOrder` 上（最常用）。

**同时注意**：
- `@Transactional` 加在 `private` / `final` / `static` 方法上无效；
- 默认只回滚 `RuntimeException`，检查型异常不回滚 → **一律显式写 `rollbackFor = Exception.class`**。

---

## 4. 事务内调用远程服务 / 发送 MQ

**现象**：事务还没提交，远程服务或消费者已经读到了数据；或者事务回滚了，消息却已发出，下游按「已发生」处理。

**错误写法**

```java
@Transactional(rollbackFor = Exception.class)
public void createOrder(OrderDTO dto) {
    orderMapper.insert(order);
    stockClient.deduct(dto.getSkuId(), dto.getNum());  // 远程调用在事务内
    rabbitTemplate.convertAndSend("notify.queue", msg); // 消息在事务内已发出
}   // 如果这里抛异常回滚，库存和消息已经出去了
```

**为什么**：
1. 事务未提交时，其他服务/线程看不到本次写入，会造成数据不一致；
2. MQ 发送不在数据库事务内，无法随之回滚；
3. 事务被拉长，数据库连接与行锁持有时间变长，并发能力下降。

**正确做法**

- **远程写操作**用分布式事务（Seata AT）保证，且尽量把它放在事务的最外层、最少次数；
- **消息发送**改为「本地消息表 + 事务提交后投递」：

```java
@Transactional(rollbackFor = Exception.class)
public void createOrder(OrderDTO dto) {
    orderMapper.insert(order);
    // 消息记录与业务在同一事务内落库，保证「业务成功则消息必被记录」
    messageMapper.insert(new LocalMessage("order.created", order.getOrderNo()));
}

// 事务提交后再投递
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void onCommitted(OrderCreatedEvent event) {
    mqSender.send(event);
}
```

再由定时任务扫描未投递成功的消息做补偿。

**为什么可行**：把「保证消息发出」降级为「保证消息被记录」，后者可以由本地事务保证；投递失败通过重试最终达成。

---

## 5. 消息丢失与消费端吞异常

**现象**：MQ 里消息不见了，或消息反复投递却始终没被处理成功，最终堆积。

**错误写法（消费者）**

```java
@RabbitListener(queues = "order.paid.queue")
public void onMessage(Message msg) {
    try {
        orderService.handlePaid(msg);
    } catch (Exception e) {
        log.error("处理失败");   // 吞掉异常，消息被 ACK，永远丢失
    }
}
```

**正确做法**

```java
@RabbitListener(queues = "order.paid.queue")
public void onMessage(Message msg) {
    try {
        orderService.handlePaid(msg);   // 内部保证幂等
    } catch (Exception e) {
        log.error("处理支付消息失败，进入重试", e);
        throw e;   // 抛出 → 不 ACK → 重试或进死信队列
    }
}
```

配套要求：
- 消费者**手动 ACK**，处理成功才确认；
- 配置重试次数与死信队列，超过阈值转入死信并告警；
- 业务异常（如参数非法、状态不允许）应判为「不可重试」，直接 ACK 并记录，避免死循环重试。

**为什么**：`catch` 后不抛也不 ACK 会导致消息一直 unacked 堆积；`catch` 后正常返回则会 ACK 掉失败的消息，永久丢失。两者都是事故。

---

## 6. 缓存与数据库不一致

**现象**：更新数据后，前端看到的还是旧值，且持续不一致。

**错误写法**

```java
redisTemplate.delete(key);      // 先删缓存
productMapper.update(product);  // 再更新数据库
```

并发下：删除缓存后、更新数据库前，另一个请求读到旧数据并回填缓存，之后数据库更新完成，缓存却永久是旧值。

**正确做法**

**先更新数据库，再删除缓存**：

```java
productMapper.update(product);
redisTemplate.delete(cacheKey);
```

可靠性要求更高时使用 **延迟双删**：

```java
redisTemplate.delete(cacheKey);
productMapper.update(product);
// 延迟再删一次，覆盖并发回填的旧值
scheduledExecutor.schedule(() -> redisTemplate.delete(cacheKey), 500, MILLISECONDS);
```

**为什么**：「先更新库再删缓存」在绝大多数场景下不一致窗口极短。真正的一致性保障靠 **给缓存设置过期时间**（兜底）和对强一致要求的数据**直接读库**（不做缓存）。

**原则**：缓存只用于「允许短暂不一致」的数据。余额、库存等强一致数据不要走缓存读。

---

## 7. 分布式锁误用

**现象**：锁没锁住、锁被别的线程释放、或加锁后依然超卖。

**错误写法**

```java
RLock lock = redissonClient.getLock("lock");
lock.lock();                    // 无超时，粒度太大
try {
    Stock stock = mapper.select(skuId);
    if (stock.getNum() >= num) { ... }   // 加锁后没有重新校验
} finally {
    lock.unlock();              // 可能释放非本线程持有的锁
}
```

**正确做法**

```java
RLock lock = redissonClient.getLock("lock:stock:" + skuId);  // 细粒度
boolean locked = lock.tryLock(3, 10, TimeUnit.SECONDS);      // 等待 3s，持有 10s
if (!locked) {
    throw new BusinessException(ResultCode.SYSTEM_BUSY);
}
try {
    // 重新读取最新状态再判断
    int rows = skuStockMapper.deductStock(skuId, num);  // 原子 SQL 兜底
    if (rows == 0) {
        throw new BusinessException(ResultCode.STOCK_NOT_ENOUGH);
    }
} finally {
    if (lock.isHeldByCurrentThread()) {
        lock.unlock();
    }
}
```

要点：
- **锁粒度按资源 ID 拆分**，不要用一把全局锁；
- **必须设置等待时间**，否则线程无限堆积；
- **加锁后重新校验状态**——锁只保证串行进入，不保证数据正确；
- **判定锁归属再释放**（Redisson 的 `isHeldByCurrentThread`）；
- **原子 SQL 兜底**，锁失效时数据仍正确。

**顺带一提**：能用数据库原子操作解决的并发问题，不要引入分布式锁。锁的维护成本和不稳定性远高于一条 `where` 条件。

---

## 8. 水平越权：只信前端传的 ID

**现象**：用户 A 通过改 URL 里的 ID，看到了用户 B 的订单、地址、支付信息。

**错误写法**

```java
@GetMapping("/order/{orderId}")
public Result<OrderVO> detail(@PathVariable Long orderId) {
    return Result.success(orderService.getById(orderId));  // 没校验归属
}
```

**正确做法**

```java
@GetMapping("/order/{orderId}")
public Result<OrderVO> detail(@PathVariable Long orderId,
                              @RequestHeader("X-User-Id") Long userId) {
    return Result.success(orderService.getDetail(orderId, userId));
}

// Service 内
Order order = orderMapper.selectById(orderId);
if (order == null || !order.getUserId().equals(userId)) {
    throw new BusinessException(ResultCode.NOT_FOUND);  // 不暴露「存在但不属于你」
}
```

要点：
- **每一个以 ID 为入参的读写操作都要校验归属**，这是最容易被忽略的安全漏洞；
- 返回「不存在」而非「无权限」，避免泄露资源存在性；
- **不要只信任 `X-User-Id` 请求头**，它可能被伪造（尤其是服务直接暴露时），配合网关白名单与内部凭证使用。

---

## 9. 状态机并发：取消与超时同时发生

**现象**：订单被取消的同时超时任务也触发，库存被回补两次；或两个操作各自成功一半，状态错乱。

**错误写法**

```java
if (order.getStatus() == PENDING_PAY) {
    order.setStatus(CANCELLED);
    orderMapper.updateById(order);
    stockClient.restore(order);   // 两个线程都执行到这里 → 重复回补
}
```

**正确做法**

用**条件更新**让数据库决定谁赢：

```xml
<update id="cancelIfPending">
    update order_info set status = 5, cancel_time = now()
    where id = #{id} and status = 1
</update>
```

```java
int rows = orderMapper.cancelIfPending(orderId);
if (rows == 0) {
    log.info("订单状态已变更，跳过取消流程 orderId={}", orderId);
    return;   // 只有更新成功的那一方才执行后续动作
}
stockClient.restore(order);   // 回补库存
```

**为什么**：判断和更新分离就有竞态。把状态判断塞进 `where` 条件，由数据库的行锁保证只有一个线程能更新成功，`rows` 就是「我是否抢到了执行权」的答案。

**配套**：库存回补失败要登记补偿表（记录订单号、重试次数），由定时任务重试，超过阈值标记人工处理——**异步补偿必须可追溯，不能只打日志。**

---

## 10. N+1 查询

**现象**：列表接口在数据量上来后响应极慢，日志里看到大量重复 SQL。

**错误写法**

```java
List<Order> orders = orderMapper.selectList(wrapper);
for (Order order : orders) {
    // 每个订单查一次商品 → N+1
    Product product = productMapper.selectById(order.getProductId());
    order.setProductName(product.getName());
}
```

**正确做法**

先收集 ID 批量查，再在内存组装：

```java
List<Order> orders = orderMapper.selectList(wrapper);
Set<Long> productIds = orders.stream().map(Order::getProductId).collect(toSet());
Map<Long, Product> productMap = productMapper.selectBatchIds(productIds).stream()
        .collect(toMap(Product::getId, Function.identity()));
orders.forEach(o -> o.setProductName(productMap.get(o.getProductId()).getName()));
```

或用一条关联查询直接返回结果。

**为什么**：N 次网络往返 + N 次 SQL 解析的开销，远大于一次批量查询。数据量 100 条时可能是 100 倍差距。

---

## 11. 大事务

**现象**：并发一上来就出现连接池耗尽、锁等待超时。

**错误写法**

```java
@Transactional(rollbackFor = Exception.class)
public void importData(List<Item> items) {
    for (Item item : items) {          // 事务内循环
        itemMapper.insert(item);        // 批量逐条写
        otherService.doSomething(item); // 事务内调用其他服务
    }
}
```

**正确做法**
- 缩小事务范围：只把必须原子化的数据库操作放进事务；
- 循环外批量写（`saveBatch`，分批提交，如每 500 条一批）；
- 外部调用、文件处理、耗时计算移出事务。

**为什么**：事务期间持有数据库连接与行锁。事务越长，占用资源越久，并发能力呈断崖式下降。

---

## 12. 直接返回 PO / 直接接收 PO 入库

**现象**：接口返回了密码字段；或前端通过多传字段改掉了不该改的列（如余额、角色）。

**错误写法**

```java
@GetMapping("/user/{id}")
public Result<User> detail(@PathVariable Long id) {
    return Result.success(userMapper.selectById(id));  // User 含 password、role
}
```

**正确做法**

- 出参定义 VO，只包含允许暴露的字段；
- 入参定义 DTO，只包含允许修改的字段；
- 需要修改的部分用显式赋值，不用 `BeanUtils.copyProperties` 整体拷贝。

**为什么**：PO 是数据库结构的映射，会随表结构变化；直接对外暴露会让「加一个字段」变成「泄露一个字段」。DTO/VO 是接口契约，必须显式定义。

---

## 速查表

| 场景 | 一句话原则 |
|---|---|
| 扣减库存/余额 | 条件更新到 SQL，用影响行数判断成败 |
| 任何写接口 | 先想幂等：唯一索引 + 状态判断 + 条件更新 |
| 加 `@Transactional` | 确认是公开方法、外部调用、`rollbackFor` 已写 |
| 事务里要发消息 | 改成本地消息表 + 事务提交后投递 |
| 事务里要调远程 | 上分布式事务，或拆到事务外 |
| 消费者 catch 异常 | 要么抛出去重试，要么 ACK 并记录，不能吞 |
| 更新缓存 | 先更新数据库，再删缓存 |
| 用分布式锁 | 细粒度 + 超时 + 锁内重校验 + SQL 兜底 |
| 按 ID 查数据 | 一定校验归属，防水平越权 |
| 状态流转 | 条件更新抢执行权，`rows > 0` 才继续 |
| 循环里查数据库 | 改成批量查询 + 内存组装 |
