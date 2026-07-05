# Pagination Guidelines

> 分页架构、模式与契约。所有章节统一走 IR → ContentBlocks 路径。

---

## 架构决策

### ADR: 分页真理源统一为 ContentBlocks（P0）

**Context**: Phase 1-3 双路径（`PageStreamer` plainText + `BlockPaginationState` contentBlocks）导致 partial→full 转换时模式切换 → 排版跳变。

**Decision**: TXT/EPUB 章节所有分页路径统一走 ContentBlocks：

- `max_chars=None`（全章）：`try_paginate_chapter_blocks` → 完整 IR paginate
- `max_chars=Some(N)`（首屏 partial）：`filter_blocks_to_chars` 截取前 N chars 对应 blocks → partial paginate → 缓存完整 IR 供 expand

**Why**:

- 消除 `plainText→contentBlocks` 模式切换导致的视觉跳变
- IR 只加载一次（partial 阶段加载，expand 阶段复用）
- 渲染路径统一（`buildBlockPageContent`），首屏/全章一致

**PageStreamer 角色**: 降级为 fallback（非 TXT/EPUB 格式，block 路径失败时）。不再作为首屏快路径。

---

## 核心契约

### `BlockPaginationState`

```rust
pub(crate) struct BlockPaginationState {
    pub ir: ChapterContentIr,          // 完整 IR（partial 时也保存完整）
    pub result: BlockPaginateResult,   // 当前分页结果（partial 或 full）
    pub is_partial: bool,              // true → expand 可用
}
```

**不变量**:

- `is_partial=true` 时，`ir.blocks.len()` >= `result` 覆盖的 blocks
- `expand_to_full` 仅在 `is_partial=true` 时调用（否则 panic）
- expand 后 `is_partial=false`，`result` 为完整结果

### `expand_to_full`

```rust
pub async fn expand_to_full(
    &mut self,
    config: TypesetConfig,
) -> Result<PaginateResult, AppError>
```

**契约**:

- 前置条件：`self.is_partial == true`
- 行为：用缓存 `self.ir` + `config` 重新调用 `paginate_chapter_ir_chunked`
- 后置条件：`self.is_partial == false`，`self.result` 为完整结果
- 模式：始终返回 `ContentBlocks`
- 性能：~10-50ms（无磁盘 IO，仅 re-paginate）

### `filter_blocks_to_chars`

```rust
fn filter_blocks_to_chars(
    blocks: &[ContentBlock],
    max_chars: u64,
) -> Vec<ContentBlock>
```

**契约**:

- 输入：完整 block 列表 + 字符上限
- 输出：前 `max_chars` 字符对应的 blocks
- 边界处理：
  - 完整落在 limit 内的 block → 原样保留
  - 跨越 limit 边界的 `TextBlock` → 截断（text 按字符截断，spans 丢弃）
  - 跨越 limit 边界的 `ImageBlock` → 跳过（不可截断）
- `max_chars=0` → 返回空 Vec
- 使用 `block.plain_start()` / `block.plain_len()` 计算偏移，无需额外 `plain_text` 参数

---

## 模式

### Partial → Full Expand（快速扩展）

**场景**: 首屏 partial paginate（`max_chars=2000`）→ 全章 expand。

**错误做法**:

```rust
// ❌ 重新调用 paginate_chapter → 重新加载 IR → 磁盘 IO ~5-20ms
apply_session_repagination(handle.session_id, entry, None, None).await
```

**正确做法**:

```rust
// ✅ 检测 partial block state → 直接用缓存 IR expand
if let PaginationEngine::Block(ref state) = entry.engine
    && state.is_partial
{
    let mut state = state.clone();
    let result = state.expand_to_full(entry.config.clone()).await?;
    // 同步更新 PaginationStore LRU + SESSION_MAP
    let cache_key = entry.cache_key();
    PaginationStore::global().put(cache_key, PaginationEngine::Block(state.clone()));
    entry.engine = PaginationEngine::Block(state);
    SESSION_MAP.lock().insert(session_id, entry);
    return Ok(result);
}
```

**关键**: expand 后必须同步更新 `PaginationStore`（path API / adopt 依赖 LRU 副本）。

---

## 禁止模式

### Don't: Partial 分页切换模式

```rust
// ❌ firstSpine 用 plainText → expand 后切换到 contentBlocks → 排版跳变
// 旧行为: beginPaginate(max_chars=2000) → mode=PlainText → UI 渲染
//        → expandToFullChapter → mode=ContentBlocks → UI 重建
```

**症状**: `[LayoutChange]` 日志显示 `mode plainText→contentBlocks`，用户看到页面重排。

**修复**: firstSpine 也用 contentBlocks → `[LayoutChange]` 显示 `mode contentBlocks→contentBlocks`。

---

## 测试契约

### partial→full 流程测试要点

1. **expand_to_full 增加页数**: partial（少量 blocks）→ full（所有 blocks），页数应增加
2. **mode 保持 contentBlocks**: partial 和 full 结果 mode 均为 `ContentBlocks`
3. **is_partial 正确翻转**: expand 后 `is_partial=false`
4. **非 partial 状态调用 panic**: `expand_to_full` 在 `is_partial=false` 时 assert 失败

### filter_blocks_to_chars 测试要点

1. 全部 blocks 在 limit 内 → 返回等量 blocks
2. 边界截断 → 包含完整块 + 截断的边界块
3. `max_chars=0` → 空结果
4. 精确边界 → 恰好包含 N 个完整块
