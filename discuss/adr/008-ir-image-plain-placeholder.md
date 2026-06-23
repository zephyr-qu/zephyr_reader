# ADR-008：IR 图片块在 plainText 中的坐标表示

- **状态**：已接受（Phase 2 M0.4，2026-06-18）
- **日期**：2026-06-18
- **背景**：[ADR-001](./001-reading-position-truth.md) 要求进度/书签/搜索锚定在 `plainText` 的 `charOffset`；[ADR-003](./003-block-pagination-ir.md) 引入 `ContentBlock::Image`。需定 IR 图片块如何投影到 plain，以便块分页、`charOffset → pageIndex`、S3 书签恢复一致。

## 选项回顾

| 选项 | plain 行为 | 主要问题 |
|------|------------|----------|
| **A** 跳过 | `<img>` 不占字符 | 图片独占页无法分配唯一 `charOffset`；连续多图共址；S3 在图页恢复模糊 |
| **B** 占位符 | 每图 **1 个** `\uFFFC`（OBJECT REPLACEMENT） | 搜索/TTS 需约定处理占位符 |
| **C** alt 文本 | plain 写入 `alt` 字符串 | `alt` 长短/变更会漂移 offset，与 [ADR-007](./007-plaintext-segmentation-stability.md) 精神冲突 |

## 决策

**采用 B：每个 `ContentBlock::Image` 在 plain 投影中占 exactly 1 个 `\uFFFC`。**

1. **投影规则**（EPUB/TXT → IR 时同步生成 plain）  
   - `Text` 块：按 ADR-007 现有规则写入 plain（块级单 `\n` 等）。  
   - `Image` 块：在 DOM/IR 顺序对应位置 append **一个** `\uFFFC`。  
   - 每个 `Image` 块记录 `plain_start`（UTF-8 字节偏移或 Rust char index，与现有 `charOffset` 语义一致）且 **`plain_len = 1`**。

2. **进度与分页**  
   - 书签/笔记/持久化进度：仍只存 `{ chapterIndex, charOffset }`（ADR-001）。  
   - 用户停在图片页：`charOffset` 指向该图的 `\uFFFC` 位置。  
   - `BlockPaginator` / descriptor：`plain_start..plain_start+1` 映射到含该 Image 块的页。

3. **TTS**  
   - 读到 `\uFFFC` 时 **不朗读占位符**；按 `plain_start` 查 IR 中对应 `Image` 块，若有非空 `alt` 则朗读 `alt`，否则跳过。

4. **搜索**  
   - 默认章内搜索 **忽略** `\uFFFC`（不参与 token 匹配）；不在 plain 中嵌入 alt（alt 仅在 IR）。

5. **与现状过渡**  
   - Phase 1 路径 `html_to_plain_text` 仍 **跳过** `<img>`（行为 A），直至 IR 管线替代 plain 来源。  
   - Phase 2 起，pagination 用的 plain **必须**来自 **IR 投影**（含 `\uFFFC`），不得与旧 plain 混用同一章的两个版本。

## 理由

- **S3**：插图页、独占页需要稳定、可区分的 `charOffset`；A 做不到，C 随 alt 变化。  
- **ADR-001 / ADR-007**：坐标稳定优先于「plain 可读性」；图片语义在 IR，`plain` 只负责 **坐标系**。  
- **行业惯例**：`\uFFFC` 常用于「内联对象占位」；长度固定便于 offset 算术。  
- **C 否决**：空 alt、多语言 alt、出版社再加工 EPUB 会导致书签漂移。

## 后果

- `ContentBlock::Image` 必须带 `plain_start`（及可选 `plain_len: 1` 不变量）。  
- 搜索/TTS 模块需识别 `\uFFFC`（小改，非第二套进度模型）。  
- 黄金测试：含 `<img>` 的 HTML fixture 断言 plain 中 `\uFFFC` 个数 = Image 块个数。  
- scroll + rich 路径不变；scroll 进度若仍绑 plain，换章后可能与 pagination plain（含占位）长度差 1×图数——**模式切换**时以当前模式 plain 为准（Phase 2 文档化，不混存）。

## 关联

- [ADR-001](./001-reading-position-truth.md) — charOffset 真理  
- [ADR-003](./003-block-pagination-ir.md) — IR + 块分页  
- [ADR-007](./007-plaintext-segmentation-stability.md) — 文本段 `\n` 规则不变  
- [PHASE2_EXIT.md](../PHASE2_EXIT.md) — M0.4、M1.3
