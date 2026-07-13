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
