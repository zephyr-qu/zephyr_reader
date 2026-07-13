# 评估 Flutter 分页性能优化方向

## 背景

ADR-016 落地后，Flutter 是唯一的分页装箱引擎。当前性能瓶颈：

1. **主 isolate TextPainter 批量测量** — 大章 `paginateAsync` 用 `yieldEveryBlocks` 让出事件循环，但测量本身仍在主 isolate，大 TXT（~10万字符）耗时 ~10–30ms
2. **无分页结果持久化** — 每次打开章节都重新装箱（即使 IR 和 layout 参数一致）

## 评估方向

### 方向 A：Isolate fragment 装箱

用 `dart:ui` `ParagraphBuilder` 在 isolate 中纯计算文本布局，避免主 isolate TextPainter。

- 需要测：`ParagraphBuilder` 能否在 isolate 中构造和布局
- 对比：当前 `FlutterBlockPaginator._PagePacker` 的 TextPainter 路径
- 风险：`dart:ui` 在 isolate 中受限（字体加载、platform view 等）

### 方向 B：PackedPage 持久化缓存

用 sled 或本地文件缓存 `(config_hash + book_id + chapter_index) → PackedPage[]`。

- 需要设计：`PackedPage` 序列化格式（目前是纯 Dart 类，无 toJson/fromJson）
- 对比：当前每次重装耗时 vs 缓存命中/回退开销
- 风险：缓存无效化策略（字号/行高/字体变更 → config_hash 变化 → 自动 miss，安全）

### 方向 C：不做（当前可接受）

如果 A/B 的实测收益不足以覆盖工程复杂度，保持现状。

## 产出

- 可行性报告：A/B 各方向的技术方案、预计收益、风险
- 推荐优先级和是否开新任务实施

## 验收标准

- [ ] 方向 A（Isolate）：查明 `ParagraphBuilder` 能否在 isolate 中使用，给出原型方案或否决理由
- [ ] 方向 B（缓存）：设计 PackedPage 序列化方案，评估 sled 读/写耗时
- [ ] 方向 C（不做的条件）：给出量化阈值（"当前大章 < X ms" → 不做）
- [ ] 推荐结论：Go / No-go for each, 含优先级排序
