//! 双语对齐模块
//! 基于句子相似度的自动对齐算法，支持中英对照阅读

use crate::ffi::types::{AlignedSegment, BilingualAlignment};
use crate::ffi::ParserError;
use flutter_rust_bridge::frb;
use unicode_segmentation::UnicodeSegmentation;

/// 句子分割器
pub struct SentenceSegmenter;

impl SentenceSegmenter {
    /// 分割中文句子
    pub fn segment_chinese(text: &str) -> Vec<(String, usize)> {
        let mut sentences = Vec::new();
        let mut current = String::new();
        let mut start_pos = 0;

        let chars: Vec<char> = text.chars().collect();
        for (i, &c) in chars.iter().enumerate() {
            current.push(c);

            // 中文句子结束标志
            if matches!(c, '。' | '！' | '？' | '\n' | '\r') {
                let trimmed = current.trim().to_string();
                if !trimmed.is_empty() {
                    sentences.push((trimmed, start_pos));
                }
                current = String::new();
                start_pos = i + 1;
            }
        }

        // 处理剩余内容
        let trimmed = current.trim().to_string();
        if !trimmed.is_empty() {
            sentences.push((trimmed, start_pos));
        }

        sentences
    }

    /// 分割英文句子
    pub fn segment_english(text: &str) -> Vec<(String, usize)> {
        let mut sentences = Vec::new();
        let mut current = String::new();
        let mut start_pos = 0;

        let chars: Vec<char> = text.chars().collect();
        for (i, &c) in chars.iter().enumerate() {
            current.push(c);

            // 英文句子结束标志
            if matches!(c, '.' | '!' | '?' | '\n' | '\r') {
                // 检查是否是缩写（如 Mr. Dr.）
                let is_abbreviation = i + 1 < chars.len() && chars[i + 1].is_ascii_lowercase();

                if !is_abbreviation {
                    let trimmed = current.trim().to_string();
                    if !trimmed.is_empty() {
                        sentences.push((trimmed, start_pos));
                    }
                    current = String::new();
                    start_pos = i + 1;
                }
            }
        }

        // 处理剩余内容
        let trimmed = current.trim().to_string();
        if !trimmed.is_empty() {
            sentences.push((trimmed, start_pos));
        }

        sentences
    }
}

/// 相似度计算器
pub struct SimilarityCalculator;

impl SimilarityCalculator {
    /// 计算两个字符串的相似度（基于编辑距离）
    pub fn calculate_similarity(s1: &str, s2: &str) -> f32 {
        if s1.is_empty() && s2.is_empty() {
            return 1.0;
        }
        if s1.is_empty() || s2.is_empty() {
            return 0.0;
        }

        // 使用归一化的编辑距离
        let distance = levenshtein_distance(s1, s2);
        let max_len = s1.len().max(s2.len());

        1.0 - (distance as f32 / max_len as f32)
    }

    /// 计算基于单词的相似度
    pub fn calculate_word_similarity(s1: &str, s2: &str) -> f32 {
        let words1: Vec<&str> = s1.split_whitespace().collect();
        let words2: Vec<&str> = s2.split_whitespace().collect();

        if words1.is_empty() && words2.is_empty() {
            return 1.0;
        }
        if words1.is_empty() || words2.is_empty() {
            return 0.0;
        }

        let common_words = words1.iter().filter(|w| words2.contains(w)).count();

        common_words as f32 / words1.len().max(words2.len()) as f32
    }
}

