package com.example.common.result;

import lombok.Data;

import java.io.Serializable;
import java.util.List;

/**
 * 统一分页返回体
 * 字段名前后端约定一致：total / current / size / records。
 */
@Data
public class PageVO<T> implements Serializable {

    private Long total;

    private Long current;

    private Long size;

    private List<T> records;

    public static <T> PageVO<T> of(Long total, Long current, Long size, List<T> records) {
        PageVO<T> vo = new PageVO<>();
        vo.setTotal(total);
        vo.setCurrent(current);
        vo.setSize(size);
        vo.setRecords(records);
        return vo;
    }

    public static <T> PageVO<T> empty() {
        return of(0L, 1L, 10L, List.of());
    }
}
