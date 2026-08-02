# Phase 9-A：API 层薄封装化 — 业务逻辑下迁至 domain/service.rs

## Goal

将 `rust/src/api/*.rs` 文件重构为薄 FRB 封装层，业务逻辑下迁至对应的 `domain/<domain>/service.rs` 文件。API 层只负责：

- `#[frb]` 注解
- 入参解包（parse/validate）
- 委托给 domain service
- 结果转换/包装

## Scope

15 个 `api/*.rs` 文件按状态分组：

### A — 当前活跃（在 `api/mod.rs` 中导出，需瘦身）

| File | Lines | 问题 |
| ------ | ------- | ------ |
| `session.rs` | 161 | Repo SQL + API 混在同一文件，`SQL_UPSERT_SESSION` 和 `SessionRepository` 内联 |
| `bookmark.rs` | 188 | 同上，SQL 和 Repo 实体内联在 api/ 中 |
| `backup.rs` | 36 | 已是薄封装 ✅（委托 `domain/backup/service.rs`） |
| `search.rs` | 107 | 已是薄封装 ✅（委托 `domain/search/engine.rs`） |

### B — 死代码（不在 `api/mod.rs` 中导出，需评估清理或唤醒）

| File | Lines | 问题 |
| ------ | ------- | ------ |
| `book.rs` | 593 | 大量业务逻辑（BookDetail 聚合、parse_book 验证链、delete 级联+缓存失效、create_web_book 构造逻辑） |
| `note.rs` | 472 | 笔记 CRUD + 导出渲染（render_txt/markdown/html）+ HTML 模板 |
| `category.rs` | 231 | 分类 CRUD + 书籍分配逻辑 |
| `bilingual.rs` | 264 | 双语对齐+高亮配对逻辑 |
| `dictionary.rs` | 215 | 词典查询、模糊搜索、分词 |
| `chapter.rs` | 77 | 较薄，主要是查+存 |
| `cover.rs` | 122 | 封面提取路由逻辑 |
| `progress.rs` | 28 | 很薄 |
| `reader.rs` | 74 | 混合 |
| `stats.rs` | 102 | 统计聚合逻辑 |
| `vocab.rs` | 152 | 生词 CRUD + 状态管理 |

### C — 修复复制粘贴错误

`domain/library/{book,category,chapter,cover}/mod.rs` 注释写着 "数据备份与还原领域"（从 backup 复制粘贴）。

## 验收标准

- [ ] `api/session.rs` 不再包含 Repo SQL/实现 → 迁至 `domain/reader/sessions/service.rs`
- [ ] `api/bookmark.rs` 不再包含 Repo SQL/实现 → 迁至 `domain/reader/bookmark/service.rs`
- [ ] `api/book.rs` 唤醒并瘦身：业务逻辑迁至 `domain/library/book/service.rs`，API 只留薄封装
- [ ] `api/note.rs` 业务逻辑（导出渲染等）迁至 `domain/profile/note/service.rs`
- [ ] 其他 B 组死代码文件逐一评估：或唤醒瘦身，或删除（若功能已由 domain 替代）
- [ ] C 组 mod.rs 注释修复
- [ ] `cargo clippy -- -D warnings` 零告警
- [ ] FRB codegen 重新生成后 Dart 侧编译通过
