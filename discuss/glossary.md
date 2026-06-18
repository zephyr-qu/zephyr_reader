# Zephyr Reader — 领域词汇表

> 与边界讨论、ADR 共用。术语稳定后，代码与文档应对齐此处定义。

| 术语 | 定义 | 非本项目的含义 |
|------|------|----------------|
| **ChapterDocument** | 单章阅读单元：至少含 `plainText`；scroll/bilingual 可附加 `richParagraphs`。 | 不等于「分页结果」。 |
| **plainText** | 章节权威正文字符串；进度、书签、搜索、TTS、Rust 分页的输入。 | 不等于屏幕可见的富文本。 |
| **charOffset** | 在 `plainText` 内的字符索引；与 `chapterIndex` 组成 **ReadingPosition**。 | EPUB 下不是 spine index。 |
| **ReadingPosition** | `{ chapterIndex, charOffset }`；持久化进度、书签、笔记锚点。 | 不等于 `pageIndex`。 |
| **PaginationView** | 对 `plainText` 的派生视图：`descriptors` + `pageIndex`；仅 pagination / pageTurn 使用。 | 不是第二套正文。 |
| **rich** | `RichParagraph[]` + 可选 `TextSpan`；scroll / bilingual 的展示增强。 | 分页模式 MVP 不依赖 rich 输入。 |
| **pageTurn** | pagination 的交互皮肤（卷曲动画），不是独立加载路径。 | 见 ADR-002。 |
| **bilingual** | 中英段落对照模式；共享 scroll 加载，额外翻译管线。 | 不是第五套解析引擎。 |
| **staging** | 相邻章首/末页预加载，用于换章时减少空白（ADR-004）。 | 不是章节内容真理源。 |
| **ContentBlock / IR** | Rust 统一中间表示：Text / Image / …  per chapter（ADR-003）。 | 不是 plainText 替代品（进度仍用 plain）。 |
| **BlockPaginator** | 对 IR 按视口切页的引擎；替代 plain-only PageStreamer 的目标组件。 | 未实现。 |
| **firstSpine** | 首屏约 2000 字的 partial 文本；仅用于快速出页，不能当 `plainText` 全文。 | 见 ADR-003。 |
| **epubRichSkipped** | 大章或失败时放弃 rich，降级 plain + 用户提示。 | 不是静默失败。 |
| **Won't** | 项目明确不做的能力；新需求先查 [READING_BOUNDARIES.md](./READING_BOUNDARIES.md)。 | 不是「以后再说」。 |
