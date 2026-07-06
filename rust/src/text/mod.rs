//! 文本处理模块
//! 包含中英文断行、章节检测、排版优化

pub mod bilingual;
pub mod block_paginator;
pub mod chapter_detect;
pub mod char_width;
pub mod constants;
pub mod css;
pub mod line_breaking;
pub mod rich_text;
pub mod typeset;

pub use bilingual::align_bilingual_content;
pub use block_paginator::paginate_chapter_ir;
pub use chapter_detect::extract_chapters;
pub use rich_text::parse_html_to_rich_text;
