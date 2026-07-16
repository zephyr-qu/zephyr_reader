//! TXT 章节检测配置数据模型

/// 单个章节检测正则（DB 存储 + 序列化）
#[derive(Debug, Clone)]
pub struct ChapterDetectPattern {
    pub pattern_name: String,
    pub regex: String,
    pub enabled: bool,
}

/// 一个命名 scope 的完整配置
#[derive(Debug, Clone)]
pub struct ChapterDetectConfig {
    pub scope: String,
    pub patterns: Vec<ChapterDetectPattern>,
}

/// 预编译后的配置（含已编译 regex，用于高性能检测）
#[derive(Debug, Clone)]
pub struct CompiledChapterDetectConfig {
    pub scope: String,
    pub patterns: Vec<CompiledPattern>,
}

/// 预编译的正则模式
#[derive(Debug, Clone)]
pub struct CompiledPattern {
    pub pattern_name: String,
    pub regex: regex::Regex,
}
