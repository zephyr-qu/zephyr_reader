# Design: 统一分页真理源 — ContentBlocks 全覆盖

## 目标

让 `paginate_chapter` 在所有路径（partial / full）都使用 `contentBlocks` 模式，
消除 `partial→full` 转换时的 mode 跳变。

## 改造范围

```
Rust 侧 (核心改动):
  rust/src/reading/pagination.rs   ← try_paginate_chapter_blocks 支持 max_chars
  rust/src/reading/block_state.rs  ← partial block state 支持 expand
  rust/src/reading/session.rs      ← paginate_session_full 处理 partial block state

Dart 侧 (适配):
  lib/features/reader/core/data/rust_pagination_session.dart  ← beginPaginate 结果 mode 变化
  lib/features/reader/core/application/chapter_load_orchestrator.dart ← 日志适配

PageStreamer: 保留作为 fallback（block 路径失败时降级），但不参与首屏快路径。
```

## Rust 改动

### 1. `pagination.rs` — `try_paginate_chapter_blocks` 支持 partial

当前 gate（line 87-89）:

```rust
if max_chars.is_some() {
    return Ok(None);  // ← 移除
}
```

新逻辑：

```
try_paginate_chapter_blocks(book_id, path, chapter_index, config, max_chars):
  1. 移除 max_chars.is_some() gate
  2. format 检查不变
  3. Cache hit 逻辑不变（命中直接返回，命中的一定不是 partial）
  4. Cache miss:
     a. load_chapter_content_ir() → 完整 IR
     b. if max_chars.is_some():
        blocks = filter_blocks_to_chars(ir.blocks, ir.plain_text, max_chars)
        partial_ir = ChapterContentIr { blocks, plain_text: ir.plain_text }
        result = paginate_chapter_ir_chunked(partial_ir, config)  // 只排 partial blocks
        store 完整 IR + result 到 BlockPaginationState { is_partial: true }
        → PaginateResult { is_partial: true, mode: ContentBlocks, pages: partial }
     c. else (全章):
        走现有流程（不变）
```

**新增辅助函数：**

```rust
/// 截取 plain_text 中前 max_chars 个字符对应的 blocks。
/// 保留完整包含块 + 截断最后一个跨越边界的块。
fn filter_blocks_to_chars(
    blocks: &[ContentBlock],
    plain_text: &str,
    max_chars: u64,
) -> Vec<ContentBlock> {
    let max_chars = max_chars as usize;
    let mut filtered = Vec::new();
    let mut cumulative = 0usize;
    
    for block in blocks {
        let start = block.plain_start() as usize;
        let len = block.plain_len() as usize;
        let end = start + len;
        
        if end <= max_chars {
            filtered.push(block.clone());
        } else if start < max_chars {
            // 跨越边界的块：截断
            let truncated_len = (max_chars - start) as u32;
            // 仅保留 TextBlock（ImageBlock 不可截断）
            if let ContentBlock::Text(ref tb) = block {
                filtered.push(ContentBlock::Text(TextBlock {
                    plain: BlockPlainRange::new(tb.plain.plain_start, truncated_len),
                    // 保留原始 rich_text 但截断逻辑较复杂，首屏 2000 chars
                    // 必然包含足够文本，此边界块可简单处理
                    ..tb.clone()
                }));
            }
        }
        cumulative = end;
        if cumulative >= max_chars {
            break;
        }
    }
    filtered
}
```

### 2. `block_state.rs` — Partial expand 支持

`BlockPaginationState` 已经存储完整 `ir: ChapterContentIr` + 当前 `result: BlockPaginateResult`。

当 `is_partial = true` 且调用 expand 时：

- 用完整 `ir` 重新 paginate（完整的 `paginate_chapter_ir_chunked(ir, config)`）
- 更新 `result` + `is_partial = false`

新增方法：

