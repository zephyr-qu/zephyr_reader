//! 文本处理模块
//! 包含中英文断行、章节检测、排版优化

pub mod bilingual;
pub mod chapter_detect;
pub mod line_break;
pub mod rich_text;
pub mod typeset;

pub use bilingual::{align_bilingual_content, simple_bilingual_align};
pub use chapter_detect::extract_chapters;
pub use line_break::detect_language;
pub use rich_text::{parse_html_to_rich_text, parse_simple_html};
pub use typeset::typeset_content;
