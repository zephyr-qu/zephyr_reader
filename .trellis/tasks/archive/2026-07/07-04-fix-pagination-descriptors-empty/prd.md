# PRD: 修复分页渲染器 descriptors 为空时的 fallback 问题

## 问题描述

运行日志重复出现以下两条警告：

```
[Renderer] build: descriptors null/empty → fallback
[Renderer] _buildFallbackPagination: no pagination data
```

即 `PaginatedModeRenderer.build()` 读取 `dataSource.descriptors` 时发现 `null` 或空列表，导致渲染器回退到错误占位 UI。

## Root Cause

在 `ChapterLoadOrchestrator._runStagingPromote()` 中，存在一个 session 生命周期管理错误：

```dart
// chapter_load_orchestrator.dart ~L579-582
final result = await _pagination.paginateFirstScreenFromCache(
  request.chapterIndex,
);

// 旧 session 在 promote 成功后释放 ← 但这是错误的！
_contentRepo.disposePagination();
```

`paginateFirstScreenFromCache()` → `_repo.beginPaginateFromCache()` 内部已经：

1. `_releaseHandle()` — 释放了旧 Rust handle
2. `core_api.createPaginationSessionAdopt()` — 创建并设置新 handle 和新 descriptors
3. `_applyPaginateResult()` — 写入新 descriptors

当 `beginPaginateFromCache` 返回时，`_descriptors` 已经指向新 session 的数据。但紧接着 `_contentRepo.disposePagination()` 调用 `_session.dispose()`，将新设置的 `_descriptors` 置为 `null`。

随后信号更新设置 `_isLoading = false`，UI 重建 → `PaginatedModeRenderer` 读取到 null descriptors → 触发 fallback。

## 修复方案

**删除 `_runStagingPromote` 中多余的 `_contentRepo.disposePagination()` 调用。**

旧 session 的清理已由 `beginPaginateFromCache` / `beginPaginate` 内部的 `_releaseHandle()` 完成。此处的 `disposePagination()` 是错误地销毁了刚创建的 session。

## 验收标准

1. `_runStagingPromote` 路径（相邻章过渡）不再触发 `[Renderer] build: descriptors null/empty → fallback`
2. UI 在章节过渡后正确显示分页内容
3. `dart analyze` 通过，无新警告
4. 现有单元测试全部通过

## 风险

- 低风险：仅删除一行 dispose 调用
- disposePagination 在 staging promote 中的唯一用途就是清理旧 session，而旧 session 已经由上游清理
- 不影响其他路径（normalLoad / configReload / expandOnly / scroll mode）