/// 计算编辑距离（Levenshtein 距离）
fn levenshtein_distance(s1: &str, s2: &str) -> usize {
    let s1_graphemes: Vec<&str> = UnicodeSegmentation::graphemes(s1, true).collect();
    let s2_graphemes: Vec<&str> = UnicodeSegmentation::graphemes(s2, true).collect();

    let len1 = s1_graphemes.len();
    let len2 = s2_graphemes.len();

    if len1 == 0 {
        return len2;
    }
    if len2 == 0 {
        return len1;
    }

    // 创建距离矩阵
    let mut matrix = vec![vec![0; len2 + 1]; len1 + 1];

    // 初始化第一行和第一列
    for i in 0..=len1 {
        matrix[i][0] = i;
    }
    for j in 0..=len2 {
        matrix[0][j] = j;
    }

    // 填充矩阵
    for i in 1..=len1 {
        for j in 1..=len2 {
            let cost = if s1_graphemes[i - 1] == s2_graphemes[j - 1] {
                0
            } else {
                1
            };

            matrix[i][j] = (matrix[i - 1][j] + 1)
                .min(matrix[i][j - 1] + 1)
                .min(matrix[i - 1][j - 1] + cost);
        }
    }

    matrix[len1][len2]
}

/// 双语对齐器
pub struct BilingualAligner {
    /// 相似度阈值
    threshold: f32,
    /// 最大窗口大小（用于动态规划）
    window_size: usize,
}

impl BilingualAligner {
    /// 创建新的对齐器
    pub fn new(threshold: f32, window_size: usize) -> Self {
        Self {
            threshold,
            window_size,
        }
    }

    /// 对齐中英文文本
    pub fn align(&self, chinese_text: &str, english_text: &str) -> BilingualAlignment {
        // 分割句子
        let zh_sentences = SentenceSegmenter::segment_chinese(chinese_text);
        let en_sentences = SentenceSegmenter::segment_english(english_text);

        let mut segments = Vec::new();
        let mut unmatched_zh = Vec::new();
        let mut unmatched_en = Vec::new();

        // 贪心对齐算法
        let mut zh_idx = 0;
        let mut en_idx = 0;

        while zh_idx < zh_sentences.len() && en_idx < en_sentences.len() {
            let (zh_sent, zh_pos) = &zh_sentences[zh_idx];
            let (en_sent, en_pos) = &en_sentences[en_idx];

            // 计算相似度
            let similarity = SimilarityCalculator::calculate_similarity(zh_sent, en_sent);

            if similarity >= self.threshold {
                // 找到匹配
                segments.push(AlignedSegment {
                    chinese: zh_sent.clone(),
                    english: en_sent.clone(),
                    similarity_score: similarity,
                    chinese_position: *zh_pos,
                    english_position: *en_pos,
                });
                zh_idx += 1;
                en_idx += 1;
            } else {
                // 尝试在窗口内寻找更好的匹配
                let mut best_match = None;
                let mut best_score = self.threshold;

                for wi in 0..self.window_size.min(zh_sentences.len() - zh_idx) {
                    for wj in 0..self.window_size.min(en_sentences.len() - en_idx) {
                        let (zh_wi, zh_pos_wi) = &zh_sentences[zh_idx + wi];
                        let (en_wj, en_pos_wj) = &en_sentences[en_idx + wj];

                        let score = SimilarityCalculator::calculate_similarity(zh_wi, en_wj);
                        if score > best_score {
                            best_score = score;
                            best_match = Some((zh_idx + wi, en_idx + wj, zh_pos_wi, en_pos_wj));
                        }
                    }
                }

                if let Some((zh_match_idx, en_match_idx, zh_pos, en_pos)) = best_match {
                    // 添加未匹配的中间句子
                    for i in zh_idx..zh_match_idx {
                        unmatched_zh.push(zh_sentences[i].0.clone());
                    }
                    for j in en_idx..en_match_idx {
                        unmatched_en.push(en_sentences[j].0.clone());
                    }

                    // 添加匹配的句子
                    segments.push(AlignedSegment {
                        chinese: zh_sentences[zh_match_idx].0.clone(),
                        english: en_sentences[en_match_idx].0.clone(),
                        similarity_score: best_score,
                        chinese_position: *zh_pos,
                        english_position: *en_pos,
                    });

                    zh_idx = zh_match_idx + 1;
                    en_idx = en_match_idx + 1;
                } else {
                    // 没有找到匹配，跳过较短的句子
                    if zh_sentences[zh_idx].0.len() < en_sentences[en_idx].0.len() {
                        unmatched_zh.push(zh_sentences[zh_idx].0.clone());
                        zh_idx += 1;
                    } else {
                        unmatched_en.push(en_sentences[en_idx].0.clone());
                        en_idx += 1;
                    }
                }
            }
        }

        // 处理剩余未匹配的句子
        for i in zh_idx..zh_sentences.len() {
            unmatched_zh.push(zh_sentences[i].0.clone());
        }
        for j in en_idx..en_sentences.len() {
            unmatched_en.push(en_sentences[j].0.clone());
        }

        BilingualAlignment {
            segments,
            unmatched_chinese: unmatched_zh,
            unmatched_english: unmatched_en,
        }
    }
}

