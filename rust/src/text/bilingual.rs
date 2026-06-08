//! 双语对齐模块
//! 基于句子相似度的自动对齐算法，支持中英对照阅读

use unicode_segmentation::UnicodeSegmentation;

use crate::{
    api::{AlignedSegment, BilingualAlignment},
    domain::AppError,
};

/// 句子分割器
pub struct SentenceSegmenter;

impl SentenceSegmenter {
    /// 分割中文句子，返回 (句子切片, 字节位置) 列表
    pub fn segment_chinese(text: &str) -> Vec<(&str, usize)> {
        let mut sentences = Vec::new();
        let mut seg_start = 0; // 当前句子在 text 中的起始字节偏移

        for (i, c) in text.char_indices() {
            // 中文句子结束标志
            if matches!(c, '。' | '！' | '？' | '\n' | '\r') {
                let end = i + c.len_utf8();
                let trimmed = text[seg_start..end].trim();
                if !trimmed.is_empty() {
                    sentences.push((trimmed, seg_start));
                }
                seg_start = end;
            }
        }

        // 处理剩余内容
        let trimmed = text[seg_start..].trim();
        if !trimmed.is_empty() {
            sentences.push((trimmed, seg_start));
        }

        sentences
    }

    /// 分割英文句子，返回 (句子切片, 字节位置) 列表
    pub fn segment_english(text: &str) -> Vec<(&str, usize)> {
        let mut sentences = Vec::new();
        let mut seg_start = 0;

        // 常见英文缩写白名单
        let abbreviations = [
            "mr.", "mrs.", "ms.", "dr.", "prof.", "sr.", "jr.", "vs.", "etc.", "e.g.", "i.e.",
            "inc.", "ltd.", "corp.", "approx.", "dept.", "est.", "gov.", "misc.", "no.",
        ];

        for (byte_idx, c) in text.char_indices() {
            // 英文句子结束标志
            if matches!(c, '.' | '!' | '?' | '\n' | '\r') {
                let end = byte_idx + c.len_utf8();
                let candidate = &text[seg_start..end];

                // 检查是否是缩写
                let lower_current = candidate.to_lowercase();
                let is_abbreviation = abbreviations
                    .iter()
                    .any(|abbr| lower_current.ends_with(abbr));

                // 检查下一个字符：如果后面直接跟小写字母，可能是缩写（如 "e.g."）
                let remaining = &text[end..].trim_start();
                let follow_pattern = remaining.chars().next().map(|n| n.is_ascii_lowercase());
                let is_abbreviation_pattern = follow_pattern == Some(true);

                if !is_abbreviation && !is_abbreviation_pattern {
                    let trimmed = candidate.trim();
                    if !trimmed.is_empty() {
                        sentences.push((trimmed, seg_start));
                    }
                    seg_start = end;
                }
                // 是缩写则继续累积（seg_start 不动）
            }
        }

        // 处理剩余内容
        let trimmed = text[seg_start..].trim();
        if !trimmed.is_empty() {
            sentences.push((trimmed, seg_start));
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
        let max_len = s1.graphemes(true).count().max(s2.graphemes(true).count());

        1.0 - (distance as f32 / max_len as f32)
    }

    /// 使用预分 grapheme 计算相似度，避免重复分词
    pub fn calculate_similarity_graphemes(
        s1_graphemes: &[&str],
        s2_graphemes: &[&str],
        s1_len: usize,
        s2_len: usize,
    ) -> f32 {
        if s1_len == 0 && s2_len == 0 {
            return 1.0;
        }
        if s1_len == 0 || s2_len == 0 {
            return 0.0;
        }

        let distance = levenshtein_distance_graphemes(s1_graphemes, s2_graphemes);
        let max_len = s1_len.max(s2_len);

        1.0 - (distance as f32 / max_len as f32)
    }
}

/// 计算编辑距离（Levenshtein 距离）
///
/// 使用两行滚动数组优化，将空间复杂度从 O(n×m) 降到 O(min(n,m))。
/// 同时添加快速失败检查，当长度差异过大时直接返回上限。
fn levenshtein_distance(s1: &str, s2: &str) -> usize {
    let s1_graphemes: Vec<&str> = UnicodeSegmentation::graphemes(s1, true).collect();
    let s2_graphemes: Vec<&str> = UnicodeSegmentation::graphemes(s2, true).collect();
    levenshtein_distance_graphemes(&s1_graphemes, &s2_graphemes)
}

/// 使用预分 grapheme 切片计算编辑距离，跳过 Unicode 分词
fn levenshtein_distance_graphemes(s1_graphemes: &[&str], s2_graphemes: &[&str]) -> usize {
    let len1 = s1_graphemes.len();
    let len2 = s2_graphemes.len();

    if len1 == 0 {
        return len2;
    }
    if len2 == 0 {
        return len1;
    }

    // 快速失败：如果长度差异过大，直接返回上限
    if (len1 as isize - len2 as isize).unsigned_abs() > len1.min(len2) / 2 {
        return len1.max(len2) / 2;
    }

    // 使用两行滚动数组优化空间复杂度 O(min(n,m))
    let (short, long) = if len1 < len2 {
        (s1_graphemes, s2_graphemes)
    } else {
        (s2_graphemes, s1_graphemes)
    };

    let mut prev: Vec<usize> = (0..=short.len()).collect();
    let mut curr = vec![0; short.len() + 1];

    for j in 1..=long.len() {
        curr[0] = j;
        for i in 1..=short.len() {
            let cost = if short[i - 1] == long[j - 1] { 0 } else { 1 };
            curr[i] = (prev[i] + 1).min(curr[i - 1] + 1).min(prev[i - 1] + cost);
        }
        std::mem::swap(&mut prev, &mut curr);
    }

    prev[short.len()]
}

/// 包含预分 grapheme 的句子结构
struct SentenceGraphemes<'a> {
    text: &'a str,
    position: usize,
    graphemes: Vec<&'a str>,
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
        // 分割句子（切片 + 位置，零分配）
        let zh_sentences = SentenceSegmenter::segment_chinese(chinese_text);
        let en_sentences = SentenceSegmenter::segment_english(english_text);