```rust
impl BlockPaginationState {
    /// 从 partial 扩展到全章（用已缓存的完整 IR）。
    pub async fn expand_to_full(&mut self, config: TypesetConfig) -> Result<PaginateResult, AppError> {
        assert!(self.is_partial, "expand_to_full called on non-partial state");
        let result = tokio::task::spawn_blocking(move || {
            crate::text::block_paginator::paginate_chapter_ir_chunked(&self.ir, config)
        }).await?;
        self.result = result.clone();
        self.is_partial = false;
        Ok(result.to_legacy_paginate_result(ChapterPaginationMode::ContentBlocks))
    }
}
```

### 3. `session.rs` — `paginate_session_full` 适配

```rust
pub(crate) async fn paginate_session_full(handle, config: Option<TypesetConfig>) {
    if let Some(cfg) = config {
        return repaginate_session(handle, cfg, None).await;
    }
    let entry = lookup_pagination_session(handle.session_id)?;
    
    // 如果是 partial block state，直接用缓存的完整 IR expand
    if let PaginationEngine::Block(ref state) = &entry.engine {
        if state.is_partial {
            // clone state, expand, write back
            let mut state = state.clone();
            let result = state.expand_to_full(entry.config.clone()).await?;
            // update SESSION_MAP
            SESSION_MAP.lock().insert(session_id, PaginationSessionEntry {
                engine: PaginationEngine::Block(state),
                ..entry
            });
            return Ok(result);
        }
    }
    
    apply_session_repagination(handle.session_id, entry, None, None).await
}
```

## Dart 适配

### `rust_pagination_session.dart` — beginPaginate 结果

```dart
// beginPaginate → _createSession(max_chars: 2000)
// Rust 现在返回 mode=contentBlocks, partial=true（不再是 plainText）
// → _applyPaginateResult 设置 mode=contentBlocks → UI 用 contentBlocks 渲染首屏
// → expandToFullChapter 后 mode 仍为 contentBlocks → 无跳变
```

**关键变化：** `_applyPaginateResult` 在 partial 阶段收到的是 `contentBlocks` 模式，
缓存是 blocks（不是 plain content），渲染器走 `buildBlockPageContent` 路径。

### `chapter_load_orchestrator.dart` — 日志

```
[LayoutChange] ch=0 pages 3→12 mode contentBlocks→contentBlocks  ← mode 不变！
```

## 性能影响

| 操作 | 旧 (plainText partial) | 新 (contentBlocks partial) | 差异 |
| ------ | ---------------------- | --------------------------- | ------ |
| IR 加载 | 无 | ~5-20ms (parse chapter structure) | ↑ |
| Block 截断 | 无 | ~0.1ms (filter blocks) | ↑ |
| Block paginate (partial) | 无 | ~30-100ms (paginate partial blocks) | ↑ |
| firstSpine 总计 | ~10-80ms | **~40-200ms** | **+30-120ms** |
| expandToFullChapter | ~80-500ms | ~10-50ms (IR 已缓存, 仅 re-paginate) | ↓ |
| **总体加载** | **~100-600ms** | **~50-250ms** | **基本持平或更快** |

> expand 阶段因为 IR 已在 firstSpine 阶段加载缓存，只需 re-paginate，反而更快。

## 文件清单

### Rust

- [x] `rust/src/reading/pagination.rs` — try_paginate_chapter_blocks + filter_blocks_to_chars
- [x] `rust/src/reading/block_state.rs` — expand_to_full
- [x] `rust/src/reading/session.rs` — paginate_session_full 适配

### Dart

- [x] `lib/features/reader/core/data/rust_pagination_session.rs` — 日志适配
- [x] `lib/features/reader/core/application/chapter_load_orchestrator.dart` — 日志适配

### 不修改

- `lib/features/reader/rendering/paginated_renderer.dart` — 已支持两种模式
- `lib/features/reader/rendering/block_page_content.dart` — 不需要改
- `lib/features/reader/core/application/pagination_coordinator.dart` — 接口不变
