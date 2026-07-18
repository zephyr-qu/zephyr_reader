//! 双语对齐与双语高亮配对业务逻辑
//!
//! 提供中英双语文本的自动对齐功能和双语高亮配对功能。
//! 数据访问委托给 NoteRepository。

use crate::common::AppError;
use crate::domain::bilingual::{
    BilingualAlignment, BilingualHighlightPair, BilingualHighlightParams,
};
use crate::domain::note::Note;
use crate::domain::note::note_repo::NoteRepository;
use crate::infra::manager::storage_pool;

/// 最大双语对齐输入长度
const MAX_BILINGUAL_LEN: usize = 2_000_000;

/// 对齐双语文本（基于相似度匹配）
pub async fn align_bilingual_content(
    chinese_content: String,
    english_content: String,
    min_similarity: f32,
) -> Result<BilingualAlignment, AppError> {
    if chinese_content.len() + english_content.len() > MAX_BILINGUAL_LEN {
        return Err(AppError::InvalidInput {
            reason: format!(
                "bilingual alignment input too large: {} bytes (max {})",
                chinese_content.len() + english_content.len(),
                MAX_BILINGUAL_LEN,
            ),
        });
    }

    let similarity = min_similarity.clamp(0.3, 1.0);

    tokio::task::spawn_blocking(move || {
        crate::domain::bilingual::engine::align_bilingual_content(
            chinese_content,
            english_content,
            similarity,
        )
    })
    .await
    .map_err(|e| AppError::TaskPanic {
        task_name: "bilingual alignment".into(),
        details: e.to_string(),
    })?
    .map_err(|e| AppError::InternalError {
        reason: format!("bilingual alignment failed: {}", e),
    })
}

/// 创建双语高亮配对（同时创建中文和英文两条高亮）
pub async fn create_bilingual_highlight_pair(
    params: &BilingualHighlightParams,
) -> Result<BilingualHighlightPair, AppError> {
    let chinese_note = Note::highlight(
        &params.book_id,
        params.chapter_index,
        params.chinese_char_offset,
        params.chinese_length,
        &params.chinese_text,
        params.highlight_color,
        params.language.clone(),
        None,
    );
    let english_note = Note::highlight(
        &params.book_id,
        params.chapter_index,
        params.english_char_offset,
        params.english_length,
        &params.english_text,
        params.highlight_color,
        params.language.clone(),
        Some(chinese_note.id.clone()),
    );

    let pool = storage_pool()?;
    NoteRepository::save(&pool, &chinese_note).await?;
    NoteRepository::save(&pool, &english_note).await?;

    Ok(BilingualHighlightPair {
        chinese_note_id: chinese_note.id,
        english_note_id: english_note.id,
        chinese_text: params.chinese_text.clone(),
        english_text: params.english_text.clone(),
    })
}

/// 获取章节的所有双语高亮配对
pub async fn get_bilingual_highlight_pairs(
    book_id: &str,
    chapter_index: i64,
) -> Result<Vec<BilingualHighlightPair>, AppError> {
    let pool = storage_pool()?;
    let notes = NoteRepository::find_paired_notes_in_chapter(&pool, book_id, chapter_index).await?;

    let mut pairs = Vec::new();
    let mut i = 0;
    while i < notes.len() {
        if let Some(paired_id) = &notes[i].paired_note_id
            && let Some(partner) = notes.iter().find(|n| &n.id == paired_id)
        {
            pairs.push(BilingualHighlightPair {
                chinese_note_id: notes[i].id.clone(),
                english_note_id: partner.id.clone(),
                chinese_text: notes[i].selected_text.clone().unwrap_or_default(),
                english_text: partner.selected_text.clone().unwrap_or_default(),
            });
            i += 1;
            if i < notes.len() && notes[i].id == partner.id {
                i += 1;
            }
            continue;
        }
        i += 1;
    }
    Ok(pairs)
}

/// 删除一对双语高亮
pub async fn delete_bilingual_highlight_pair(
    chinese_note_id: &str,
    english_note_id: &str,
) -> Result<(), AppError> {
    let pool = storage_pool()?;
    NoteRepository::delete_by_id(&pool, chinese_note_id).await?;
    NoteRepository::delete_by_id(&pool, english_note_id).await?;
    Ok(())
}
