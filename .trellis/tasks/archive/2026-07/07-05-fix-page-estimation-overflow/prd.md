# PRD: 分页估算不准确导致内容溢出可滑动 (P0)

## 问题

分页模式下，Rust 分页引擎估算的一页内容比实际可视区域多，内容超出屏幕底部，导致用户可以在单"页"内滑动。

### 根因分析

**数据流：**

```
reader_shell.dart:108
  pageHeight = mq.size.height - mq.padding.vertical
  → 这是完整可用高度（含内容区上下内边距）

typeset_calibrator.dart:352 (buildTypesetConfig)
  pageHeight: (height * devicePixelRatio).round()
  → Rust 收到 pageHeight = 完整可用高度（设备像素）

Rust block_paginator.rs:258 (BlockPaginator::new)
  remaining_height = page_height_px
  → 按完整高度分配行数，lines_per_page = page_height_px / line_height_px

Dart renderer (paginated_renderer.dart:409,525)
  vPad = pageContentVerticalPadding = 20.0
  bodyHeight = constraints.maxHeight - 2 * vPad = pageHeight - 40dp
  → 实际显示区域比 Rust 估算的小了 40dp

PaginatedPageViewport (paginated_page_viewport.dart)
  SizedBox(height: bodyHeight) + ClipRect + SingleChildScrollView
  → DEBUG 遗留的 SingleChildScrollView 使溢出内容可滑动
```

**结果：** Rust 按 `pageHeight` 分配内容，但 Dart 实际裁剪高度为 `pageHeight - 40dp`。每页多装了约 `40dp / lineHeight` 行内容。对于 fontSize=16, lineHeight=1.5 的场景，每页多装约 1.67 行 → 内容溢出，用户可滑动查看被截断的行。

## 影响范围

- **严重性：** P0 — 用户在任何分页模式下都能滑动页面，打破"翻页"心智模型
- **影响面：** 所有书籍、所有章节、所有分页模式（plainText + contentBlocks）
- **可见性：** 高 — 用户直接看到页面内容可滑动，与分页设计矛盾

## 修复方案

### 方案 A（推荐）：修正 pageHeight 传递

**Rust 侧** — 不需要改。`page_height_px` 本应是可视内容区高度，不应该包含上下 padding。

**Dart 侧** — 两处改动：

1. `buildTypesetConfig()` — 传入的 `height` 应扣除 `2 × pageContentVerticalPadding`：

```dart
pageHeight: ((height - 2 * padding) * devicePixelRatio).round(),
```

> `padding` 已经是 `buildTypesetConfig` 的参数，但当前只用于 `pageWidth`。可新增 `verticalPadding` 参数或复用 `padding` 语义。

1. `PaginatedPageViewport` — 移除 DEBUG 遗留的 `SingleChildScrollView`，替换为 `<SizedBox>` + `ClipRect` + `Align`：

```dart
// 从
ClipRect(
  child: SingleChildScrollView(
    child: Align(alignment: Alignment.topCenter, child: child),
  ),
)
// 改为
ClipRect(
  child: Align(alignment: Alignment.topCenter, child: child),
)
```

> 注意：移除 `SingleChildScrollView` 前必须确保 pageHeight 计算修正完成，否则内容会被静默裁剪（不可见溢出）。

### 方案 B：保留 scroll + 防御性 clip（临时修复）

仅移除 `SingleChildScrollView` 并加 `overflow: hidden`，不改 pageHeight 计算。

**问题：** 内容被静默裁剪，用户看不到最后几行。

### 方案 C：双端对齐

同时改 Rust 侧（增加 topSpacing/bottomSpacing 比例计算结果校验）和 Dart 侧。

**复杂度：** 过高。P0 需要精准快速修复。

## 验收标准

1. 单页内不可滚动（`PaginatedPageViewport` 无 `ScrollView`）
2. 最后一页内容不被静默裁剪（内容完整度对比 Rust 估算 vs Dart 渲染）
3. `[LayoutChange]` 无新增异常日志
4. `dart analyze --fatal-infos` 无新问题
5. 移除 `SingleChildScrollView` 后回归覆盖：
   - 短章（1-2 页）正常
   - 长章（50+ 页）正常
   - 含图片章节的布局正常
   - 跨章 stagingPromote 正常

## 相关文件

| 文件 | 改动类型 |
| ------ | --------- |
| `lib/features/reader/rendering/paginated_page_viewport.dart` | 移除 `SingleChildScrollView` |
| `lib/features/reader/data/typeset_calibrator.dart` | `buildTypesetConfig` pageHeight 扣减 vPad |
| `lib/features/reader/rendering/paginated_renderer.dart` | 验证 bodyHeight 语义正确 |
| `lib/features/reader/rendering/reader_render_config.dart` | 不修改（`pageContentVerticalPadding` 语义正确） |
