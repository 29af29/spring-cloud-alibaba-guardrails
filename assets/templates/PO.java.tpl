package com.example.{module}.domain.po;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * {Entity} 持久化对象
 * 与表结构一一对应，禁止直接对外暴露。
 */
@Data
@TableName("{table_name}")
public class {Entity}PO {

    @TableId(type = IdType.ASSIGN_ID)
    private Long id;

    private Long userId;

    private String name;

    private Integer num;

    private Integer status;

    @TableLogic
    private Integer deleted;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createTime;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updateTime;
}
