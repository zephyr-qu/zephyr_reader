---
name: 引擎小优化合集
overview: planc/pland 完成后的低成本高收益项：跳过 redundant full repaginate、expandToFull 传 None、测试与文档补全、可选收紧 Dart fallback。
todos:
  - id: skip-redundant-full
    content: expandOnly + sessionIsPartial==false 时跳过 expandToFullChapter
    status: pending
  - id: expand-none-path
    content: config hash 未变时 expandToFullChapter 走 paginate_session_full(handle, None)
    status: pending
  - id: configreload-offset
    content: _runConfigReload 统一用 request.initialCharOffset 解析 pageIndex
    status: pending
  - id: polish-tests
    content: preserveContent / pageIndex / sessionConfigHash fallback 单测
    status: pending
  - id: readme-sync
    content: lib/features/reader/README 与 doc/README 互链
    status: pending
isProject: false
---

# 引擎小优化合集（Polish）

在 [pland.md](pland.md) 与 [plane/planf](plane-cross-chapter-preload.md) 之间的 **低成本** 改进项，可拆成 1–2 个小 PR。

---

## 1. 跳过 redundant full repaginate

**问题**：[`_runExpandOnly`](lib/features/reader/core/application/chapter_load_orchestrator.dart) 恒返回 `isPartial: true`，即使 session 已是 full，仍会 `expandToFullChapter`。

**改法**（依赖 pland PR2 `sessionIsPartial`）：

```dart
if (!repo.sessionIsPartial) {
  return (totalPages: descriptors.length, isPartial: false);
}
```

**验收**：initialize `expandOnly` 路径日志出现 `fullPaginate skipped`。

---

## 2. expandToFull 同 config 走 None

**问题**：[`expandToFullChapter`](lib/features/reader/core/data/rust_pagination_session.dart) 始终 `paginateSessionFull(handle, config: newConfig)`，同 hash 也走完整 repaginate。

**改法**：

```dart
if (_sessionConfigHash == newConfig.configHash.toInt()) {
  result = await core_api.paginateSessionFull(handle: _handle!, config: null);
} else {
  result = await core_api.paginateSessionFull(handle: _handle!, config: newConfig);
}
```

**验收**：Rust 日志 partial→full 同 config 不重复 validate config。

---

## 3. configReload pageIndex 一致性

**问题**：[`_runConfigReload`](lib/features/reader/core/application/chapter_load_orchestrator.dart) 用 `_pageState.currentCharOffset`；finalize 用 `request.initialCharOffset`。

**改法**：统一 `request.initialCharOffset`（debounce 已传 current offset）。

---

## 4. 测试补全（polish review 缺口）

| 用例 | 文件 |
|------|------|
| configReload + preserveContent → chapterContent 保持 data | chapter_manager_test |
| configReload 后 pageIndex 随 offset 更新 | chapter_manager_test |
| sessionConfigHash==null → firstSpine fallback | chapter_manager_test |
| repaginate font_size 集成 | core_pagination_test |

---

## 5. 文档

- [`lib/features/reader/README.md`](../lib/features/reader/README.md) 增加指向 [`doc/README.md`](README.md)
- archive 中 planc polish 条目与实现同步

---

## 6. 可选：收紧 Dart fallback（单独决策）

[`fallbackToCalculatePages`](lib/features/reader/core/application/pagination_coordinator.dart) 仍用 Dart `calculatePages`。

**仅当** 生产 telemetry 显示 fallback 率 <0.1% 时考虑改为「报错 + 重试 repaginate」；否则保留。

---

## PR 建议

**单 PR「engine-polish」**：1 + 2 + 3 + 4 + 5，约 0.5–1 天。

**依赖**：pland PR2 完成后再做 1；2 可与 planc 后立即做。
