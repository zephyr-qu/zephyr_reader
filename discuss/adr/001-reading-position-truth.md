# ADR-001：阅读进度以 plainText + charOffset 为唯一真理

- **状态**：**已接受**（2026-06-18，R3-1 确认）
- **日期**：2026-06-18
- **背景**：第一轮 §5.1 未勾选；第二轮 G3 要求「讲解后再定」。

## 决策

1. 持久化进度、书签、笔记锚点 = **ReadingPosition** `{ chapterIndex, charOffset }`。
2. `charOffset` 是章节 **plainText** 内的字符索引（从 0 起）。
3. `pageIndex` **不写入数据库**；由 `charOffset` + 当前分页 descriptors 每次推算。

## 通俗解释（给 G3）

| 概念 | 是什么 | 举例 |
|------|--------|------|
| **plainText** | 一章的「纯文字串」，书签/TTS/搜索都认它 | 去掉 HTML 标签后的正文；图在 rich 里，plain 里可能有占位或跳过 |
| **charOffset** | 读到第几个字符 | 第 5000 个字 ≈ 书签位置 |
| **pageIndex** | 当前是第几**页** | 改字号后同一 charOffset 可能变成第 8 页或第 10 页 → **所以不能只存页码** |

**若采纳**：换字体后书签仍准确到句；scroll 与 pagination 可互跳（页码可能差几页，你已接受）。  
**若不采纳**：就要同时存 pageIndex + charOffset + 排版 hash，复杂度更高，不符合 G8-d。

## 与 G1-b（块分页）的关系

块分页落地后，plainText 仍保留（搜索/TTS）；每页渲染用 **ContentBlock 引用**，charOffset 仍映射到 plain 坐标。IR 是渲染输入，不是进度真理。图片块在 plain 中占 **一个 `\uFFFC`**（[ADR-008](./008-ir-image-plain-placeholder.md)）。

## 后果

- Orchestrator 不得长期用 firstSpine 2000 字充当全书 `chapterContent`。
- TTS/搜索在 **全文 plain ready** 后运行。

## 关联

- [glossary.md](../glossary.md)
- [READING_BOUNDARIES.md](../READING_BOUNDARIES.md)
