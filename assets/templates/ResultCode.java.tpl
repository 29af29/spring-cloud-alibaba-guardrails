package com.example.common.result;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 错误码枚举
 * 业务代码中禁止硬编码数字码值；新增错误码只追加，不复用已有码值表达新语义。
 */
@Getter
@AllArgsConstructor
public enum ResultCode {

    SUCCESS(200, "操作成功"),

    PARAM_ERROR(400, "参数错误"),
    UNAUTHORIZED(401, "未登录或登录已过期"),
    FORBIDDEN(403, "无权限"),
    NOT_FOUND(404, "资源不存在"),

    SYSTEM_ERROR(500, "系统繁忙，请稍后重试"),

    // 业务错误码从 1000 起递增，按模块分段
    STOCK_NOT_ENOUGH(1001, "库存不足"),
    ORDER_STATUS_ERROR(1002, "订单状态不允许该操作"),
    ;

    private final Integer code;

    private final String message;
}
