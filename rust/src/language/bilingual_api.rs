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

// ============================================================
// 文件作用：双语对齐与高亮配对 API。
//
// 公有结构体：
//   - AlignedSegment — 对齐片段
//   - BilingualAlignment — 对齐结果
//   - BilingualHighlightPair — 双语高亮配对
//   - BilingualHighlightParams — 创建配对参数
//
// 公有函数：
//   - align_bilingual_content() — 对齐双语文本（基于相似度匹配）
//   - create_bilingual_highlight_pair() — 创建双语高亮配对
//   - get_bilingual_highlight_pairs() — 获取章节双语高亮配对
//   - delete_bilingual_highlight_pair() — 删除一对双语高亮
// ============================================================

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
        return Err(AppError::InvalidInput { reason: format!(
            "bilingual alignment input too large: {} bytes (max {})",
            chinese_content.len() + english_content.len(),
            MAX_BILINGUAL_LEN,
        ).into() });
    }

    let similarity = min_similarity.max(0.3).min(1.0);

    tokio::task::spawn_blocking(move || {
        crate::parser::bilingual::align_bilingual_content(
            chinese_content,
            english_content,
            similarity,
        )
    })
    .await
    .map_err(|e| AppError::TaskPanic { task_name: "bilingual alignment".into(), details: e.to_string().into() })?
    .map_err(|e| AppError::InternalError { reason: format!("bilingual alignment failed: {}", e).into() })
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
#[allow(clippy::too_many_arguments)]
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
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;

    NoteRepository::save(&pool, &target_note)
        .await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;

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
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;

    // Batch fetch all partner notes in a single query (replaces N+1)
    let query_pairs: Vec<(String, String)> = paired_notes
        .iter()
        .filter_map(|n| n.paired_note_id.as_ref().map(|p| (p.clone(), n.id.clone())))
        .collect();

    let partners = NoteRepository::find_partner_notes_batch(&pool, &query_pairs)
        .await
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;

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
        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;

    if let Some(n) = note {
        if let Some(ref pair_id) = n.paired_note_id {
            let partner = NoteRepository::find_partner_note(&pool, pair_id, &note_id)
                .await
                .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
            if let Some(partner) = partner {
                if partner.id != note_id {
                    NoteRepository::delete_by_id(&pool, &partner.id)
                        .await
                        .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
                }
            }
        }
        // 删除当前 note
        NoteRepository::delete_by_id(&pool, &note_id)
            .await
            .map_err(|e| AppError::DatabaseError { reason: e.to_string().into() })?;
    }

    Ok(())
}

