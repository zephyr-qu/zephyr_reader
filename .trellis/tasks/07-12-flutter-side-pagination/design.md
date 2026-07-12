# Design — 方案 2：Rust 出 IR，Flutter 分页排版渲染

## 目标架构（实验）

```
┌─────────────────────────────────────────────────────────┐
│  Rust（只出内容）                                         │
│  EPUB/TXT parse → ChapterContentIr                      │
│  (blocks + plainText + 可选图 asset 路径)                 │
│  API: get_chapter_content_ir(book_id, chapter_index)    │
│  ✗ 不调用 BlockPaginator / session / calibration apply  │
└──────────────────────────┬──────────────────────────────┘
                           │ ContentBlock[] + plainText
                           ▼
┌─────────────────────────────────────────────────────────┐
│  Flutter Spike                                          │
│  1. 排版：TypesetMeasureParams → TextStyle/Strut        │
│  2. 分页：FlutterBlockPaginator（TextPainter 量高装箱）   │
│  3. 渲染：现有 block_page_content / PageView            │
│  4. 进度：descriptors 上 charOffset ↔ pageIndex         │
└─────────────────────────────────────────────────────────┘
```

与现网对比：砍掉「Rust 装箱 + metrics 回传 + ICU store_line_breaks」整环。

## 模块划分（新建，旁路现网）

| 模块 | 职责 | 建议路径 |
|------|------|----------|
| Flag | 开关 | `ReaderConfig` 或 debug-only `kFlutterPaginationSpike` |
| IR 加载 | 只调 `getChapterContentIr` | 薄封装，可复用 repo 方法 |
| `FlutterBlockPaginator` | IR → `List<SpikePage>` | `lib/features/reader/spike/` |
| `SpikePage` | plain 区间 + 块切片 + 可选图 | 本地类型，不必 FRB |
| Spike Session | 持 IR、descriptors、按页取切片 | 替代 `RustPaginationSession` |
| Spike 入口 | orchestrator 旁路或独立 debug 页 | 最小侵入：orchestrator 一处 if |

**原则**：新代码进 `spike/` 包；不改 Rust 分页引擎；现网路径零行为变化（flag 关）。

## 装箱算法（MVP）

对每个 `ContentBlock`：

1. **Text**：用与渲染相同的 `TextStyle`/`StrutStyle`/`measureSliceLayout` 得行高与总高；按行累加进当前页；超 `bodyHeight` 则在行边界翻页（必要时块内切分，记录 `isBlockStart/End`）。
2. **Image**（第二刀）：估高；放不下则独占页（对齐现 `InlineContain`/`FullPage` 语义的简化版）。
3. 段距 / 块 padding：计入页高预算（与 `block_page_content` 一致，避免双加）。

输出每页：

```dart
class SpikePage {
  final int startOffset; // plain Unicode
  final int endOffset;
  final List<SpikeBlockSlice> slices;
}
```

`charOffset → pageIndex`：二分 descriptors（抄现 Rust 语义）。

## 渲染

优先复用 `buildBlockPageContent`：把 `SpikeBlockSlice` 映射为现有 `PageBlockSlice` 形状，或抽一层共同接口。避免第二套 Widget 树。

## 进度与配置变更

- 持久化仍 ADR-001：`chapterIndex + charOffset`。
- 字号/行距变：丢弃 Spike Session，重新装箱；用 charOffset 定位新页。
- **不做** Flutter→Rust calibration；测量只服务本侧装箱。

## 破损面（首轮接受）

| 能力 | 首轮 |
|------|------|
| staging 零 loading | 不做 |
| sled 分页缓存 | 不做（可内存缓存 IR） |
| 大章 | 先主 isolate；卡顿则再 `compute` |
| pageTurn curl | 可用 slide；curl 后接 |
| 双语 | 不接 |

## 风险

| 风险 | 缓解 |
|------|------|
| 与 orchestrator 缠死 | flag 早退 + spike 目录 |
| 块内切分与高亮偏移 | 测试 charOffset 往返 |
| 图/样式遗漏 | TXT 先绿，再 EPUB |
| 误合并 | 分支名 `explore/` + PRD Out of Scope |

## 成功 / 失败判据

**Go（值得开 ADR）**：TXT 金路径 overflow 稳定 `ok`，改字号书签不飘，代码量可控。  
**No-Go**：装箱复杂度逼近再造 BlockPaginator，且 staging/图成本过高。  
**Conditional**：TXT 成、EPUB 图或大章未证 → 第二轮 spike 再定。
