# Phase 8：滚动模式 Flutter 化

## Goal

将 scroll 模式的 EPUB 富文本排版从 Rust 迁移到 Flutter，用 `ChapterContentIr` 统一两条渲染路径。

## 分析结论

### 可行 ✅

**两条路径共享 HTML 解析器**（`parse_html_to_rich_text` → `Vec<RichParagraph>`），分岔点在解析后。IR（`ChapterContentIr`）的 `TextBlock` 和 `TextBlockStyle` 已覆盖 `RichParagraph` 的全部渲染相关字段（spans、indent、heading、margin、text-align、font-size 等）。

### 删除连锁反应

| 依赖链 | 说明 |
| -------- | ------ |
| `get_epub_chapter_rich_content` | Rust API 入口，最后一个 `TypesetConfig` FRB 消费者 |
| `RichParagraph` / `RichChapterContent` | `RichTextSpan` 保留（IR 也在用） |
| `TypesetConfig` / `TypesetCalibration` / `TypesetConfigFixReport` | FRB 导出全删；struct 定义可考虑保留或移动 |
| `char_width.rs` + `line_breaking.rs` | **无生产消费者**，可直接整模块删除 |
| `currentRichParagraphs` getter | Dart 接口层删除 |

### 风险

- 🟡 scroll 渲染效果需视觉回归
- 🟢 `char_width`/`line_breaking` 已无消费者
- 🟢 IR `TextBlock` 和 `RichParagraph` 共用 `RichTextSpan`，样式转换复用

## 工作量评估

| # | Step | 估计 |
| --- | ------ | ------ |
| 1 | Flutter 侧 IR → TextSpan 渲染器 | 1h |
| 2 | 替换 scroll 数据源（rust_chapter_content_repository） | 0.5h |
| 3 | 删除 Rust API 层 + 领域类型 | 0.5h |
| 4 | 删除 `char_width.rs` + `line_breaking.rs` | 0.2h |
| 5 | FRB codegen + Dart 接口清理 | 0.5h |
| 6 | 测试验证 | 1h |
| **合计** | | **~4h** |

## 验收标准

- [ ] Scroll 模式不再调用 `get_epub_chapter_rich_content`
- [ ] Scroll 模式使用 IR 渲染，视觉效果一致
- [ ] Rust 侧 `TypesetConfig` 无 FRB 导出
- [ ] `char_width.rs`、`line_breaking.rs` 已删除
- [ ] `flutter test` 全绿
- [ ] `cargo clippy -- -D warnings` 零告警（不含 pre-existing）
