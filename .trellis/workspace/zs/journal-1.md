# Journal - zs (Part 1)

> AI development session journal
> Started: 2026-07-02

---

## 2026-07-05 — P0: 分页估算不准确（pageHeight 未扣 vPad）

**根因确认：**

- `reader_shell.dart:108` 设置 `pageHeight = screenHeight - systemPadding`（完整可用高度）
- `buildTypesetConfig` 不经扣减直接 `pageHeight * dpr` 传入 Rust
- Rust `BlockPaginator` 按 `page_height_px` 分配行 → 每页多装 ~40dp/lineHeight 行
- Dart 渲染时 `bodyHeight = constraints.maxHeight - 2*20px`（vPad=20）
- `PaginatedPageViewport` 有 DEBUG 遗留的 `SingleChildScrollView` → 溢出内容可滑动

**修复方向：**

1. `typeset_calibrator.dart:352` pageHeight 扣减 `2 * padding`
2. `paginated_page_viewport.dart` 移除 `SingleChildScrollView`

**关联 task:** `07-05-fix-page-estimation-overflow`（child of fix-chapter-layout-jitter）