        // H1: 预分 grapheme 避免 levenshtein 内重复分词
        let zh_graphemes: Vec<SentenceGraphemes> = zh_sentences
            .iter()
            .map(|&(text, pos)| SentenceGraphemes {
                text,
                position: pos,
                graphemes: UnicodeSegmentation::graphemes(text, true).collect(),
            })
            .collect();
        let en_graphemes: Vec<SentenceGraphemes> = en_sentences
            .iter()
            .map(|&(text, pos)| SentenceGraphemes {
                text,
                position: pos,
                graphemes: UnicodeSegmentation::graphemes(text, true).collect(),
            })
            .collect();

        let mut segments = Vec::new();
        let mut unmatched_zh = Vec::new();
        let mut unmatched_en = Vec::new();

        // 贪心对齐算法
        let mut zh_idx = 0;
        let mut en_idx = 0;

        while zh_idx < zh_graphemes.len() && en_idx < en_graphemes.len() {
            let zh_sg = &zh_graphemes[zh_idx];
            let en_sg = &en_graphemes[en_idx];

            // 使用预分 grapheme 计算相似度
            let similarity = SimilarityCalculator::calculate_similarity_graphemes(
                &zh_sg.graphemes,
                &en_sg.graphemes,
                zh_sg.graphemes.len(),
                en_sg.graphemes.len(),
            );

            if similarity >= self.threshold {
                // 找到匹配
                segments.push(AlignedSegment {
                    chinese: zh_sg.text.to_string(),
                    english: en_sg.text.to_string(),
                    similarity_score: similarity,
                    chinese_position: zh_sg.position,
                    english_position: en_sg.position,
                });
                zh_idx += 1;
                en_idx += 1;
            } else {
                // 尝试在窗口内寻找更好的匹配
                let mut best_match = None;
                let mut best_score = self.threshold;

                let zh_window = self.window_size.min(zh_graphemes.len() - zh_idx);
                let en_window = self.window_size.min(en_graphemes.len() - en_idx);

                for wi in 0..zh_window {
                    let zh_wi = &zh_graphemes[zh_idx + wi];
                    for wj in 0..en_window {
                        let en_wj = &en_graphemes[en_idx + wj];

                        let score = SimilarityCalculator::calculate_similarity_graphemes(
                            &zh_wi.graphemes,
                            &en_wj.graphemes,
                            zh_wi.graphemes.len(),
                            en_wj.graphemes.len(),
                        );
                        if score > best_score {
                            best_score = score;
                            best_match = Some((zh_idx + wi, en_idx + wj));
                            if (score - 1.0).abs() < f32::EPSILON {
                                break;
                            }
                        }
                    }
                    if best_match
                        .is_some_and(|_| (best_score - 1.0).abs() < f32::EPSILON)
                    {
                        break;
                    }
                }

                if let Some((zh_match_idx, en_match_idx)) = best_match {
                    // 获取 zh_idx 到 zh_match_idx 之间的未匹配中文句子
                    unmatched_zh.extend(
                        zh_graphemes[zh_idx..zh_match_idx]
                            .iter()
                            .map(|sg| sg.text.to_string()),
                    );

                    // 获取 en_idx 到 en_match_idx 之间的未匹配英文句子
                    unmatched_en.extend(
                        en_graphemes[en_idx..en_match_idx]
                            .iter()
                            .map(|sg| sg.text.to_string()),
                    );

                    // 添加匹配的句子
                    segments.push(AlignedSegment {
                        chinese: zh_graphemes[zh_match_idx].text.to_string(),
                        english: en_graphemes[en_match_idx].text.to_string(),
                        similarity_score: best_score,
                        chinese_position: zh_graphemes[zh_match_idx].position,
                        english_position: en_graphemes[en_match_idx].position,
                    });

                    zh_idx = zh_match_idx + 1;
                    en_idx = en_match_idx + 1;
                } else {
                    // 没有找到匹配，跳过较短的句子
                    if zh_graphemes[zh_idx].text.len() < en_graphemes[en_idx].text.len() {
                        unmatched_zh.push(zh_graphemes[zh_idx].text.to_string());
                        zh_idx += 1;
                    } else {
                        unmatched_en.push(en_graphemes[en_idx].text.to_string());
                        en_idx += 1;
                    }
                }
            }
        }

