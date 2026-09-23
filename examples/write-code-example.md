# 写代码模式产出样例

对比同一个需求在**未加载 Skill** 与**加载 Skill** 下的产出差异。

---

## 需求

> 帮我给商品模块写一个分页查询接口，支持按名称模糊搜索和分类筛选

---

## 未加载 Skill 时的典型产出

```java
@RestController
@RequestMapping("/product")
public class ProductController {

    @Autowired
    private ProductMapper productMapper;

    @GetMapping("/list")
    public Map<String, Object> list(@RequestParam(required = false) String name,
                                    @RequestParam(required = false) Long categoryId,
                                    @RequestParam(defaultValue = "1") Integer page,
                                    @RequestParam(defaultValue = "10") Integer size) {
        try {
            QueryWrapper<Product> wrapper = new QueryWrapper<>();
            if (name != null) {
                wrapper.like("name", name);
            }
            if (categoryId != null) {
                wrapper.eq("category_id", categoryId);
            }
            Page<Product> p = new Page<>(page, size);
            productMapper.selectPage(p, wrapper);

            Map<String, Object> result = new HashMap<>();
            result.put("code", 200);
            result.put("data", p.getRecords());
            result.put("total", p.getTotal());
            return result;
        } catch (Exception e) {
            e.printStackTrace();
            return Map.of("code", 500, "msg", "查询失败");
        }
    }
}
```

**问题清单**

| 问题 | 严重级别 |
|---|---|
| Controller 直接调 Mapper，跳过 Service 层 | P2 |
| 返回裸 `Map`，破坏统一响应契约 | P1 |
| 直接返回 PO，暴露数据库字段 | P1 |
| 分页大小无上限，`size=100000` 可拖垮数据库 | P0 |
| 用 `e.printStackTrace()` 处理异常，生产环境无法追踪 | P1 |
| 用字符串列名 `"name"` / `"category_id"`，字段改名后静默失效 | P2 |
| 路径缺少 `/api` 前缀，与其他模块不一致 | P3 |
| 缺少接口文档注解 | P3 |

---

## 加载 Skill 后的产出

```java
// ---------- Controller ----------
@RestController
@RequestMapping("/api/product")
@Tag(name = "商品接口")
@AllArgsConstructor
public class ProductController {

    private final ProductService productService;

    @GetMapping("/page")
    @Operation(summary = "分页查询商品")
    public Result<PageVO<ProductVO>> page(ProductPageDTO dto) {
        return Result.success(productService.pageList(dto));
    }
}

// ---------- DTO ----------
@Data
@Schema(description = "商品分页查询入参")
public class ProductPageDTO {

    @Min(value = 1, message = "页码从 1 开始")
    @Schema(description = "页码", defaultValue = "1")
    private Integer pageNum = 1;

    @Min(value = 1, message = "每页数量至少为 1")
    @Max(value = 100, message = "每页数量不能超过 100")
    @Schema(description = "每页数量", defaultValue = "10")
    private Integer pageSize = 10;

    @Size(max = 50, message = "搜索关键词过长")
    @Schema(description = "商品名称（模糊匹配）")
    private String name;

    @Schema(description = "分类 ID")
    private Long categoryId;
}

// ---------- ServiceImpl ----------
@Service
@AllArgsConstructor
public class ProductServiceImpl implements ProductService {

    private final ProductMapper productMapper;

    @Override
    public PageVO<ProductVO> pageList(ProductPageDTO dto) {
        Page<ProductPO> page = new Page<>(dto.getPageNum(), dto.getPageSize());
        LambdaQueryWrapper<ProductPO> wrapper = new LambdaQueryWrapper<ProductPO>()
                .like(StringUtils.hasText(dto.getName()), ProductPO::getName, dto.getName())
                .eq(dto.getCategoryId() != null, ProductPO::getCategoryId, dto.getCategoryId())
                .eq(ProductPO::getStatus, ProductStatus.ON_SALE)
                .orderByDesc(ProductPO::getCreateTime);
        productMapper.selectPage(page, wrapper);

        List<ProductVO> records = page.getRecords().stream()
                .map(this::toVO)
                .toList();
        return PageVO.of(page.getTotal(), page.getCurrent(), page.getSize(), records);
    }

    private ProductVO toVO(ProductPO po) {
        ProductVO vo = new ProductVO();
        vo.setId(po.getId());
        vo.setName(po.getName());
        vo.setPrice(po.getPrice());
        vo.setCoverUrl(po.getCoverUrl());
        // 不映射成本价、内部状态等敏感字段
        return vo;
    }
}
```

**对照改进**

| 原问题 | 改进方式 |
|---|---|
| Controller 调 Mapper | 回归三层：Controller → Service → Mapper |
| 返回裸 `Map` | 统一 `Result<PageVO<T>>` |
| 返回 PO | 定义 `ProductVO`，显式映射允许暴露的字段 |
| 分页无上限 | DTO 加 `@Max(100)`，分页参数有明确校验 |
| `printStackTrace` | 移除 try-catch，异常交全局处理器统一记录完整堆栈 |
| 字符串列名 | 改用 `LambdaQueryWrapper`，字段改名编译期即报错 |
| 路径不统一 | 统一 `/api/product` 前缀 |
| 无文档注解 | 补 `@Tag` / `@Operation` / `@Schema` |

---

## 交付说明（Skill 要求附带的最后一环）

```
## 变更说明
新增 3 个文件：
- ProductController.java —— 接口层，新增分页查询入口
- ProductPageDTO.java —— 分页入参，含页码上限校验
- ProductServiceImpl.java —— 分页业务与 PO→VO 转换

## 自检结果
- [x] 字段名与 ProductPO、ProductVO 保持一致
- [x] 分页参数有上限（100），防止大分页
- [x] 未返回敏感字段（成本价未映射）
- [x] 使用 LambdaQueryWrapper，无字符串列名
- [x] 无新增 Maven 依赖

## 待确认
1. `ProductStatus.ON_SALE` 是全量查询都需要的过滤条件吗？还是后台管理接口需要查全部状态？
2. 是否需要支持按价格区间筛选？如需要请补充 DTO 字段。
3. 当前用 `like` 做名称模糊匹配，数据量大时前置模糊会全表扫描，
   是否考虑后续接入搜索引擎？
```

**注意最后一部分**：列出不确定项而不是自行决定，这是 Skill 明确要求的行为。
