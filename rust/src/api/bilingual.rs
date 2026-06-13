//! 双语对齐 API & 双语高亮配对 API
//!
//! 提供中英双语文本的自动对齐功能，支持对照阅读
//! 提供双语对照阅读模式下的高亮配对功能。
//! 当一个高亮在中文侧创建时，自动在英文侧创建配对高亮，
//! 两者通过 `paired_note_id` 字段关联。
//!
use crate::domain::AppError;
use crate::storage::models::Note;
use crate::storage::repos::NoteRepository;
use crate::storage::storage_pool;
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
/// 对齐片段
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct AlignedSegment {
    pub chinese: String,
    pub english: String,
    pub similarity_score: f32,
    pub chinese_position: usize,
    pub english_position: usize,
}

/// 双语对齐结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct BilingualAlignment {
    pub segments: Vec<AlignedSegment>,
    pub unmatched_chinese: Vec<String>,
    pub unmatched_english: Vec<String>,
}

const MAX_BILINGUAL_LEN: usize = 2_000_000;

/// 对齐双语文本（基于相似度匹配）
///
/// 使用编辑距离计算句子相似度，通过贪心+窗口搜索算法
/// 自动匹配中英文对应的句子
///
/// # 参数
///
/// * `chinese_content` - 中文文本内容
/// * `english_content` - 英文文本内容
/// * `min_similarity` - 最小相似度阈值 (0.3 - 1.0)，低于此值不匹配
///
///   传入的值会被 clamp 到 `[0.3, 1.0]` 区间，0.3 以下会静默提升到 0.3
///
/// # 返回值
///
/// 返回对齐结果，包含匹配的片段对和未匹配的片段
///
/// # 长度限制
///
/// 中英文文本**合计**不得超过 2MB，超限返回错误。
#[frb]
pub async fn align_bilingual_content(
    chinese_content: String,
    english_content: String,
    min_similarity: f32,
) -> Result<BilingualAlignment, AppError> {
    tracing::info!("[bilingual] align_bilingual_content: chinese_len={}, english_len={}", chinese_content.len(), english_content.len());
    if chinese_content.len() + english_content.len() > MAX_BILINGUAL_LEN {
        return Err(AppError::invalid_input(format!(
            "bilingual alignment input too large: {} bytes (max {})",
            chinese_content.len() + english_content.len(),
            MAX_BILINGUAL_LEN,
        )));
    }

    let similarity = min_similarity.max(0.3).min(1.0);

    tokio::task::spawn_blocking(move || {
        crate::text::bilingual::align_bilingual_content(
            chinese_content,
            english_content,
            similarity,
        )
    })
    .await
    .map_err(|e| AppError::task_panic("bilingual alignment", e.to_string()))?
    .map_err(|e| AppError::internal(format!("bilingual alignment failed: {}", e)))
}


/// 双语高亮配对
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct BilingualHighlightPair {
    pub source_note: Note,
    pub target_note: Option<Note>,
}
#[derive(Debug, Clone)]
#[frb(non_opaque)]
pub struct BilingualHighlightParams {
    pub source_book_id: String,
    pub source_chapter_index: i64,
    pub source_char_offset: i32,
    pub source_length: i32,
    pub source_selected_text: String,
    pub source_language: String,
    pub target_book_id: String,
    pub target_chapter_index: i64,
    pub target_char_offset: i32,
    pub target_length: i32,
    pub target_selected_text: String,
    pub target_language: String,
    pub highlight_color: i64,
}
/// 创建双语高亮配对
///
/// 同时创建两个高亮 Note，通过 `paired_note_id` 互相链接。
/// 创建后两个高亮可通过 `paired_note_id` 相互查询。
#[frb]
#[warn(clippy::too_many_arguments)]
pub async fn create_bilingual_highlight_pair(
    params: BilingualHighlightParams,
) -> Result<BilingualHighlightPair, AppError> {
    tracing::info!("[bilingual] create_bilingual_highlight_pair: book_id={}, chapter_index={}", params.source_book_id, params.source_chapter_index);
    let pool = storage_pool()?;
    let pair_id = Uuid::new_v4().to_string();

    let source_note = Note::highlight(
        &params.source_book_id,
        params.source_chapter_index,
        params.source_char_offset as i64,
        params.source_length as i64,
        &params.source_selected_text,
        params.highlight_color,
        Some(&params.source_language),
        Some(&pair_id),
    );

    let target_note = Note::highlight(
        &params.target_book_id,
        params.target_chapter_index ,
        params.target_char_offset as i64,
        params.target_length as i64,
        &params.target_selected_text,
        params.highlight_color,
        Some(&params.target_language),
        Some(&pair_id),
    );

    NoteRepository::save(&pool, &source_note)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;

    NoteRepository::save(&pool, &target_note)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;

    Ok(BilingualHighlightPair {
        source_note,
        target_note: Some(target_note),
    })
}

