# Zephyr Reader — 领域词汇表

> 与边界讨论、ADR 共用。术语稳定后，代码与文档应对齐此处定义。  
> **最后更新**：2026-06-25（Phase 4 grilling）

| 术语 | 定义 | 非本项目的含义 |
|------|------|----------------|
| **ChapterDocument** | 单章阅读单元：含 `ContentBlock[]`（IR）与 `plainText` 投影。 | 不等于「分页结果」。 |
| **plainText** | 章节权威正文字符串；进度、书签、全书搜索、TTS 的锚点。EPUB 分段见 ADR-007。IR 图片占位 `\uFFFC`（ADR-008）。 | 不等于屏幕可见的富文本。 |
| **charOffset** | 在 `plainText` 内的字符索引；与 `chapterIndex` 组成 **ReadingPosition**。 | EPUB 下不是 spine index。 |
| **ReadingPosition** | `{ chapterIndex, charOffset }`；持久化进度、书签、笔记锚点。 | 不等于 `pageIndex`。 |
| **PaginationView** | 对 IR/`plainText` 的派生视图：`descriptors` + `pageIndex`；pagination / pageTurn 使用。 | 不是第二套正文。 |
| **ScrollView** | 对 IR 的连续流派生：多章 `ScrollChapterSegment` + scrollOffset → charOffset。 | 不是全书 global offset 重构。 |
| **rich** | `RichParagraph[]` + 可选 `TextSpan`；**过渡**路径，Phase 4 由 IR 替代 scroll 主路径。 | 分页不依赖 rich 输入。 |
| **pageTurn** | pagination 的交互皮肤（卷曲动画），不是独立加载路径。 | 见 ADR-002。 |
| **bilingual** | 中英对照；**独立 feature 模块**（ADR-011），非主加载链。 | 不是第五套解析引擎。 |
| **staging** | 相邻章首/末页预加载（ADR-004）；**必须命中、零可见 loading**（ADR-012）。 | 不是章节内容真理源。 |
| **ContentBlock / IR** | Rust 统一中间表示：Text / Image / … per chapter（ADR-003）。scroll + pagination 渲染输入。 | 不是 plainText 替代品（进度仍用 plain）。 |
| **BlockPaginator** | 对 IR 按视口切页的引擎；Phase 2 MVP 已完成，替代 plain-only PageStreamer（含图章）。 | 不是 Dart 分页。 |
| **firstSpine** | 首屏约 2000 字的 partial 文本；仅用于快速出页，不能当 `plainText` 全文。 | 见 ADR-003。 |
| **epubRichSkipped** | 大章 plain 降级 + 用户提示；Phase 4 目标通过 scroll→IR 消除。 | 不是静默失败。 |
| **版式像原书（窄义）** | font-family、text-indent、段间距、行高、基础强调、图片位；不含多栏/float/复杂表格（ADR-010）。 | 不是出版级 CSS 引擎。 |
| **Won't** | 项目明确不做的能力；新需求先查 [READING_BOUNDARIES.md](./READING_BOUNDARIES.md)。 | 不是「以后再说」。 |
