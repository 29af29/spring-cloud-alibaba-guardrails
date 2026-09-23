---
name: spring-cloud-alibaba-guardrails
description: 面向 Spring Boot 3 + Spring Cloud Alibaba 项目的 Java 后端开发护栏，约束 AI 按企业级规范编写或修改 Controller、Service、ServiceImpl、Mapper、DTO、VO、PO，设计统一响应体与全局异常、参数校验、JWT 鉴权与身份透传，以及涉及 Redis、RabbitMQ、Seata、Sentinel、Redisson 的代码；也可在用户要求「检查这个接口」「review 一下」「有没有问题」时，对已写代码按五维度输出分级问题清单。Trigger: Spring Cloud Alibaba, Spring Boot 3, 微服务, 开发规范, code review, 接口审查, 分层规范, 统一响应, 分布式事务, 幂等, 超卖。
agent_created: true
version: 1.0.0
license: MIT
---

# Spring Cloud Alibaba 开发护栏

把「企业级 Java 微服务怎么写」变成 AI 每次都会自动遵守的约束，并在交付前主动挑出自己的问题。

本 Skill 提供两种工作模式，**先判断模式，再按需加载资源**。

## 第 0 步：判断模式并加载资源

| 模式 | 触发场景 | 必须读取 |
|---|---|---|
| **A · 写代码** | 新增或修改 Java 类、新增接口、新增模块 | `references/conventions.md` + `assets/templates/` 下对应骨架 |
| **B · 审代码** | 用户要求检查 / review / 找问题 / 评估某段代码 | `references/review-checklist.md` |
| **补充 · 风险场景** | 代码涉及库存、锁、幂等、MQ、分布式事务、缓存 | 追加读取 `references/pitfalls.md` |

不要一次性读完所有资源。按表格按需读取，避免上下文浪费。

## 铁律（两种模式下都成立）

1. **禁止擅自新增 Maven 依赖。** 需要新依赖时，先说明用途、版本、替代方案，征得同意再改 `pom.xml`。
2. **禁止凭记忆或推测生成字段名、表名、接口路径。** 必须与项目现有代码、API 文档或数据字典核对；项目内找不到依据时，明确说出「此处需确认」而不是编一个。
3. **禁止臆造不存在的类、方法、常量。** 引用前先在项目中确认其真实存在。
4. **禁止吞异常。** 不写空的 `catch`，不写 `catch (Exception e) { return null; }`，不用 try-catch 掩盖逻辑问题。
5. **禁止分层越界。** Controller 不写业务逻辑，Service 不碰 HTTP 协议细节，Mapper 不做业务判断，DTO/VO 不直接当 PO 用。
6. **禁止无依据的重构。** 审查模式下只输出问题清单，不擅自改动代码。

## 模式 A：写代码

按顺序执行，不跳步：

1. **对齐**——先确认字段名、表结构、响应结构、包路径。信息不足就提问，不猜。
2. **读规范**——读取 `references/conventions.md`，按其执行。
3. **套骨架**——从 `assets/templates/` 复制对应模板，替换占位符。骨架已体现分层与注解约定，不要自由发挥。
4. **自查**——按 `references/review-checklist.md` 中的「必查项」自检一遍，把发现的问题在交付说明里列出来。
5. **交付**——说明改了什么文件、为什么这样分层、有没有未决问题。

## 模式 B：审代码

1. 读取 `references/review-checklist.md`。
2. 按其中五个维度逐项检查，**不要只扫一遍就给结论**。
3. 按清单文件末尾规定的格式输出问题清单：问题定位 → 严重级别 → 成因 → 修改建议（含代码片段）。
4. 涉及库存、锁、幂等、MQ、分布式事务的问题，追加读取 `references/pitfalls.md` 对照真实坑位。
5. **只给清单，不改代码。** 用户确认后再进入模式 A 修改。

## 反面清单：AI 写 Java 后端的高频通病

写代码时主动避免以下行为，审代码时优先检查：

- 万能 try-catch 包裹整个方法，异常信息丢失
- 凭空发明工具类、常量类、抽象接口，制造幽灵代码
- 为一个方法写一层没有第二实现的 `XxxService` / `XxxServiceImpl` 抽象（除非项目已有此约定）
- 注释复述代码（`// 设置名称` 后面跟 `setName()`），而非解释原因
- 过度防御：在一个已完成校验的链路里重复校验同一字段
- 只在 Service 加 `@Transactional` 却调用了远程服务或发送 MQ，把外部 IO 拖进事务
- 查询接口返回 PO 而非 VO，把数据库字段裸露给前端
- 分页查询漏掉总数、或先查全量再内存分页
- 新增接口不写 `@Operation` 注解，导致 API 文档缺失

## 资源索引

- `references/conventions.md` —— 工程结构、分层职责、统一响应与异常、鉴权、数据访问、依赖管理、中间件约定
- `references/review-checklist.md` —— 五维度审查清单 + 严重级别定义 + 输出模板
- `references/pitfalls.md` —— 超卖、幂等、事务边界、消息可靠投递等真实坑位与正确做法
- `assets/templates/` —— Controller / Service / ServiceImpl / Mapper / DTO / VO / Result 代码骨架
