package com.example.{module}.service;

import com.example.common.result.PageVO;
import com.example.{module}.domain.dto.{Entity}PageDTO;
import com.example.{module}.domain.dto.{Entity}SaveDTO;
import com.example.{module}.domain.dto.{Entity}UpdateDTO;
import com.example.{module}.domain.vo.{Entity}VO;

/**
 * {Entity} 服务接口
 * 业务校验、状态流转、多表编排、事务边界都定义在这一层。
 */
public interface {Entity}Service {

    PageVO<{Entity}VO> pageList({Entity}PageDTO dto, Long userId);

    {Entity}VO getDetail(Long id, Long userId);

    void save({Entity}SaveDTO dto, Long userId);

    void update(Long id, {Entity}UpdateDTO dto, Long userId);

    void delete(Long id, Long userId);
}
