//! 引擎位置提示管理 — FRB 薄封装层
//!
//! 提供 Readium/Builtin 引擎私有位置恢复信息的持久化接口。
//! 与阅读进度（reading_progress）分离——引擎位置只用于恢复加速，
//! 逻辑位置仍然以 ReadingPosition（chapterIndex + charOffset）为准。

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::engine_position::models::ReadingEnginePosition;
use crate::domain::engine_position::repo::EnginePositionRepository;
use crate::infra::manager::storage_pool;

/// 获取书籍的引擎位置提示
#[frb]
pub async fn get_engine_position_hint(
    book_id: String,
) -> Result<Option<ReadingEnginePosition>, AppError> {
    let pool = storage_pool()?;
    EnginePositionRepository::find_by_book(&pool, &book_id).await
}

/// 保存或更新书籍的引擎位置提示
#[frb]
pub async fn save_engine_position_hint(
    position: ReadingEnginePosition,
) -> Result<(), AppError> {
    let pool = storage_pool()?;
    EnginePositionRepository::save(&pool, &position).await
}

/// 删除书籍的引擎位置提示
#[frb]
pub async fn delete_engine_position_hint(book_id: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    EnginePositionRepository::delete_by_book(&pool, &book_id).await
}
