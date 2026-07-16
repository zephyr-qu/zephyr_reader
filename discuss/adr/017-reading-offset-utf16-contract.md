# ADR-017：阅读坐标统一为 UTF-16 code-unit offset

- **状态**：已接受（Phase 13 P0，2026-07-16）
- **日期**：2026-07-16
- **背景**：[ADR-001](./001-reading-position-truth.md) 将 `charOffset` 定为进度真理，但未规定跨语言编码单位；Rust 曾按 Unicode scalar 计数，Flutter 的 `String`、`TextSelection` 与 `TextPainter` 按 UTF-16 code unit 计数。

## 决策

1. `plainText` 的所有跨层坐标统一为 **UTF-16 code-unit offset**，使用半开区间 `[start, end)`。
2. 适用范围包括 IR `plain_start/plain_len`、分页 descriptor、滚动位置、进度、书签、笔记、高亮、会话和搜索结果。
3. `\uFFFC` 图片占位符占 1 个 UTF-16 code unit；换行符按实际 `plainText` 内容计数。
4. offset 不采用 grapheme cluster：组合字符可能占多个 code unit，但选择范围不得落在代理对中间。
5. Rust 负责在生成 IR 时计算 UTF-16 长度，并在按范围切片时拒绝越界或代理对中间位置；Flutter 可直接使用 Dart `String.substring` 和 `TextSelection` 的 offset。
6. IR 磁盘缓存版本提升；旧 Unicode-scalar IR 缓存视为 miss 并重新解析。搜索索引记录独立的 offset version，版本变化时清空派生索引并等待正常索引流程重建。

## 迁移判断

现有进度、书签和笔记由 Flutter 的 selection、分页 descriptor 与 scroll mapper 产生，再由 Rust API 原样持久化。因此数据库中的既有位置按 UTF-16 解释，不做无依据的批量重写。若未来发现旧版本存在 Rust 主动生成并持久化的 scalar offset，必须增加带来源版本的显式迁移，禁止猜测转换。

## 理由

- Flutter 是精确排版、选择和渲染执行端，其原生坐标就是 UTF-16。
- 若继续使用 Rust scalar offset，emoji 等非 BMP 字符之后的分页、划线和恢复位置会漂移。
- 在 Flutter 热路径转换 scalar offset 会增加复杂度，并产生新的双坐标真理。

## 验收

- Rust 契约测试覆盖 ASCII、CJK、emoji、组合字符、换行与 `\uFFFC`。
- Flutter 使用 Rust IR descriptor 对 `plainText.substring(start, end)` 切片时不越界、不拆代理对。
- scroll 与 pagination 切换、书签和高亮恢复到相同文本。

## 关联

- [ADR-001](./001-reading-position-truth.md)
- [ADR-007](./007-plaintext-segmentation-stability.md)
- [ADR-008](./008-ir-image-plain-placeholder.md)
- [DOMAIN_MODEL.md](../DOMAIN_MODEL.md)
