/// 词典模块数据模型
///
/// 定义词典查询相关的数据结构。
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 词典词条
///
/// 表示从词典文件中查询到的单个词条信息。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct DictEntry {
    /// 查询的单词
    pub word: String,
    /// 来自 MDX 文件的原始 HTML 格式释义
    /// Flutter 端使用 flutter_widget_from_html_core 进行渲染
    pub definition_html: String,
    /// 发音音频资源在 .mdd 文件中的键名（如果可用）
    pub audio_key: Option<String>,
}

/// 词典查询结果
///
/// 包含精确匹配结果和拼写纠正建议。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct DictSearchResult {
    /// 精确匹配的词条（如果存在）
    pub exact: Option<DictEntry>,
    /// 拼写纠正建议列表（编辑距离 ≤ 2）
    pub suggestions: Vec<String>,
}
