package com.example.{module}.domain.vo;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * {Entity} 出参
 * 只包含允许对外暴露的字段，禁止直接返回 PO。
 */
@Data
@Schema(description = "{Entity}信息")
public class {Entity}VO {

    @Schema(description = "主键")
    private Long id;

    @Schema(description = "名称")
    private String name;

    @Schema(description = "数量")
    private Integer num;

    @Schema(description = "创建时间")
    private LocalDateTime createTime;

    // 禁止出现 password、内部状态码、成本价等敏感字段
}
