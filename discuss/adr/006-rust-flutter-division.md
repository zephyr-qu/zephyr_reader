# ADR-006：Rust / Flutter 职责划分

- **状态**：已接受（R3-2，2026-06-18）
- **日期**：2026-06-18
- **关联**：[TARGET_ARCHITECTURE.md](../TARGET_ARCHITECTURE.md)、appendix01

## 决策

| 层 | 负责 | 不负责 |
|----|------|--------|
| **Rust** | 解析 EPUB/TXT → **IR (ContentBlock[])**；块分页；`config_hash` 缓存；图片处理与路径 | UI 状态、动画、Widget 树 |
| **Flutter** | 视口/DPI/排版设置；signals；按页请求块；Text/Image 渲染；**staging 触发** | 全书分页算法、HTML 解析 |

## 理由

- 第三轮确认采纳 appendix01「Heavy Logic in Rust, Reactive UI in Flutter」。
- 与 ADR-003（块分页）、ADR-004（staging 在 Flutter 侧触发预取）一致。
- 避免 Phase 2 再在 Dart 重写分页测量。

## 后果

- 新分页/解析能力默认在 `rust/src/` 落地，经 FRB 暴露。
- Flutter `ChapterLoadOrchestrator` 逐步瘦身为「调 Rust + 写 signals」，不新增 Dart 分页引擎。
- Phase 1 仍可使用现有 `PageStreamer`，作为向 IR 演进的过渡，不推翻 Rust 分工。

## 演进注意

- IR 与现有 `RichParagraph` / `PageStreamer` **并存过渡期**允许；终态以 IR + BlockPaginator 为准（ROADMAP Phase 2）。
