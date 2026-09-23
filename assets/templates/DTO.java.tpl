package com.example.{module}.domain.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * {Entity} 新增入参
 * 只包含允许前端提交的字段；校验注解在 Controller 上通过 @Valid 生效。
 */
@Data
@Schema(description = "{Entity}新增入参")
public class {Entity}SaveDTO {

    @NotBlank(message = "名称不能为空")
    @Size(max = 50, message = "名称长度不能超过 50")
    @Schema(description = "名称")
    private String name;

    @NotNull(message = "数量不能为空")
    @Min(value = 1, message = "数量至少为 1")
    @Schema(description = "数量")
    private Integer num;

    // 禁止在此定义 userId、status、amount 等应由服务端决定的字段
}
