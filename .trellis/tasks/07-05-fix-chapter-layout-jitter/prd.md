# PRD: 修复章节加载后排版跳变

## 问题

章节加载时出现明显的排版跳变——页面数量、文字排版在首屏渲染后突然变化。

### 根因

Orchestrator 的分页流程：

```
firstSpine: beginPaginate(maxChars=2000) → mode=plainText, pages=3, partial=true
  → _isLoading=false → UI 立即用 plainText 模式渲染首屏 3 页

expandToFullChapter: paginateSessionFull → mode=contentBlocks, pages=12, partial=false
  → _applyPaginateResult: 清除缓存，切换到 contentBlocks，12 页
  → _syncPaginationSignalsAfterRepaginate: totalPages 3→12
  → UI 重建：contentBlocks 渲染 12 页 → 排版跳变 ⚡
```

**关键：** `partial→full` 过程中 pagination mode 从 `plainText` 切到 `contentBlocks`。
两个模式渲染路径不同：

- `plainText`: Rust PageStreamer 按行切分纯文本 → `SelectableText.rich(PlainTextSpan)`
- `contentBlocks`: Rust IR 块渲染，按段落/标题/图片分别排版 → `buildBlockPageContent`

模式切换导致页面边界全部重新计算，用户看到文字重排/跳变。

## 修复方案

### 方案 A（推荐）：延迟显示，等 expand 完成再 `_isLoading=false`

**改动：** 在 `_runCalibratedPartialPaginate` 中，当 `quickResult.isPartial=true` 时不立即设置 `_isLoading=false`，推迟到 `_syncPaginationSignalsAfterRepaginate` 后。

**优点：** 彻底消除跳变，UI 只看到最终排版。
**缺点：** 首屏显示延迟增加（~80-500ms，取决于章节大小）。

**实现要点：** `_runCalibratedPartialPaginate` 需要知道后续是否会 expand，当前调用方已经知道 `quickResult.isPartial`。

### 方案 B：强制统一模式，firstSpine 也用 contentBlocks

**改动：** 修改 `beginPaginate(maxChars=2000)` 调用，让 Rust 侧也用 contentBlocks 模式做 partial pagination。

**优点：** 无模式切换，排版前后一致。
**缺点：** 需要 Rust 侧支持 contentBlocks 模式的 partial 分页；contentBlocks 比 plainText 慢。

### 方案 C：平滑过渡

**改动：** 在 `_syncPaginationSignalsAfterRepaginate` 前后，用 AnimatedSwitcher/FadeTransition 掩盖跳变。

**优点：** 不改渲染流程。
**缺点：** 面具方案，排版仍然跳变只是看不到；动画可能比跳变更明显。

### 方案 D：preserveContent 保留旧 rendering mode

**改动：** 在 expand 时保持 `_sessionMode` 不变（仍用 plainText），仅刷新 descriptors。

**优点：** 最简单。
**缺点：** 最终渲染质量低（plainText 不支持 block-level 样式）。

## 验收标准

1. 章节加载后无可见的页面数/排版跳变
2. `[LayoutChange]` 日志中 `mode` 切换已消除（或发生在 `_isLoading=true` 期间）
3. 新增 pagination pipeline 单元测试覆盖 `partial→full` 流程
4. `dart analyze` 无新问题
5. 跨章 stagingPromote 性能不受影响

## 新增日志

`[LayoutChange]` 标签已在以下位置插入：

- `RustPaginationSession._applyPaginateResult()` — 捕获 descriptor 变更（页面数/mode/partial 切换）
- `ChapterLoadOrchestrator._syncPaginationSignalsAfterRepaginate()` — 捕获信号同步（totalPages/pageIndex 跳变）
