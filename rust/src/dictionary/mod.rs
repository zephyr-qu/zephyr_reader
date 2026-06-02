/// 词典模块
///
/// 提供离线词典查询功能，支持 MDict 格式（.mdx/.mdd）词典文件。
/// 主要功能包括：
/// - 单词查询：获取单词的详细释义（HTML 格式）
/// - 拼写建议：基于编辑距离的模糊匹配
/// - 前缀补全：用于自动完成 UI
/// - 音频资源：提取发音音频文件
pub mod mdict_engine;
pub mod models;

pub use mdict_engine::MdictEngine;
pub use models::{DictEntry, DictSearchResult};
