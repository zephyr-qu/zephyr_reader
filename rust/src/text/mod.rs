// ============================================================
// 文件作用：文本处理模块，公开子模块和关键函数
//
// 公有类型/函数：
//   - align_bilingual_content() — 双语对齐入口
//   - extract_chapters() — 章节提取入口
//   - parse_html_to_rich_text() — HTML 富文本解析入口
// ============================================================

//! 文本处理模块
//! 包含中英文断行、章节检测、排版优化

pub mod bilingual;
pub mod chapter_detect;
pub mod constants;
pub mod css;
pub mod rich_text;

pub use bilingual::align_bilingual_content;
pub use chapter_detect::extract_chapters;
pub use rich_text::parse_html_to_rich_text;
