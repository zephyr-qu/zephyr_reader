# ADR-013：分页字宽 — Rust 初筛 + Flutter Metrics 回传校准

- **状态**：Superseded by [ADR-016](016-flutter-pagination-engine-proposed.md)（Flutter 精确装箱取代 Rust+校准回传环）
- **日期**：2026-06-25

## 决策

1. **保留** Rust `CharWidthTable` 做快速、粗粒度分页预计算（性能）。
2. **新增** Flutter 首屏（及 config 变更后）通过 `TextPainter` 采集实际字宽/行高，**回传 Rust** 微调后续页 `PageDescriptor` 切分，并更新 sled layout 缓存。
3. **Lazy 模式标点挤压**：维持 **by design 跳过**（D9a）；不在 Phase 4 引入完整 CJK 标点引擎。
4. **Rust 分页任务取消**：Phase 4 **仍不做**；Dart `_generation` 防写回足够（D9c）。

## 理由

- CharWidthTable 与 Skia/Impeller 真实 glyph 存在**结构性漂移**，纯 Rust 无法消除末行多/少一字。
- 混合精度：Rust 速度 + Flutter 渲染真理，通信成本低于重写排版引擎。
- 标点挤压与 CancellationToken 收益低于复杂度（R4-6 结论延续）。

## 后果

- **接受**：FRB 新增 metrics 回传 API；`repaginateInPlace` 在 metrics 变更时触发校准路径。
- **拒绝**：Phase 4 引入 harfbuzz 级 CJK 引擎或 FRB CancellationToken。
- **文档**：README/边界注明「非专业出版级排版引擎」。

## 关联

- [PHASE4_SCOPE.md](../PHASE4_SCOPE.md) P4-4
- [issue/CORE_READING_CHAIN_STATUS.md](../../issue/CORE_READING_CHAIN_STATUS.md) §3.2 lazy 标点
