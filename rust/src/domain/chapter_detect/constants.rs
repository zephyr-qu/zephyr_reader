//! 内置通用章节检测规则（硬编码，Global 不可变）

use std::sync::LazyLock;

use super::models::ChapterDetectPattern;

/// 内置的 4 种通用章节检测规则
///
/// 优先级：用户自定义规则（DB）→ 内置通用规则 → 整文件单章
/// `global` scope 的书直接使用内置规则。
pub(crate) static BUILTIN_DETECT_PATTERNS: LazyLock<Vec<ChapterDetectPattern>> = LazyLock::new(
    || {
        vec![
            ChapterDetectPattern {
                pattern_name: "中文章回".into(),
                regex: r"(?m)^(?:第\s*)?([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟 0-9]+)\s*[章回卷节部篇集]\s*(.+)?$|^(?:楔子|序[言引]?|前言|引子|尾声|完结|番外|后记|自序|代序|跋|附录|\S+版自序)\s*(.+)?$".into(),
                enabled: true,
            },
            ChapterDetectPattern {
                pattern_name: "中文枚举".into(),
                regex: r"(?m)^([零〇一二三四五六七八九十百千万壹贰叁肆伍陆柒捌玖拾佰仟]{1,8})\s*[、.．:：]\s*(\S.+)$".into(),
                enabled: true,
            },
            ChapterDetectPattern {
                pattern_name: "英文".into(),
                regex: r"(?mi)^(?:Chapter\s+\d+|[IVX]+\.[\s.]|[IVX]+\s+[A-Z]|\bPart\s+\d+|Book\s+\d+|Prologue|Epilogue|Preface|Introduction|Conclusion)\s*:?\s*(.*)$".into(),
                enabled: true,
            },
            ChapterDetectPattern {
                pattern_name: "数字".into(),
                regex: r"(?m)^(\d+)[\s.、:：](.+)$".into(),
                enabled: true,
            },
        ]
    },
);
