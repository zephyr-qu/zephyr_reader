# Test fixtures（本地，不入库）

`test/fixtures/*` 二进制文件被 `.gitignore` 忽略；克隆后需自行放入。

## EPUB（ADR-007 / 阅读链集成测试）

| 文件 | 用途 | 引用方 |
|------|------|--------|
| `medium.epub` | 中等体量 EPUB；分页 session、repaginate、oversized 衍生 | `epub_reading_chain_test.rs`、`provider.rs` 单测 |
| `活着.epub` | 复杂多章 EPUB；**黄金样章** ch.0 plain 含「自序」 | `epub_reading_chain_test.rs`、`core_pagination_test.dart` |

缺失时相关测试 **SKIP**（`require_fixture`），不导致 CI 硬失败。

## TXT

| 文件 | 用途 |
|------|------|
| `small.txt` / `large.txt` | 分页、解析基准 |
| `活着.txt` | 与 EPUB 对照 |
| `pure_cjk.txt` / `mixed_cjk_latin.txt` | 断行/混排 |

## 验收命令

```bash
# Rust plain + EPUB 链（需本地 fixture）
cargo test --lib parser::epub::provider::tests
cargo test --test epub_reading_chain_test
```

核对记录见 [discuss/adr/007-epub-golden-verification.md](../../discuss/adr/007-epub-golden-verification.md)。
