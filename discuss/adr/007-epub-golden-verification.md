# ADR-007 EPUB 黄金样章核对记录

- **状态**：已核对（Phase 1 退出门禁）
- **日期**：2026-06-18
- **样章**：`test/fixtures/活着.epub`（本地 gitignore，~185 KB，多章）

## 核对项

| 项 | 结果 | 依据 |
|----|------|------|
| ch.0 全文 plain 可提取 | ✅ | `get_chapter(file, 0)` → `ChapterContent::Raw` |
| 字符量合理（>1000） | ✅ | `epub_golden_plain_chapter0_adr007` |
| 无 HTML 标签泄漏 | ✅ | `!text.contains('<')` |
| 人工标记「自序」存在 | ✅ | 与 Dart `core_pagination_test` 一致 |
| 无异常三连换行 | ✅ | `!text.contains("\n\n\n")` |
| 阅读链集成 | ✅ | `cargo test --test epub_reading_chain_test` **11/11** |

## 自动化门禁

```bash
cargo test --lib parser::epub::provider::tests   # html_to_plain_text 16 项
cargo test --test epub_reading_chain_test        # 含 epub_golden_plain_chapter0_adr007
```

Fixture 缺失时 EPUB 集成测试 SKIP；开发机放入 `活着.epub` / `medium.epub` 后全绿。

## 关联

- [ADR-007](./007-plaintext-segmentation-stability.md)
- [test/fixtures/README.md](../../test/fixtures/README.md)
- [PHASE1_EXIT.md](../PHASE1_EXIT.md)
