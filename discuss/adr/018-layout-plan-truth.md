# ADR-018：LayoutPlan 真理 — 布局计划作为分页与渲染之间唯一正式边界

- **状态**：已接受（Phase 13，2026-07-16）
- **日期**：2026-07-16
- **背景**：分页器（`FlutterBlockPaginator`）当前使用 `lineCount × estimatedLineHeight` 估算行高，并将 TextPainter 断行、高度估计与页面装箱混合在同一个状态机中。渲染端从 `ReaderRenderConfig` 和 `ActiveChapterIr` 全局状态读取信息。两者之间存在隐式假设耦合，导致 8dp slack、页面边界飘移和调试困难。

## 决策

1. **布局计划（LayoutPlan）是分页与渲染之间唯一的正式边界**。分页器产生不可变计划，渲染器只消费计划，不重新解释页边界。

2. **LayoutSpec 包含所有影响断行和分页的参数**。渲染组件不得从 `MediaQuery`、Theme 或其它全局状态隐式读取影响布局的参数。颜色、背景色、高亮和选择状态不影响布局，不应进入 `LayoutSpec`。

3. **BlockLayout 源自真实 TextPainter 测量**。行高必须由 `computeLineMetrics().height` 产生，而非 `fontSize × lineHeight × lineCount`。

4. **PagePlan 是分页器消费 BlockLayout 产生的不可变页面集合**。分页算法不直接理解字体、`TextStyle`、`TextPainter`。

5. **LayoutSnapshot 是 session 对外发布的唯一快照**。UI 每帧只能看到一个内部一致的不可变计划。session 不再分别暴露可能错配的 IR、descriptors 和 config hash。

6. **过渡期共存**：`PagePlan` 和 `PackedPage` 通过 adapter 桥接。`ActiveChapterIr` 随 Phase 4 移除。

## 不变量

```
page[i].endUtf16 == page[i + 1].startUtf16
startUtf16 <= endUtf16
LayoutKey 不同的计划禁止复用或互相 promote
页面范围必须完整覆盖已布局内容，无重叠、无空隙
```

## 核心类型

| 类型 | 位置 | 作用 |
| ------ | ------ | ------ |
| `LayoutSpec` | `layout/layout_spec.dart` | 不可变排版参数聚合体，不含颜色/背景 |
| `LayoutKey` | `layout/layout_key.dart` | LayoutSpec 的不可变标识（hash 比较） |
| `BlockLayout` | `layout/block_layout.dart` | 一个 IR 块的完整行式布局结果 |
| `LineLayout` | `layout/block_layout.dart` | 单行 UTF-16 范围 + 真实高度 |
| `PagePlan` | `pagination/page_plan.dart` | 一页的完整描述（which fragments, 范围, 高度） |
| `PageFragment` | `pagination/page_plan.dart` | 页内一块连续渲染片段 |
| `LayoutSnapshot` | `layout/layout_snapshot.dart` | session 对外发布的原子快照 |

## 迁移顺序

```
Phase 1: 定义类型 + adapter → 产品无行为变化
Phase 2: ParagraphLayouter 产生真实 BlockLayout
Phase 3: PagePacker 消费 BlockLayout → PagePlan
Phase 4: Renderer 直接消费 PagePlan, 移除 ActiveChapterIr
Phase 5: LayoutSnapshot 原子化 session 状态
Phase 6: 删除旧 PackedPage/PackedBlockSlice/FlutterBlockPaginator
```

## 理由

- 消除分页器与渲染器之间的隐式假设耦合，使页面边界来源显式化。
- 真实行高消除 8dp slack 的根源。
- `PagePlan` 使分页算法的纯逻辑可单元测试，无需 Widget 树。
- `LayoutSnapshot` 消除多字段不同步的时序问题。
- 过渡期共存确保每阶段可独立验证和回退。

## 验收

- `LayoutSpec` 包含 `TextScaler`、`baselineAlign`、字体、宽高、段距，不包含颜色/背景。
- `LayoutKey` 覆盖所有影响布局的参数，改变任一参数产生不同的 Key。
- adapter 转换前后 descriptor 范围完全一致。
- 产品行为在 Phase 1 通过后无可见变化。

## 关联

- [ADR-006](./006-rust-flutter-division.md)：Rust/Flutter 分工
- [ADR-016](./016-flutter-pagination-engine-proposed.md)：（未落地，本 ADR 取代其分页引擎决策）
- [ADR-017](./017-reading-offset-utf16-contract.md)：UTF-16 阅读坐标
