//! 阅读引擎位置提示 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::engine_positions::engine_position_repo::EnginePositionHintRepository;
use crate::domain::engine_positions::models::EnginePositionHint;
use crate::infra::manager::storage_pool;

/// 保存引擎私有位置提示（每本书一行，整体覆盖写）
#[frb]
pub async fn save_engine_position(hint: EnginePositionHint) -> Result<(), AppError> {
    tracing::debug!(
        "[engine_position] save_engine_position: book_id={}, engine_kind={}",
        hint.book_id,
        hint.engine_kind
    );
    let pool = storage_pool()?;
    EnginePositionHintRepository::save(&pool, &hint).await
}

/// 获取书籍的引擎位置提示
#[frb]
pub async fn get_engine_position(book_id: String) -> Result<Option<EnginePositionHint>, AppError> {
    tracing::debug!("[engine_position] get_engine_position: book_id={}", book_id);
    let pool = storage_pool()?;
    EnginePositionHintRepository::find_by_book(&pool, &book_id).await
}
