//! 分页引擎：plain `PageStreamer` 或 block `BlockPaginationState`（Phase 2.5 统一 LRU 值类型）。

use crate::reading::block_state::BlockPaginationState;
use crate::text::PageStreamer;

/// Session / 内存 LRU 持有的分页引擎。
#[derive(Clone)]
pub(crate) enum PaginationEngine {
    Plain(PageStreamer),
    Block(BlockPaginationState),
}
