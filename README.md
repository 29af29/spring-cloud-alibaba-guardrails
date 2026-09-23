# Spring Cloud Alibaba Guardrails

> 给 AI 戴上「企业级 Java 微服务」的护具 —— 按规范写代码，按清单挑毛病。

一个面向 **Spring Boot 3 + Spring Cloud Alibaba** 项目的 AI Agent Skill。

装好之后，AI 在你项目里写 Java 后端代码时，会自动遵守分层规范、统一响应契约、鉴权约定；你让它检查刚写完的接口时，它会按五个维度逐项挑错，并给出带严重级别的修复建议。

---

## 为什么需要它

用 AI 写 Java 后端，你是不是遇到过这些：

- **AI 不知道你的项目规矩**，每次新开对话都要重新交代一遍分层、响应体、鉴权方式
- **字段名靠猜**，写出来的 DTO 跟你的表结构对不上
- **顺手加依赖**，`pom.xml` 里突然多出几个没听说过的包
- **Controller 里写业务逻辑**，Service 只当了个转发器
- **并发、事务、幂等的坑照踩**，本地测全过，一压测就出事

这个 Skill 把上述问题变成 AI 每次都会自动执行的约束。它不是一份给人读的规范文档 —— **是给 AI 执行的护栏**。

---

## 特性

| 能力 | 说明 |
|---|---|
| **双模式** | 写代码时约束（模式 A），审代码时挑错（模式 B），自动判断该用哪个 |
| **分层铁律** | Controller / Service / Mapper / DTO-VO-PO 的职责边界，越界即纠正 |
| **统一契约** | `Result` / 错误码枚举 / 全局异常 / 分页返回的标准化约定 |
| **鉴权规范** | 网关鉴权、身份透传、水平越权防护、内部接口隔离 |
| **中间件约定** | Redis Key 命名、MQ 幂等与可靠投递、分布式锁、Seata 事务边界、Sentinel 降级 |
| **12 个代码骨架** | Controller / Service / Impl / Mapper / DTO / VO / PO / Result / ResultCode / PageVO / 异常类 / 全局异常处理器 |
| **12 个真实坑位** | 超卖、幂等、事务自调用失效、消息丢失、缓存不一致、水平越权等，每个都给出错误写法与正确写法 |
| **审查报告模板** | 五个维度 + P0~P3 严重级别 + 固定输出格式，结论可落地 |

---

## 安装

### 方式一：用户级（推荐，所有项目可用）

```bash
git clone <this-repo> ~/.workbuddy/skills/spring-cloud-alibaba-guardrails
```

### 方式二：项目级（随仓库共享给协作者）

```bash
git clone <this-repo> <你的项目>/.workbuddy/skills/spring-cloud-alibaba-guardrails
```

或直接下载仓库，把整个文件夹放进上述任一目录。

安装后无需额外配置，描述匹配到相关任务时会自动加载。

### 在其他 AI 编码工具中使用

