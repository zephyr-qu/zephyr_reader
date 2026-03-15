//! 文本处理模块
//! 包含中英文断行、章节检测、排版优化

pub mod chapter_detect;
pub mod line_break;
pub mod typeset;

pub use chapter_detect::extract_chapters;
pub use line_break::detect_language;
pub use typeset::typeset_content;
