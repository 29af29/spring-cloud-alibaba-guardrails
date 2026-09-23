# 审查报告产出样例

下面是模式 B（审代码）的完整产出示例。**输入是一段有真实缺陷的代码，输出是分级清单。**

---

## 输入

用户说：

> 帮我检查一下这个取消订单的方法有没有问题

```java
@Service
@AllArgsConstructor
public class OrderServiceImpl implements OrderService {

    private final OrderMapper orderMapper;
    private final StockClient stockClient;

    @Transactional
    public void cancelOrder(Long orderId) {
        try {
            OrderPO order = orderMapper.selectById(orderId);
            if (order.getStatus() == 1) {
                order.setStatus(5);
                orderMapper.updateById(order);
                stockClient.restore(order.getSkuId(), order.getNum());
            }
        } catch (Exception e) {
            log.error("取消失败：" + e.getMessage());
        }
    }

    @GetMapping("/order/{id}")
    public Result<OrderPO> detail(@PathVariable Long id) {
        return Result.success(orderMapper.selectById(id));
    }
}
```

---

## 输出

```markdown
## 审查结论
存在 2 个阻塞问题、3 个严重问题，不建议合入。其中水平越权与并发重复回补库存
会在生产环境直接造成数据与资金损失。

## 问题清单

### [P0] 取消订单未校验归属，存在水平越权
- 位置：OrderServiceImpl.java:11 `cancelOrder`
- 现象：任何登录用户传入他人的 orderId，即可取消他人订单并触发库存回补。
  当前方法只接收 orderId，完全没有用户身份入参。
- 成因：以 ID 为入参的写操作未校验资源归属。
- 建议：方法签名加入 userId，查询后校验归属，不一致时抛 NOT_FOUND（不暴露「存在但不属于你」）。

  @Transactional(rollbackFor = Exception.class)
  public void cancelOrder(Long orderId, Long userId) {
      OrderPO order = orderMapper.selectById(orderId);
      if (order == null || !Objects.equals(order.getUserId(), userId)) {
          throw new BusinessException(ResultCode.NOT_FOUND);
      }
      ...

### [P0] 状态判断与更新分离，并发下会重复回补库存
- 位置：OrderServiceImpl.java:13-17
- 现象：用户点击取消的同时，超时关单定时任务也触发，两个线程都读到 status == 1，
  都能通过判断，于是各自执行一次 update 和一次 stockClient.restore，
  库存被回补两次。updateById 无状态条件，后写覆盖先写，不会报错。
- 成因：先查再判断再更新，中间存在竞态窗口。
- 建议：改为条件更新，用影响行数决定执行权，只有抢到的线程才执行后续动作。

  int rows = orderMapper.cancelIfPending(orderId);
  if (rows == 0) {
      log.info("订单状态已变更，跳过取消流程 orderId={}", orderId);
      return;
  }
  stockClient.restore(order.getSkuId(), order.getNum());

  对应 SQL：
  update order_info set status = 5, cancel_time = now()
  where id = #{id} and status = 1

  另建议：库存回补失败要写入补偿表并配置定时重试，不能只靠调用成功。

### [P1] 事务内调用远程服务，事务与远程调用无法保持一致性
- 位置：OrderServiceImpl.java:17 `stockClient.restore`
- 现象：`@Transactional` 方法内直接调用远程服务。若远程调用成功但后续事务回滚，
  库存已被回补而订单仍是待付款；若远程调用超时（网络抖动），本地事务回滚但远程
  可能已执行成功，出现「幽灵回补」。
- 成因：HTTP 调用不在数据库事务内，无法随事务回滚。
- 建议（二选一）：
  1. 引入分布式事务（Seata AT），并确认被调用方的数据源已接入同一 TC 集群；
  2. 改为最终一致性：本地记录待回补任务（与状态更新同一事务落库），
     由定时任务异步执行并重试。
  注意：AT 模式无法回滚 Redis、MQ 等非事务型资源，涉及这些要走方案 2。

### [P1] 吞异常导致失败被静默忽略
- 位置：OrderServiceImpl.java:18-20
- 现象：catch 住 Exception 后只打一条日志，异常被吞掉，方法正常返回。
  Controller 会返回「操作成功」，但订单可能压根没取消、库存也没回补，
  用户看到成功提示，实际数据未变更。且不重新抛出异常，事务不会回滚。
- 成因：用 try-catch 掩盖了失败。
- 建议：业务异常直接抛出交给全局异常处理器；非预期异常记录完整堆栈后重新抛出，
  由上层决定响应。

  } catch (BusinessException e) {
      throw e;
  } catch (Exception e) {
      log.error("取消订单失败 orderId={}", orderId, e);
      throw new BusinessException(ResultCode.SYSTEM_ERROR);
  }

### [P1] 日志未打印完整堆栈
- 位置：OrderServiceImpl.java:19
- 现象：`log.error("取消失败：" + e.getMessage())` 只输出异常 message，
  排查时看不到调用链与根因，等于没有日志。
- 建议：把异常对象作为最后一个参数传入，让日志框架输出完整堆栈。

  log.error("取消订单失败 orderId={}", orderId, e);

### [P1] 事务注解缺少 rollbackFor
- 位置：OrderServiceImpl.java:10 `@Transactional`
- 现象：未声明 rollbackFor，Spring 默认只对 RuntimeException 回滚，
  若抛出检查型异常则事务不会回滚。
- 建议：统一写为 `@Transactional(rollbackFor = Exception.class)`。

### [P2] 接口直接返回 PO，泄露数据库字段
- 位置：OrderServiceImpl.java:24 `detail`
- 现象：`Result<OrderPO>` 把 PO 直接返回前端。PO 与表结构一一对应，
  后续表结构新增字段（如内部备注、成本价、渠道标识）会立刻变为对外暴露的接口字段。
- 成因：未定义 VO 隔离。
- 建议：定义 OrderVO 只包含允许暴露的字段，在 Service 中转换后返回。

### [P2] 业务逻辑泄漏到 Controller 层
- 位置：OrderServiceImpl.java:23-26
- 现象：`detail` 方法带 `@GetMapping` 与 `@PathVariable`，说明 Controller 的接口定义
  写在了 ServiceImpl 中，分层职责混乱，且该类未被 `@RestController` 标注，该映射不会生效。
- 建议：接口定义归入 `XxxController`，ServiceImpl 只保留业务方法。

## 未发现问题项
- 统一响应体 `Result` 的包装方式正确
- Mapper 层未见业务判断
- 未引入新的 Maven 依赖
- 未发现 SQL 注入风险

## 审查盲区
1. 未看到 `order_info` 表结构与唯一索引定义，无法确认订单号是否有唯一约束；
2. 未看到 `stockClient.restore` 的实现与超时配置，无法判断其失败处理是否完善；
3. 未看到超时关单定时任务的代码，无法确认其与取消操作是否共用同一状态流转逻辑；
4. 未看到库存回补是否已有补偿表。建议补充上述信息后重新审查并发相关部分。
```

---

## 这份产出的几个特点

1. **每条问题都能说清「什么条件下会出什么错」** —— 这是判定 P0/P1 的依据，而不是"感觉不好"
2. **给出可直接采用的代码**，而不是"建议加校验"这类空话
3. **包含未发现问题项** —— 让使用者知道审查覆盖了哪些范围，而不是怀疑被漏看
4. **明确列出审查盲区** —— 看不到的东西不硬猜，说明需要什么信息才能继续
5. **不擅自修改代码** —— 清单交付，等确认后再动手
