package com.example.{module}.service.impl;

import com.example.common.exception.BusinessException;
import com.example.common.result.PageVO;
import com.example.common.result.ResultCode;
import com.example.{module}.domain.dto.{Entity}PageDTO;
import com.example.{module}.domain.dto.{Entity}SaveDTO;
import com.example.{module}.domain.dto.{Entity}UpdateDTO;
import com.example.{module}.domain.po.{Entity}PO;
import com.example.{module}.domain.vo.{Entity}VO;
import com.example.{module}.mapper.{Entity}Mapper;
import com.example.{module}.service.{Entity}Service;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.AllArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Objects;

/**
 * {Entity} 服务实现
 */
@Service
@AllArgsConstructor
public class {Entity}ServiceImpl implements {Entity}Service {

    private final {Entity}Mapper {entity}Mapper;

    @Override
    public PageVO<{Entity}VO> pageList({Entity}PageDTO dto, Long userId) {
        Page<{Entity}PO> page = new Page<>(dto.getPageNum(), dto.getPageSize());
        LambdaQueryWrapper<{Entity}PO> wrapper = new LambdaQueryWrapper<{Entity}PO>()
                .eq({Entity}PO::getUserId, userId)
                .orderByDesc({Entity}PO::getCreateTime);
        {entity}Mapper.selectPage(page, wrapper);

        List<{Entity}VO> records = page.getRecords().stream()
                .map(this::toVO)
                .toList();
        return PageVO.of(page.getTotal(), page.getCurrent(), page.getSize(), records);
    }

    @Override
    public {Entity}VO getDetail(Long id, Long userId) {
        {Entity}PO po = getOwned{Entity}(id, userId);
        return toVO(po);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void save({Entity}SaveDTO dto, Long userId) {
        // 业务校验：简单规则用 DTO 注解，业务规则写在这里
        {Entity}PO po = new {Entity}PO();
        po.setUserId(userId);
        // TODO 按实际字段赋值，禁止用 BeanUtils 整体拷贝
        {entity}Mapper.insert(po);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, {Entity}UpdateDTO dto, Long userId) {
        {Entity}PO po = getOwned{Entity}(id, userId);
        // TODO 按实际字段赋值，禁止允许前端改写 userId / 状态 / 金额等敏感列
        {entity}Mapper.updateById(po);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id, Long userId) {
        {Entity}PO po = getOwned{Entity}(id, userId);
        {entity}Mapper.deleteById(po.getId());
    }

    /**
     * 查询并校验归属，防水平越权。
     * 返回「不存在」而非「无权限」，避免暴露资源存在性。
     */
    private {Entity}PO getOwned{Entity}(Long id, Long userId) {
        {Entity}PO po = {entity}Mapper.selectById(id);
        if (po == null || !Objects.equals(po.getUserId(), userId)) {
            throw new BusinessException(ResultCode.NOT_FOUND);
        }
        return po;
    }

    private {Entity}VO toVO({Entity}PO po) {
        {Entity}VO vo = new {Entity}VO();
        vo.setId(po.getId());
        // TODO 仅映射允许对外暴露的字段，禁止返回 password 等敏感列
        return vo;
    }
}