        // 处理剩余未匹配的句子
        unmatched_zh.extend(zh_graphemes[zh_idx..].iter().map(|sg| sg.text.to_string()));
        unmatched_en.extend(en_graphemes[en_idx..].iter().map(|sg| sg.text.to_string()));

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
pub fn align_bilingual_content(
    chinese_content: String,
    english_content: String,
    min_similarity: f32,
) -> Result<BilingualAlignment, AppError> {
    let aligner = BilingualAligner::new(min_similarity.max(0.3), 5);
    Ok(aligner.align(&chinese_content, &english_content))
}


#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_chinese_segmentation() {
        let text = "这是第一句。这是第二句！这是第三句？";
        let sentences = SentenceSegmenter::segment_chinese(text);
        assert_eq!(sentences.len(), 3);
        assert_eq!(sentences[0].0, "这是第一句。");
        assert_eq!(sentences[1].0, "这是第二句！");
        assert_eq!(sentences[2].0, "这是第三句？");
    }

    #[test]
    fn test_chinese_segmentation_empty_input() {
        let sentences = SentenceSegmenter::segment_chinese("");
        assert!(sentences.is_empty());
    }

    #[test]
    fn test_chinese_segmentation_no_delimiter() {
        let text = "这是一个没有分隔符的句子";
        let sentences = SentenceSegmenter::segment_chinese(text);
        assert_eq!(sentences.len(), 1);
        assert_eq!(sentences[0].0, "这是一个没有分隔符的句子");
    }

    #[test]
    fn test_english_segmentation() {
        let text = "This is sentence one. This is sentence two! Is this sentence three?";
        let sentences = SentenceSegmenter::segment_english(text);
        assert_eq!(sentences.len(), 3);
    }

    #[test]
    fn test_english_abbreviation() {
        let text = "Dr. Smith went to Washington. He met with Mr. Jones.";
        let sentences = SentenceSegmenter::segment_english(text);
        assert_eq!(sentences.len(), 2);
        assert!(sentences[0].0.contains("Dr."));
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
    fn test_similarity_graphemes() {
        let s1 = "Hello World";
        let s2 = "Hello World";
        let g1: Vec<&str> = UnicodeSegmentation::graphemes(s1, true).collect();
        let g2: Vec<&str> = UnicodeSegmentation::graphemes(s2, true).collect();
        assert_eq!(
            SimilarityCalculator::calculate_similarity_graphemes(&g1, &g2, g1.len(), g2.len()),
            1.0
        );

        let s3 = "Hello World";
        let s4 = "Hello Rust";
        let g3: Vec<&str> = UnicodeSegmentation::graphemes(s3, true).collect();
        let g4: Vec<&str> = UnicodeSegmentation::graphemes(s4, true).collect();
        let sim = SimilarityCalculator::calculate_similarity_graphemes(&g3, &g4, g3.len(), g4.len());
        assert!(sim > 0.0 && sim < 1.0);
    }

    #[test]
    fn test_similarity_empty() {
        assert_eq!(
            SimilarityCalculator::calculate_similarity("", ""),
            1.0
        );
        let g_empty: Vec<&str> = Vec::new();
        assert_eq!(
            SimilarityCalculator::calculate_similarity_graphemes(&g_empty, &g_empty, 0, 0),
            1.0
        );
    }

    #[test]
    fn test_similarity_one_empty() {
        let g: Vec<&str> = UnicodeSegmentation::graphemes("hello", true).collect();
        let g_empty: Vec<&str> = Vec::new();
        assert_eq!(
            SimilarityCalculator::calculate_similarity_graphemes(&g, &g_empty, g.len(), 0),
            0.0
        );
    }

    #[test]
    fn test_bilingual_align() {
        let zh = "你好世界。这是一个测试。";
        let en = "Hello World. This is a test.";

        let result = align_bilingual_content(zh.to_string(), en.to_string(), 0.3).unwrap();
        assert!(!result.segments.is_empty());
    }

    #[test]
    fn test_bilingual_align_empty() {
        let result = align_bilingual_content(String::new(), String::new(), 0.3).unwrap();
        assert!(result.segments.is_empty());
    }


    #[test]
    fn test_levenshtein_graphemes() {
        let g1: Vec<&str> = UnicodeSegmentation::graphemes("hello", true).collect();
        let g2: Vec<&str> = UnicodeSegmentation::graphemes("hollo", true).collect();
        assert_eq!(levenshtein_distance_graphemes(&g1, &g2), 1);

        let g_empty: Vec<&str> = Vec::new();
        assert_eq!(levenshtein_distance_graphemes(&g_empty, &g2), 5);
        assert_eq!(levenshtein_distance_graphemes(&g1, &g_empty), 5);
    }
}
