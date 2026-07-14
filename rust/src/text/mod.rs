// ============================================================
// 文件作用：文本处理模块，公开子模块和关键函数
//
// 公有类型/函数：
//   - align_bilingual_content() — 双语对齐入口
//   - parse_html_to_rich_text() — HTML 富文本解析入口
// ============================================================

//! 文本处理模块
//! 包含双语对齐及富文本解析
//!
//! 注意：章节检测（extract_chapters）已迁移至 parser::txt::chapter_detect。
//! CSS 解析（css）已迁移至 parser::epub::css。
//! 排版常量（constants）已合入 parser::txt::chapter_detect。

pub mod bilingual;
pub mod rich_text;

pub use bilingual::align_bilingual_content;
pub use rich_text::parse_html_to_rich_text;
