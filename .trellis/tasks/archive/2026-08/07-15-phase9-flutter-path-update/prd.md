# Phase 9-B：Flutter import 路径修复 — 匹配 FRB 生成结构

## Goal

Rust 侧已完成大规模目录迁移（api/*→ domain/*/service.rs），FRB codegen 已重新生成 Dart 绑定代码。但 Flutter 侧 import 路径被手动修改为不存在的路径（如 `library/`, `reader/`, `profile/`, `language/`, `search/` 等子目录下的文件），导致编译失败。

本任务将 Flutter 侧所有 `src/rust/` 的 import 路径修正为与实际 FRB 生成文件匹配的正确路径。

## 背景

### 当前错误的 import 路径（Flutter 工作目录中的修改）

| 错误路径 | 出现次数 |
| --------- | --------- |
| `library/models.dart` | 79 |
| `reader/content_ir.dart` | 18 |
| `library/book_api.dart` | 11 |
| `profile/note_api.dart` | 5 |
| `reader/rich_text.dart` | 4 |
| `reader/reader_api.dart` | 4 |
| `reader/pagination.dart` | 4 |
| `profile/vocab_api.dart` | 4 |
| `language/bilingual_api.dart` | 4 |
| `search/api.dart` | 3 |
| `profile/stats_api.dart` | 3 |
| `language/dictionary_api.dart` | 3 |
| `infra/backup.dart` | 3 |
| `reader/session.dart` | 2 |
| `reader/progress.dart` | 2 |
| `reader/bookmark.dart` | 2 |
| `library/category_api.dart` | 2 |
| `library/import_api.dart` | 1 |
| `library/epub_api.dart` | 1 |
| `library/cover_api.dart` | 1 |
| `library/chapter_api.dart` | 1 |
| `language/vocab_scanner.dart` | 1 |
| `language/models.dart` | 1 |
| `common/error.dart` | 1 |

### 实际的 FRB 生成文件结构

```
lib/src/rust/
  api/*.dart                    — FRB 薄封装 API 函数
  common/*.dart                 — 共享类型（error, security）
  domain/*/models.dart          — 领域模型（按领域拆分）
  infra/init.dart               — 初始化
  parser/epub/metadata.dart     — EPub 元数据
  pipeline/types.dart           — IR/流水线类型
```

### 正确的映射规则

| 错误路径 | 正确路径 | 说明 |
| --------- | --------- | ------ |
| `library/book_api.dart` | `api/book.dart` | 书籍 API 函数 |
| `library/category_api.dart` | `api/category.dart` | 分类 API 函数 |
| `library/import_api.dart` | `api/book.dart` | 导入函数在 book.dart 中 |
| `library/epub_api.dart` | `api/book.dart` | EPUB 元数据在 book.dart 中 |
| `library/cover_api.dart` | `api/cover.dart` | 封面 API 函数 |
| `library/chapter_api.dart` | `api/chapter.dart` | 章节 API 函数 |
| `library/models.dart` | `domain/*/models.dart` | 按使用的类型替换为对应的领域模型 |
| `reader/reader_api.dart` | `api/reader.dart` | 阅读器 API 函数 |
| `reader/pagination.dart` | `api/reader.dart` | 分页函数在 reader.dart 中 |
| `reader/content_ir.dart` | `pipeline/types.dart` | IR 类型定义 |
| `reader/rich_text.dart` | `pipeline/types.dart` | RichTextSpan 等类型 |
| `reader/session.dart` | `api/session.dart` | 阅读会话 API |
| `reader/progress.dart` | `api/progress.dart` | 阅读进度 API |
| `reader/bookmark.dart` | `api/bookmark.dart` | 书签 API |
| `profile/note_api.dart` | `api/note.dart` | 笔记 API |
| `profile/vocab_api.dart` | `api/vocab.dart` | 生词 API |
| `profile/stats_api.dart` | `api/stats.dart` | 统计 API |
| `language/bilingual_api.dart` | `api/bilingual.dart` | 双语 API |
| `language/dictionary_api.dart` | `api/dictionary.dart` | 词典 API |
| `language/vocab_scanner.dart` | `api/vocab.dart` | 生词扫描函数在 vocab.dart 中（需确保 FRB codegen 包含 wordlist） |
| `language/models.dart` | `domain/dictionary/models.dart` 或 `domain/bilingual/models.dart` | 按使用类型 |
| `search/api.dart` | `api/search.dart` | 搜索 API |
| `infra/backup.dart` | `api/backup.dart` | 备份 API |
| `common/error.dart` | `common/error.dart` | ✅ 已正确 |

## 验收标准

- [ ] `flutter_rust_bridge.yaml` 新增 `crate::domain::wordlist` 配置项
- [ ] FRB codegen 重新生成后 `lib/src/rust/` 包含 wordlist API 函数
- [ ] 所有 Flutter 文件中的 `src/rust/` import 路径指向正确的生成文件
- [ ] 79 处 `library/models.dart` 被替换为领域特定的模型导入
- [ ] `flutter analyze --fatal-infos` 零错误
- [ ] `cargo clippy -- -D warnings` 零告警
