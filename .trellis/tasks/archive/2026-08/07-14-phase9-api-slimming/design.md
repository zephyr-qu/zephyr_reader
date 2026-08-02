# API 薄封装化 — 技术设计

## 1. 目标模式

### 当前（坏的）

```rust
// api/session.rs
const SQL_UPSERT_SESSION: &str = "...";
#[frb(opaque)]
pub struct SessionRepository;   // Repo 实体内联在 api/ 中
impl SessionRepository { ... }  // SQL 实现

#[frb] pub async fn create_session(...) { ... }  // 直接调 Repo
```

### 目标（好的）— 参考 `api/search.rs` + `domain/backup/service.rs`

```rust
// api/session.rs — 仅薄封装
use crate::domain::reader::sessions::*;

#[frb] pub async fn create_session(...) -> Result<ReadingSession, AppError> {
    service::create_session(...).await
}

// domain/reader/sessions/service.rs — 业务逻辑
pub async fn create_session(...) -> Result<ReadingSession, AppError> {
    // 验证、构造、调 repo
}
```

## 2. 分层契约

| 层 | 职责 | 允许的依赖 |
| ----- | --------- | --------- |
| `api/` | `#[frb]`、入参转换、委托 service | domain models, domain service |
| `domain/*/service.rs` | 业务规则、构造逻辑、编排、校验 | domain repos, domain models |
| `domain/*/*_repo.rs` | SQL 查询、DB Ops | domain models, sqlx |
| `domain/*/models.rs` | 数据类型、枚举 | serde, chrono, uuid |

**禁止**：

- `api/` 不能定义 `const SQL_*` 或 `#[frb(opaque)] pub struct XxxRepository`
- `service.rs` 不能包含 `#[frb]`（纯业务，不关心 FFI）
- `api/` 不能实现业务构造逻辑（如 `Book::new(...)` 参数拼接）

## 3. 映射表

### A 组 — 当前活跃

| api 文件 | 目标 domain service | 备注 |
| ---------- | ------------------- | ------ |
| `api/session.rs` | `domain/reader/sessions/service.rs` | 现有 `session_repo.rs` 保留为 repo，service 层作为中介 |
| `api/bookmark.rs` | `domain/reader/bookmark/service.rs` | 现有 `bookmark_repo.rs` 保留为 repo，service 层作为中介 |
| `api/backup.rs` | ✅ 已完成 — `domain/backup/service.rs` | 不动 |
| `api/search.rs` | ✅ 已完成 — `domain/search/engine.rs` | 不动 |

### B 组 — 死代码

| api 文件 | 目标 domain service | 处理方式 |
| ---------- | ------------------- | ---------- |
| `api/book.rs` | `domain/library/book/service.rs` | **唤醒**：部分函数已有 domain repo，但 `BookDetail` 聚合逻辑、`delete_book` 级联+缓存失效、`create_web_book` 构造、`parse_book` 验证链需要提取 |
| `api/note.rs` | `domain/profile/note/service.rs` | **唤醒**：导出渲染函数（render_txt/markdown/html）是纯业务逻辑 |
| `api/category.rs` | `domain/library/category/service.rs` | **唤醒**：大部分已是薄封装，但 `reorder_categories` 有事务逻辑 |
| `api/bilingual.rs` | `domain/language/` | **唤醒**：双语对齐存在 `domain/language/aligner.rs`，需确认 |
| `api/dictionary.rs` | `domain/language/` | **唤醒**：Mdict 查询、模糊搜索逻辑 |
| `api/chapter.rs` | `domain/library/chapter/service.rs` | **唤醒**：基本是薄封装，少量验证 |
| `api/cover.rs` | `domain/library/cover/service.rs` | **唤醒**：解析格式路由+处理逻辑 |
| `api/progress.rs` | `domain/reader/progress/service.rs` | **唤醒**：很薄 |
| `api/stats.rs` | `domain/profile/stats/service.rs` | **唤醒**：统计聚合逻辑 |
| `api/vocab.rs` | `domain/profile/vocabulary/service.rs` | **唤醒**：生词管理逻辑 |
| `api/reader.rs` | `domain/reader/` | **唤醒**：阅读引擎 API |

## 4. mod.rs 修复

| 文件 | 问题 | 修复 |
| ------ | ------ | ------ |
| `domain/library/book/mod.rs` | 注释 "数据备份与还原领域" | 改为 "书籍管理领域"；确认 `service.rs` 存在 |
| `domain/library/category/mod.rs` | 同上 | 改为 "分类管理领域" |
| `domain/library/chapter/mod.rs` | 同上 | 改为 "章节管理领域" |
| `domain/library/cover/mod.rs` | 同上 | 改为 "封面管理领域" |

## 5. 依赖与边界

- `api/` → `domain/*/service.rs` → `domain/*/*_repo.rs`
- 已有 infra 层依赖（`async_storage!`, `storage_pool()`）保留在 api 中或通过 service 参数传入
- `domain/reader/sessions/session_repo.rs` 已存在——service 包装之
- `domain/reader/bookmark/bookmark_repo.rs` 已存在——service 包装之
- `domain/profile/note/note_repo.rs` 已存在——service 包装之