`SKILL.md` 遵循 [Agent Skills 开放标准](https://agentskills.io)，**同一份文件可直接用于多个工具**，只需放入对应目录：

| 工具 | 安装目录 | 层级 |
|---|---|---|
| Claude Code | `~/.claude/skills/` | 用户级 |
| OpenAI Codex CLI | `~/.codex/skills/` | 用户级 |
| Gemini CLI | `~/.gemini/skills/` | 用户级 |
| OpenClaw | `~/.openclaw/skills/` | 用户级 |
| WorkBuddy | `~/.workbuddy/skills/` | 用户级 |
| Cursor | `.cursor/skills/` | 项目级 |
| GitHub Copilot | `.github/skills/` | 项目级 |

> 本 Skill 仅使用 `name`、`description` 与 Markdown 正文，未依赖任何平台专有特性，因此可跨平台直接复用。`agent_created` 字段为 WorkBuddy 专属，其他工具会安全忽略。

---

## 使用

### 模式 A：写代码

直接提需求即可，Skill 会自动生效：

```
帮我给商品模块写一个分页查询接口，需要支持按名称模糊搜索和分类筛选
```

AI 会：
1. 先确认字段名与表结构（信息不足就提问，不猜）
2. 读取规范文档
3. 按骨架生成代码
4. 交付前按必查项自检，并列出发现的问题

**也可以显式点名**：

```
按 spring-cloud-alibaba-guardrails 的规范，写一个订单取消接口
```

### 模式 B：审代码

```
帮我检查一下 OrderServiceImpl 的 cancelOrder 方法，有没有问题
```

输出是一份分级清单，而不是笼统的"看起来没问题"：

```
## 审查结论
存在 1 个阻塞问题，需修复后合入。

### [P0] 取消订单未校验归属，存在水平越权
- 位置：OrderServiceImpl.java:58 `cancelOrder`
- 现象：任意登录用户传入他人 orderId 即可取消他人订单
- 成因：未校验订单 userId 与当前用户是否一致
- 建议：查询后校验归属，不一致时抛 NOT_FOUND
  ...

### [P1] 状态判断与更新分离，并发下会重复回补库存
- 位置：OrderServiceImpl.java:64
- ...

## 未发现问题项
参数校验、事务注解位置、异常处理均符合规范。

## 审查盲区
未看到 sku_stock 表的库存扣减 SQL，无法确认是否存在超卖风险。
```

完整样例见 [`examples/review-output-sample.md`](examples/review-output-sample.md)。

---

## 目录结构

```
spring-cloud-alibaba-guardrails/
├── SKILL.md                        入口：模式判断、铁律、资源索引
├── references/
│   ├── conventions.md              开发规范（工程结构/分层/契约/鉴权/中间件）
│   ├── review-checklist.md         审查清单（五维度 + 严重级别 + 输出模板）
│   └── pitfalls.md                 12 个真实坑位：错误写法 vs 正确做法
├── assets/templates/               12 个代码骨架，复制即用
├── examples/                       使用示例与产出样例
├── CHANGELOG.md
└── LICENSE
```

### 加载机制

```
你的需求
   ↓
匹配 description ──→ 命中，加载 SKILL.md
   ↓
按任务类型加载对应资源（不会一次读完）
   ├── 写代码 → conventions.md + 对应骨架
   ├── 审代码 → review-checklist.md
   └── 涉及并发/事务/MQ → 追加 pitfalls.md
```

正常运行时不占用上下文，只在相关任务出现时才按需读取。

---

## 定制成你自己的规范

这份 Skill 里的技术选型（MyBatis-Plus、RabbitMQ、Seata、Sentinel）是主流组合，但每个团队的约定都不同。**改起来很简单，全是 Markdown 和代码模板，不需要写任何程序。**

常见改法：

| 想改什么 | 改哪里 |
|---|---|
| 响应体结构（比如 `code/data/msg` 换成 `status/payload/error`） | `references/conventions.md` 第 3 节 + `assets/templates/Result.java.tpl` |
| 包结构（比如用 `entity` 代替 `po`） | `references/conventions.md` 第 1.2 节 |
| 中间件换成 RocketMQ / Kafka | `references/conventions.md` 第 7.2 节 + `references/pitfalls.md` 第 5、6 节 |
| 不用 Seata，走最终一致性 | 删除 `conventions.md` 第 7.4 节，扩充 `pitfalls.md` 第 4 节 |
| 加团队专属规则 | `SKILL.md` 的「铁律」小节追加 |

改完记得同步更新 `SKILL.md` 里的描述，保持与实际内容一致。

---

## 适用范围

**适合**：
- Spring Boot 3 + Spring Cloud Alibaba 的微服务项目
- 单体 Spring Boot 项目（分层与契约部分完全适用，中间件部分按需取用）
- 想按企业级规范练手、准备面试的学生与求职者
- 需要统一团队 AI 编码规范的开发团队

**不适合**：
- 非 Java 技术栈
- 纯前端、算法、数据处理类项目
- 期望它自动改代码 —— 它是规范与清单，不是代码生成器

---

## 设计原则

1. **约束优先于生成** —— 保证 AI 不越界，比让它写得快更重要
2. **按需加载** —— 主文件精简，细节下沉，不浪费上下文
3. **可验证** —— 每条规则都能对应到具体的检查动作，不是空泛口号
4. **可裁剪** —— 不绑定任何具体项目，全部用占位符，拿到就能改

---

## 贡献

欢迎提交 Issue 与 PR。有价值的贡献方向：

- 补充你踩过的坑（请附错误写法与正确写法）
- 增加其他中间件的约定（RocketMQ / Kafka / XXL-JOB / MinIO）
- 补充代码骨架（Feign Client、定时任务、MQ 消费者）
- 修正规范中过时或不准确的部分

提交前请确认：**内容不包含任何真实项目的密码、内网地址、业务数据。**

---

## License

[MIT](LICENSE)