/// 对齐 bilingual 文本
///
/// # 参数
///
/// * `chinese_content` - 中文内容
/// * `english_content` - 英文内容
/// * `min_similarity` - 最小相似度阈值 (0.0 - 1.0)
///
/// # 返回值
///
/// 返回对齐结果，包含匹配的片段和未匹配的片段
#[frb(sync)]
pub fn align_bilingual_content(
    chinese_content: String,
    english_content: String,
    min_similarity: f32,
) -> Result<BilingualAlignment, ParserError> {
    let aligner = BilingualAligner::new(min_similarity.max(0.3), 5);
    Ok(aligner.align(&chinese_content, &english_content))
}

/// 简单的句子对齐（1:1 对齐）
#[frb(sync)]
pub fn simple_bilingual_align(
    chinese_content: String,
    english_content: String,
) -> BilingualAlignment {
    let zh_sentences = SentenceSegmenter::segment_chinese(&chinese_content);
    let en_sentences = SentenceSegmenter::segment_english(&english_content);

    let mut segments = Vec::new();
    let max_count = zh_sentences.len().min(en_sentences.len());

    for i in 0..max_count {
        segments.push(AlignedSegment {
            chinese: zh_sentences[i].0.clone(),
            english: en_sentences[i].0.clone(),
            similarity_score: 1.0, // 简单对齐，假设完全匹配
            chinese_position: zh_sentences[i].1,
            english_position: en_sentences[i].1,
        });
    }

    let mut unmatched_zh = Vec::new();
    let mut unmatched_en = Vec::new();

    for i in max_count..zh_sentences.len() {
        unmatched_zh.push(zh_sentences[i].0.clone());
    }
    for j in max_count..en_sentences.len() {
        unmatched_en.push(en_sentences[j].0.clone());
    }

    BilingualAlignment {
        segments,
        unmatched_chinese: unmatched_zh,
        unmatched_english: unmatched_en,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_chinese_segmentation() {
        let text = "这是第一句。这是第二句！这是第三句？";
        let sentences = SentenceSegmenter::segment_chinese(text);
        assert_eq!(sentences.len(), 3);
    }

    #[test]
    fn test_english_segmentation() {
        let text = "This is sentence one. This is sentence two! Is this sentence three?";
        let sentences = SentenceSegmenter::segment_english(text);
        assert_eq!(sentences.len(), 3);
    }

    #[test]
    fn test_similarity() {
        let s1 = "Hello World";
        let s2 = "Hello World";
        assert_eq!(SimilarityCalculator::calculate_similarity(s1, s2), 1.0);

        let s3 = "Hello World";
        let s4 = "Hello Rust";
        let sim = SimilarityCalculator::calculate_similarity(s3, s4);
        assert!(sim > 0.0 && sim < 1.0);
    }

    #[test]
    fn test_bilingual_align() {
        let zh = "你好世界。这是一个测试。";
        let en = "Hello World. This is a test.";

        let result = align_bilingual_content(zh.to_string(), en.to_string(), 0.3).unwrap();
        assert!(!result.segments.is_empty());
    }
}