/// 获取指定章节的双语高亮配对列表
#[frb]
pub async fn get_bilingual_highlight_pairs(
    book_id: String,
    chapter_index: i32,
) -> Result<Vec<BilingualHighlightPair>, AppError> {
    tracing::debug!("[bilingual] get_bilingual_highlight_pairs: book_id={}, chapter_index={}", book_id, chapter_index);
    let pool = storage_pool()?;

    let paired_notes = NoteRepository::find_paired_notes_in_chapter(&pool, &book_id, chapter_index as i64)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;

    // Batch fetch all partner notes in a single query (replaces N+1)
    let query_pairs: Vec<(String, String)> = paired_notes
        .iter()
        .filter_map(|n| n.paired_note_id.as_ref().map(|p| (p.clone(), n.id.clone())))
        .collect();

    let partners = NoteRepository::find_partner_notes_batch(&pool, &query_pairs)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;

    let mut pairs: Vec<BilingualHighlightPair> = Vec::new();
    let mut processed: std::collections::HashSet<String> = std::collections::HashSet::new();

    for note in &paired_notes {
        if processed.contains(&note.id) {
            continue;
        }

        if let Some(ref pair_id) = note.paired_note_id {
            let partner = partners.get(pair_id);

            let (source, target) = match partner {
                Some(p) if p.id != note.id => {
                    processed.insert(p.id.clone());
                    (note.clone(), Some(p.clone()))
                }
                _ => (note.clone(), None),
            };

            processed.insert(note.id.clone());
            pairs.push(BilingualHighlightPair {
                source_note: source,
                target_note: target,
            });
        }
    }

    Ok(pairs)
}

/// 删除一对双语高亮
///
/// 传入任意一个 note_id，会同时删除配对的另一个高亮
#[frb]
pub async fn delete_bilingual_highlight_pair(note_id: String) -> Result<(), AppError> {
    tracing::info!("[bilingual] delete_bilingual_highlight_pair: note_id={}", note_id);
    let pool = storage_pool()?;

    // 获取当前 note 以找到其 paired_note_id
    let note = NoteRepository::find_by_id(&pool, &note_id)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;

    if let Some(n) = note {
        if let Some(ref pair_id) = n.paired_note_id {
            let partner = NoteRepository::find_partner_note(&pool, pair_id, &note_id)
                .await
                .map_err(|e| AppError::database_error(e.to_string()))?;
            if let Some(partner) = partner {
                if partner.id != note_id {
                    NoteRepository::delete_by_id(&pool, &partner.id)
                        .await
                        .map_err(|e| AppError::database_error(e.to_string()))?;
                }
            }
        }
        // 删除当前 note
        NoteRepository::delete_by_id(&pool, &note_id)
            .await
            .map_err(|e| AppError::database_error(e.to_string()))?;
    }

    Ok(())
}

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::repos::book_repo::BookRepository;
//     use crate::storage::repos::test_utils::test_book;

//     async fn setup() -> crate::storage::repos::test_utils::TestStorage {
//         let ts = crate::storage::repos::test_utils::init_test_storage().await;
//         let pool = crate::storage::ensure_storage().unwrap().pool().unwrap();
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         ts
//     }

//     #[tokio::test]
//     async fn test_create_and_get_bilingual_pair() {
//         setup().await;
//         let result = create_bilingual_highlight_pair(
//             "book1".into(), 0, 10, 5, "中文高亮".into(), "zh".into(),
//             "book1".into(), 0, 100, 5, "English highlight".into(), "en".into(),
//             0xFF0000,
//         ).await.unwrap();
//         assert_eq!(result.source_note.selected_text.as_deref(), Some("中文高亮"));
//         assert!(result.target_note.is_some());
//         assert_eq!(result.target_note.as_ref().unwrap().selected_text.as_deref(), Some("English highlight"));
//         assert_eq!(result.source_note.paired_note_id, result.target_note.as_ref().unwrap().paired_note_id);

//         let pairs = get_bilingual_highlight_pairs("book1".into(), 0).await.unwrap();
//         assert_eq!(pairs.len(), 1);
//         assert_eq!(pairs[0].source_note.selected_text.as_deref(), Some("中文高亮"));
//         assert!(pairs[0].target_note.is_some());
//     }

//     #[tokio::test]
//     async fn test_get_bilingual_pairs_empty_chapter() {
//         setup().await;
//         let pairs = get_bilingual_highlight_pairs("book1".into(), 0).await.unwrap();
//         assert!(pairs.is_empty());
//     }

//     #[tokio::test]
//     async fn test_delete_bilingual_pair_deletes_both() {
//         setup().await;
//         let result = create_bilingual_highlight_pair(
//             "book1".into(), 0, 10, 5, "中文".into(), "zh".into(),
//             "book1".into(), 0, 100, 5, "English".into(), "en".into(),
//             0xFF0000,
//         ).await.unwrap();

//         let source_id = result.source_note.id.clone();
//         delete_bilingual_highlight_pair(source_id).await.unwrap();

//         let pairs = get_bilingual_highlight_pairs("book1".into(), 0).await.unwrap();
//         assert!(pairs.is_empty());
//     }

//     #[tokio::test]
//     async fn test_delete_nonexistent_pair_succeeds() {
//         setup().await;
//         let result = delete_bilingual_highlight_pair("nonexistent-id".into()).await;
//         assert!(result.is_ok());
//     }
//     #[tokio::test]
//     async fn test_align_bilingual_content_basic() {
//         let result = align_bilingual_content(
//             "你好世界。这是一个测试。".to_string(),
//             "Hello World. This is a test.".to_string(),
//             0.3,
//         ).await.unwrap();
//         assert!(!result.segments.is_empty());
//     }

//     #[tokio::test]
//     async fn test_simple_bilingual_align() {
//         let result = simple_bilingual_align(
//             "你好。测试。".to_string(),
//             "Hello. Test.".to_string(),
//         ).await.unwrap();
//         assert!(!result.segments.is_empty());
//     }

//     #[tokio::test]
//     async fn test_bilingual_exceeds_max_length() {
//         let long = "x".repeat(1_500_000);
//         let result = align_bilingual_content(
//             long.clone(), long, 0.3,
//         ).await;
//         assert!(result.is_err());
//     }
// }
