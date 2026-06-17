---
name: 引擎小优化合集
overview: planc/pland 完成后的低成本高收益项：跳过 redundant full repaginate、expandToFull 传 None、测试与文档补全、可选收紧 Dart fallback。
todos:
  - id: skip-redundant-full
    content: expandOnly + sessionIsPartial==false 时跳过 expandToFullChapter
    status: completed
  - id: expand-none-path
    content: config hash 未变时 expandToFullChapter 走 paginate_session_full(handle, None)
    status: completed
  - id: configreload-offset
    content: _runConfigReload 统一用 request.initialCharOffset 解析 pageIndex
    status: completed
  - id: polish-tests
    content: preserveContent / pageIndex / sessionConfigHash fallback 单测
    status: completed
  - id: readme-sync
    content: lib/features/reader/README 与 doc/README 互链
    status: completed
isProject: false
---

# 引擎小优化合集（Polish）

在 [pland.md](pland.md) 与 [plane](plane-cross-chapter-preload.md) / [planf](planf-layout-kv-cache.md) 之间的 **低成本** 改进项，已全部实施。

---

## 1. 跳过 redundant full repaginate ✅

**问题**：[`_runExpandOnly`](lib/features/reader/core/application/chapter_load_orchestrator.dart) 恒返回 `isPartial: true`，即使 session 已是 full，仍会 `expandToFullChapter`。

**改法**：

```dart
if (!repo.sessionIsPartial) {
  return (totalPages: descriptors.length, isPartial: false);
}
```

**状态**：`_runExpandOnly` 返回 `isPartial: _contentRepo.sessionIsPartial`（pland PR2 `sessionIsPartial` 已到位）。调用方 `run()` 检查 `quickResult.isPartial`，false 时跳过 `expandToFullChapter`。

---

## 2. expandToFull 同 config 走 None ✅

**问题**：[`expandToFullChapter`](lib/features/reader/core/data/rust_pagination_session.dart) 始终 `paginateSessionFull(handle, config: newConfig)`，同 hash 也走完整 repaginate。

**改法**：

```dart
final newHash = core_api.computeConfigHash(config: newConfig);
final configArg = (newHash.toInt() == _sessionConfigHash) ? null : newConfig;
result = await core_api.paginateSessionFull(handle: _handle!, config: configArg);
```

**日志**：`config=reuse` / `config=new` 标明决策。

---

## 3. configReload pageIndex 一致性 ✅

**问题**：[`_runConfigReload`](lib/features/reader/core/application/chapter_load_orchestrator.dart) 本可能用 `_pageState.currentCharOffset` 与 finalize 不一致。

**状态**：已统一使用 `request.initialCharOffset`。

---

## 4. 测试补全 ✅

| 用例 | 覆盖 |
|------|------|
| configReload intent 推导 | `chapter_pagination_intent_resolver_test.dart` |
| normalLoad / expandOnly intent 推导 | 同上 |
| sessionConfigHash==null → firstSpine fallback | 同上 |
| configReload + preserveContent | 同上（intent 层）+ 现有 end-to-end mock 覆盖 |

configReload 全链路测试受限于 Rust FFI mock 不可用，intent resolver 层已验证。

---

## 5. 文档 ✅

- [`lib/features/reader/README.md`](../lib/features/reader/README.md) → 增加指向 [`doc/README.md`](README.md) 的链接
- [`doc/archive/README.md`](archive/README.md) → planc Polish 追加 `expandToFullChapter` config:null 条目
- [`doc/README.md`](README.md) → plang 标记已实现

---

## 6. 可选：收紧 Dart fallback（未实施）

[`fallbackToCalculatePages`](lib/features/reader/core/application/pagination_coordinator.dart) 仍用 Dart `calculatePages`。

**建议**：当生产 telemetry 显示 fallback 率 <0.1% 时再考虑改为「报错 + 重试 repaginate」；当前保留。

---

## 改动历史

| 日期 | 改动 |
|------|------|
| 2026-06-16 | 初始 audit 确认 item 1、3 已在 pland 中完成 |
| 2026-06-16 | item 2：`expandToFullChapter` hash 未变时传 `config: null` |
| 2026-06-16 | item 4：确认 resolver 测试覆盖 intent 推导 |
| 2026-06-16 | item 5：README 互链 + archive 同步 |
