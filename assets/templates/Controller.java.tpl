package com.example.{module}.controller;

import com.example.common.result.PageVO;
import com.example.common.result.Result;
import com.example.{module}.domain.dto.{Entity}PageDTO;
import com.example.{module}.domain.dto.{Entity}SaveDTO;
import com.example.{module}.domain.dto.{Entity}UpdateDTO;
import com.example.{module}.domain.vo.{Entity}VO;
import com.example.{module}.service.{Entity}Service;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.AllArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * {Entity} 接口
 * 职责：接收参数 → 调用 Service → 包装 Result。不写业务逻辑。
 */
@RestController
@RequestMapping("/api/{module}")
@Tag(name = "{Entity}接口")
@AllArgsConstructor
public class {Entity}Controller {

    private final {Entity}Service {entity}Service;

    @GetMapping("/page")
    @Operation(summary = "分页查询{Entity}")
    public Result<PageVO<{Entity}VO>> page({Entity}PageDTO dto,
                                           @RequestHeader("X-User-Id") Long userId) {
        return Result.success({entity}Service.pageList(dto, userId));
    }

    @GetMapping("/{id}")
    @Operation(summary = "查询{Entity}详情")
    public Result<{Entity}VO> detail(@PathVariable Long id,
                                     @RequestHeader("X-User-Id") Long userId) {
        return Result.success({entity}Service.getDetail(id, userId));
    }

    @PostMapping
    @Operation(summary = "新增{Entity}")
    public Result<Void> save(@RequestBody @Valid {Entity}SaveDTO dto,
                             @RequestHeader("X-User-Id") Long userId) {
        {entity}Service.save(dto, userId);
        return Result.success();
    }

    @PutMapping("/{id}")
    @Operation(summary = "修改{Entity}")
    public Result<Void> update(@PathVariable Long id,
                               @RequestBody @Valid {Entity}UpdateDTO dto,
                               @RequestHeader("X-User-Id") Long userId) {
        {entity}Service.update(id, dto, userId);
        return Result.success();
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "删除{Entity}")
    public Result<Void> delete(@PathVariable Long id,
                               @RequestHeader("X-User-Id") Long userId) {
        {entity}Service.delete(id, userId);
        return Result.success();
    }
}
