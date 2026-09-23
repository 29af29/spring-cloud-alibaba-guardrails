package com.example.common.exception;

import com.example.common.result.ResultCode;
import lombok.Getter;

/**
 * 业务异常
 * 业务失败一律抛出此异常，由全局异常处理器统一转换，不在 Service 中返回 null 或手动包装 Result。
 */
@Getter
public class BusinessException extends RuntimeException {

    private final Integer code;

    public BusinessException(ResultCode resultCode) {
        super(resultCode.getMessage());
        this.code = resultCode.getCode();
    }

    public BusinessException(ResultCode resultCode, String message) {
        super(message);
        this.code = resultCode.getCode();
    }
}
