# Design — 方案三

## 一句话

页边界真理在 Flutter；Rust 只出 IR；staging = 同算法后台精确预装箱；无校准环。

## 目标架构

```
Rust
  EPUB/TXT → ChapterContentIr (+ 图路径)
  （T4 可选）粗页数 Hint only — 默认不做

Flutter
  当前章：TextPainter 精确装箱 → descriptors → 渲染
  相邻章：同算法预装箱 → staging 首/末屏 → promote 交接
  大章：主 isolate 分块 yield + 首屏优先（非 compute）
  进度：chapterIndex + charOffset（ADR-001）
```

## 相对方案 1 / 2

| | 结论 |
|---|------|
| vs 方案 1（Rust+校准） | 少校准环；多 Dart 装箱 + staging/大章工程 |
| vs 方案 2 | 无哲学差；方案 2 = T0，方案 3 = T0→T5 |

## 模块

| 模块 | 路径 / 职责 |
|------|-------------|
| Flag | `kFlutterPaginationSpike`（方案三总开关） |
| `FlutterBlockPaginator` | IR → `SpikePage[]` |
| `FlutterPaginationSession` | = 升格后的 spike session（持 IR、descriptors、blocks） |
| `SpikeStagingStore` | 相邻章精确预装箱结果（IR+pages+filePath） |
| Staging → `NextChapterStaging` | 填 renderer 虚拟页所需 descriptors/锚页 |
| Orchestrator | flag 开：spike 加载；staging promote 走精确交接 |
| Rust | `get_chapter_content_ir` + 图解码；分页 API 并存至对比结束 |

## Staging 数据流（T2）

```
preloadAdjacent
  → getChapterContentIr
  → FlutterBlockPaginator.paginate（同当前章算法）
  → SpikeStagingStore.{next|prev} = {ir, pages, filePath}
  → NextChapterStaging(descriptors, anchorBlocks, plain) 供虚拟页

promote (adjacentCrossChapter)
  → SpikeSession.install(SpikeStagingStore)
  → 设 pageIndex 首/末
  → clear staging + 预取新相邻章
  ✗ 不调用 Rust adopt / 不重跑校准
```

## 大章（T3）

- **不能**把 TextPainter 装箱搬进普通 `compute`/`Isolate.run`（字体子系统绑主 isolate）。
- 做法：主 isolate `paginateAsync`，每 N 块 `await Duration.zero` 让出事件循环；`isCancelled` / generation 门控写回。
- 首屏：`maxChars` → `stopAfterPlainOffset` → `isPartial`；随后 `expandToFullChapter` 复用 IR 补全。

## ADR

- [ADR-016](../../../discuss/adr/016-flutter-pagination-engine-proposed.md) 提案对齐方案三。  
- Accept 仅在「对比胜出并合并」时。

## 风险（摘录）

| 风险 | 缓释 |
|------|------|
| Staging 变难 | T2 同算法精确预装箱 |
| 大章卡顿 | T3 isolate |
| 双引擎过久 | 对比后 T5 二选一 |
| Phase 5 冲突 | 不进主线直至对比合并 |
