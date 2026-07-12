# Flutter侧分页实验 — 方案 2（Rust 出 IR）

## Goal

在分支 `explore/flutter-side-pagination` 做隔离实验：

- **Rust**：只输出章 IR（`ContentBlock[]` + `plainText`），不做页装箱 / pagination session / metrics 回传。
- **Flutter**：分页装箱 + 排版测量 + 渲染，全部用同一套 `TextPainter` 真理。

验证单侧真理能否消掉 overflow / 校准环；**默认不合并主线**。

## Background

| 项 | 说明 |
|----|------|
| 基线提交 | `d69c4df`（stage6 行高/buffer 修复已落在 `phase/stage6-line-width-calib`） |
| 契约选择 | **方案 2**：Rust 仍 `get_chapter_content_ir`；实验路径禁止分页 FFI |
| ADR | 实验刻意偏离 ADR-006/013；合并前必须新 ADR |
| Phase 5 | 不插队真机签退 |

## Requirements

- R1：feature flag（如 `flutterPaginationSpike`），默认关；关 = 现网 Rust 分页不变。
- R2：flag 开时：零 `create_pagination_session` / `paginate_chapter` / `apply_session_calibration` / `store_line_breaks`。
- R3：Flutter 对 IR 装箱 → 页描述符 → 复用/旁路现有块渲染；同页 overflow 诊断 `ok`（≤0.5dp）。
- R4：进度仍 `chapterIndex + charOffset`；实验内实现 `charOffset → pageIndex`。
- R5：首轮含 Text 块；Image 块至少不丢字（可先整页占位或延后）。
- R6：`design.md` + `implement.md` 可执行；spike 结束写 Go/No-Go。

## Acceptance Criteria

- [ ] AC1：flag 开，指定 TXT 章走 Flutter 分页，日志可证明无 Rust 分页 FFI。
- [ ] AC2：翻页无丢字/重字；诊断 `ok`。
- [ ] AC3：改字号重装箱后，charOffset 书签落在正确句附近。
- [ ] AC4：flag 关，烟测与 stage6 基线一致。
- [ ] AC5：文档结论：Go（开 ADR）/ No-Go（收工保留分支）/ Conditional（缺什么再 spike）。

## Out of Scope（首轮）

- staging / 跨章预取
- sled layout 分页缓存
- 双语、curl 皮肤打磨
- 删除 Rust `BlockPaginator`
- WebView / 完整 CSS（Won't）

## Decisions Locked

| # | 决策 |
|---|------|
| D1 | 方案 2：Rust 输出 IR，不算页 |
| D2 | 实验分支隔离，flag 门控 |
| D3 | 首轮 TXT 竖切优先，EPUB 图第二刀 |
