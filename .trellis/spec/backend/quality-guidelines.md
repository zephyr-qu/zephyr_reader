# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Common Mistakes

### `<span>` 内联容器吞没 `<img>`

**Symptom**: `<span><img src="..." /></span>` 中图片被静默丢失，不产生 `ImageBlock`。

**Cause**: `rich_text.rs` 中两个函数之间缺少图片检测协调：

1. `walk_inline_subtree()` 对 `"span"` arm 调 `collect_text_spans()`，但该函数无 `try_emit_image_paragraph` 调用。
2. `collect_text_spans()` 中 `"img" => {}` 是空分支 — 图片被吞没。

相比之下，`walk_paragraph_children()` 在顶层循环中调 `try_emit_image_paragraph`，所以 `<p><img/></p>` 正常。

**Fix**: 在 `collect_text_spans` 中增加 `<img>` 检测：遇到 `img` 元素时 flush 当前 spans 并 emit `RichParagraph::image_placeholder`。

```rust
// rich_text.rs — collect_text_spans 函数
"img" => {
    let src = get_attribute(attrs, "src").unwrap_or_default();
    let alt = get_attribute(attrs, "alt").unwrap_or_default();
    // flush existing text spans first, then emit image
    paragraphs.push(RichParagraph::image_placeholder(src, alt));
}
```

**Status**: Known — 未修复（Phase 5 bug bash 目标）。

**Related**: `walk_inline_subtree` 的 `try_emit_image_paragraph` 未覆盖通过 `collect_text_spans` 路径的子元素。

---

## Required Patterns

<!-- Patterns that must always be used -->

(To be filled by the team)

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
