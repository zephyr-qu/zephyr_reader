# Phase 8 迁移方案

## 现状

两条渲染路径共用同一个 HTML 解析器（`parse_html_to_rich_text`），解析后分岔：

```
                    EPUB HTML
                        │
                        ▼
          parse_html_to_rich_text → Vec<RichParagraph>
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
    chapter_ir_from_       get_epub_chapter_
    rich_paragraphs        rich_content
              │                   │
              ▼                   ▼
    ChapterContentIr     Vec<RichParagraph> (FRB)
    (FRB, 纯数据)              │
              │                   ▼
    Flutter paginator      Dart RichTextConverter
    (TextPainter 装箱)          │
              │                   ▼
              ▼           scroll TextSpan
    PackedPage[]
              │
              ▼
      page widgets
```

## 迁移目标

Scroll 路径复用 IR，替代 Rust `get_epub_chapter_rich_content` 管线。

```
  迁移后：
    EPUB HTML → parse_html_to_rich_text
                 → chapter_ir_from_rich_paragraphs → ChapterContentIr (FRB)
                 → 分页: FlutterBlockPaginator
                 → scroll: 新的 IR → TextSpan 转换器
```

## 步骤

### Step 1: Flutter 侧 IR scroll 渲染器

- 新建 `ir_to_scroll_content.dart`（或直接扩展 `rich_text_converter.dart`）
- 消费 `ChapterContentIr` / `ContentBlock` / `TextBlock`
- 复用已有 span 处理逻辑（`RichTextSpan` → Flutter `TextStyle`）
- 处理 `TextBlockStyle`：heading font-size、margin、text-align、text-indent

### Step 2: 替换 scroll 数据源

- `rust_chapter_content_repository.dart`：
  - `_loadRichCapablePayload` 改为调用 `getChapterContentIr` 而非 `getEpubChapterRichContent`
  - 删除 `_currentRichParagraphs` 和 `currentRichParagraphs` getter
  - 删除 `RichTextConverter` 的 `toTextSpan` 调用，替换为 IR 转换器

### Step 3: 删除 Rust API 层

- `api/epub.rs`：删除 `get_epub_chapter_rich_content`、`RICH_CONTENT_CACHE`
- `api/epub.rs`：删除 `TypesetConfig` import

### Step 4: 删除 Rust 领域类型

- `domain/types/rich_text.rs`：保留 `RichTextSpan`、`SpanStyle`、`RichTextSpanData`（IR 也在用）；删除 `RichParagraph`、`RichChapterContent`、`apply_typeset`
- `domain/types/typeset.rs`：删除 `TypesetConfig`、`TypesetConfigFixReport`、`TypesetCalibration` 的 FRB 导出（需确认 `validate_and_fix` 是否还有其他消费者）

### Step 5: 删除 `char_width.rs` + `line_breaking.rs`

- `text/char_width.rs`：整模块删除
- `text/line_breaking.rs`：整模块删除

### Step 6: 清理 FRB 绑定

- `flutter_rust_bridge_codegen generate`

### Step 7: Dart 接口清理

- 删除 `reader_render_data_source.dart` 的 `currentRichParagraphs`
- 删除 `chapter_content_repository.dart` 的 `currentRichParagraphs`
- 删除 `scroll_chapter_payload.dart` 的 `richParagraphs` 字段
- 删除 `rich_text_converter.dart` 或替换为 IR 版本

### Step 8: 测试

- `flutter test` 全绿
- 手动视觉对比 scroll 模式的渲染效果

## 关键验证点

- [ ] IR `TextBlock.spans` 和 `RichParagraph.spans` 数据一致
- [ ] `TextBlockStyle` 覆盖所有 `RichParagraph` 的样式字段（indent、margin、align、heading、font-size）
- [ ] Scroll 模式下图片排版正确（`ImageBlock` → Flutter image widget）
- [ ] `store_line_breaks` 不依赖已删除的 `line_breaking.rs`（已验证不依赖）
- [ ] `char_width.rs` 无生产代码消费者（已验证）
