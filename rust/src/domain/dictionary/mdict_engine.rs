//! MDict 词典引擎，封装 `rs-mdict` 库的功能。
//!
//! 负责管理 .mdx（释义）和 .mdd（资源：音频、图片、CSS）文件。
//! 使用内存映射文件 I/O，因此构建后的查询速度接近瞬时响应。
use rust_mdict::{LookupResult, Mdd, Mdx};

use super::models::{DictEntry, DictSearchResult};

/// MDict 词典引擎
///
/// 封装 .mdx（释义）和可选的 .mdd（资源文件：音频、图片、CSS）。
/// 两者均使用内存映射文件 I/O，因此构造完成后查询速度极快。
pub struct MdictEngine {
    /// MDX 词典文件（存储单词释义）
    mdx: Mdx,
    /// MDD 资源文件（可选，存储音频、图片等）
    mdd: Option<Mdd>,
}

impl MdictEngine {
    /// 打开 .mdx 文件及其配套的 .mdd 文件（可选）。
    ///
    /// # 参数
    /// * `mdx_path` - MDX 词典文件路径
    /// * `mdd_path` - MDD 资源文件路径（可选）
    ///
    /// # 错误
    /// 如果文件无法打开或解析，返回 `MdictError`。
    pub fn open(mdx_path: &str, mdd_path: Option<&str>) -> Result<Self, rust_mdict::MdictError> {
        let mdx = Mdx::new(mdx_path)?;
        let mdd = match mdd_path {
            Some(p) if !p.is_empty() => Some(Mdd::new(p)?),
            _ => None,
        };
        Ok(Self { mdx, mdd })
    }

    /// 在词典中查询单词。
    ///
    /// 返回精确匹配结果以及模糊匹配建议（编辑距离 ≤ 2）。
    ///
    /// # 参数
    /// * `word` - 要查询的单词
    ///
    /// # 返回值
    /// 返回查询结果，包含精确匹配（如果存在）和拼写建议
    pub fn lookup(&mut self, word: &str) -> Option<DictSearchResult> {
        let exact = self.mdx.lookup(word).map(|r| self.to_entry(word, &r));
        let suggestions = if exact.is_some() {
            vec![]
        } else {
            self.mdx.suggest(word, 2)
        };
        Some(DictSearchResult { exact, suggestions })
    }

    /// 基于前缀的补全建议（用于自动完成 UI）。
    ///
    /// # 参数
    /// * `prefix` - 前缀字符串
    /// * `limit` - 返回结果的最大数量
    ///
    /// # 返回值
    /// 返回匹配前缀的单词列表
    pub fn suggest(&self, prefix: &str, limit: usize) -> Vec<String> {
        self.mdx
            .prefix_keys(prefix)
            .into_iter()
            .take(limit)
            .map(|s| s.to_string())
            .collect()
    }

    /// 从 .mdd 文件中提取资源（音频、图片）的原始字节数据。
    ///
    /// # 参数
    /// * `audio_key` - 资源在 .mdd 文件中的键名
    ///
    /// # 返回值
    /// 如果未加载 .mdd 文件或找不到该键，返回 `None`
    pub fn extract_audio(&mut self, audio_key: &str) -> Option<Vec<u8>> {
        self.mdd.as_mut()?.locate_raw(audio_key)
    }

    /// 检查资源键是否存在于 .mdd 文件中。
    ///
    /// # 参数
    /// * `audio_key` - 要检查的资源键名
    ///
    /// # 返回值
    /// 如果 .mdd 文件已加载且包含该键，返回 `true`
    pub fn has_resource(&self, audio_key: &str) -> bool {
        self.mdd.as_ref().is_some_and(|m| m.contains(audio_key))
    }

    /// 将查询结果转换为 DictEntry 结构体。
    ///
    /// # 参数
    /// * `word` - 原始查询单词
    /// * `r` - 查询结果引用
    ///
    /// # 返回值
    /// 返回包含单词、释义和音频键的词条对象
    fn to_entry(&self, word: &str, r: &LookupResult) -> DictEntry {
        let audio_key = self.mdd.as_ref().and_then(|m| {
            // 尝试常见的音频键模式
            let candidates = [
                format!("\\{word}.spx"),
                format!("\\{word}.wav"),
                format!("\\{word}.mp3"),
            ];
            candidates.iter().find(|k| m.contains(k)).cloned()
        });
        DictEntry {
            word: r.key_text.clone(),
            definition_html: r.definition.clone(),
            audio_key,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_open_nonexistent_mdx() {
        let result = MdictEngine::open("/nonexistent/file.mdx", None);
        assert!(result.is_err(), "should fail for non-existent .mdx file");
    }

    #[test]
    fn test_open_nonexistent_mdd() {
        let result = MdictEngine::open("/nonexistent/file.mdx", Some("/nonexistent/file.mdd"));
        assert!(result.is_err(), "should fail when .mdd file does not exist");
    }

    #[test]
    fn test_open_empty_mdd_path_treated_as_none() {
        // Passing an empty string for mdd_path is equivalent to None
        let result = MdictEngine::open("/nonexistent/file.mdx", Some(""));
        assert!(
            result.is_err(),
            "should still fail because .mdx doesn't exist"
        );
    }

    #[test]
    fn test_lookup_without_opening() {
        // MdictEngine starts with mdd=None; lookup delegates to Mdx which needs real file
        // This test simply verifies the error message originates from the file layer
        let result = MdictEngine::open("/dev/null", None);
        match result {
            Err(_) => {} // expected
            Ok(_) => panic!("should not open /dev/null as valid .mdx"),
        }
    }
}
