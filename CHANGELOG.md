# Changelog

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/)，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [1.0.0] - 2026-09-23

### 新增

- **SKILL.md 主入口**：模式判断（写代码 / 审代码）、六条铁律、AI 常见通病反面清单、资源索引
- **references/conventions.md**：开发规范
  - 工程结构：模块划分原则、固定包结构
  - 分层职责：Controller / Service / Mapper / 领域模型 / 跨模块调用
  - 统一响应与异常：`Result` 结构、错误码枚举、全局异常处理、参数校验
  - 鉴权与身份透传：网关统一鉴权、身份透传、内部接口隔离
  - 数据访问：MyBatis-Plus 约定、分页、金额与时间类型
  - 依赖管理：版本统一、新增依赖的前置确认
  - 中间件约定：Redis / RabbitMQ / Redisson / Seata / Sentinel
  - API 文档与 Git 提交规范
- **references/review-checklist.md**：审查清单
  - 五个维度共 50+ 检查项（正确性 / 并发与一致性 / 健壮性 / 安全 / 可维护性）
  - P0~P3 严重级别定义与判定原则
  - 标准化输出模板
  - 写代码时的 8 条必查项
- **references/pitfalls.md**：12 个高频坑位
  - 超卖、幂等、事务自调用失效、事务内远程调用与发消息、消息丢失与吞异常
  - 缓存与数据库不一致、分布式锁误用、水平越权、状态机并发、N+1 查询、大事务、直接返回 PO
  - 每个坑位包含：现象 → 错误写法 → 正确写法 → 原理说明
  - 附场景速查表
- **assets/templates/**：12 个代码骨架
  - Controller / Service / ServiceImpl / Mapper / DTO / VO / PO
  - Result / ResultCode / PageVO / BusinessException / GlobalExceptionHandler
- **examples/**：使用示例与审查报告产出样例
- **README.md**：安装、使用、定制指南
- **LICENSE**：MIT
