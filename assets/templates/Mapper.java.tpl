package com.example.{module}.mapper;

import com.example.{module}.domain.po.{Entity}PO;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Update;

/**
 * {Entity} 数据访问
 * 只做数据访问，不含业务判断。单表用 MyBatis-Plus 方法，复杂查询写 XML。
 */
@Mapper
public interface {Entity}Mapper extends BaseMapper<{Entity}PO> {

    /**
     * 状态条件更新示例：把「判断」和「更新」合成原子操作。
     * 用影响行数判断是否抢到执行权，避免并发下重复处理。
     *
     * @return 影响行数，0 表示状态已变更、本次未执行
     */
    @Update("update {table_name} set status = #{targetStatus} "
            + "where id = #{id} and status = #{expectStatus}")
    int updateStatusIfMatch(@Param("id") Long id,
                            @Param("expectStatus") Integer expectStatus,
                            @Param("targetStatus") Integer targetStatus);
}
