# API 薄封装化 — 实施计划

## 执行顺序

按风险从低到高：先修 C 组（无风险注释），再 A 组（活跃但有已知方向），最后 B 组（需逐一评估）。

### Step 1: 🔧 C 组 — 修复 mod.rs 复制粘贴注释 (5 min)

文件：

- `domain/library/book/mod.rs`
- `domain/library/category/mod.rs`
- `domain/library/chapter/mod.rs`
- `domain/library/cover/mod.rs`

Fix：改注释为对应领域；确保 `pub mod service;` 对应文件存在（若无则创建空骨架）。

### Step 2: 🎯 A 组 — `api/session.rs` 瘦身 (20 min)

1. 创建 `domain/reader/sessions/service.rs`
   - 导入现有 `SessionRepository` + `ReadingSession`
   - 薄封装：`list_sessions_by_book()`, `list_sessions_by_date_range()`, `list_sessions_by_recent()`, `create_session()`, `upsert_session()`, `clear_sessions_by_book()`
   - 日期转换逻辑从 api 迁入 service
2. 重写 `api/session.rs`：删 SQL/Repo，调 service
3. 更新 `domain/reader/sessions/mod.rs` 加 `pub mod service;`

### Step 3: 🎯 A 组 — `api/bookmark.rs` 瘦身 (15 min)

1. 创建 `domain/reader/bookmark/service.rs`
   - 导入现有 `BookmarkRepository` + `Bookmark`
   - 封装所有方法
2. 重写 `api/bookmark.rs`：删 SQL/Repo，调 service
3. 更新 `domain/reader/bookmark/mod.rs` 加 `pub mod service;`

### Step 4: 🏗️ B 组 — `api/book.rs` 唤醒 + 瘦身 (30 min)

1. 创建 `domain/library/book/service.rs`
   - `get_book_detail()` — 多 Repo 聚合逻辑
   - `delete_book()` — 文件删除+缓存失效+搜索索引清理
   - `create_web_book()` — Book 构造逻辑
   - `parse_book()` — 验证链+解析路由
   - `batch_update_book_status()` — 循环+事务
   - 其他薄函数直接委托 repo
2. 重写 `api/book.rs`：仅留 FRB 注解和 delegation
3. 添加 `api/mod.rs`：`pub mod book;`

### Step 5: 🏗️ B 组 — `api/note.rs` 唤醒 + 瘦身 (20 min)

1. 创建 `domain/profile/note/service.rs`
   - 导出渲染函数（render_txt/markdown/html）
   - HTML 模板
   - 笔记统计
2. 重写 `api/note.rs`：仅留 FRB 注解和 delegation

### Step 6: 🏗️ B 组 — 其余死代码文件处理 (20 min each)

按 `api/category.rs` → `api/chapter.rs` → `api/cover.rs` → `api/progress.rs` → `api/bilingual.rs` → `api/dictionary.rs` → `api/vocab.rs` → `api/stats.rs` → `api/reader.rs` 顺序：

1. 若目标 domain service 不存在则创建
2. 提取业务逻辑
3. 重写 api 为薄封装
4. 在 `api/mod.rs` 中 export

### Step 7: ✅ 验证

- `cargo clippy -- -D warnings` 零告警
- FRB codegen 重新生成
- Dart 侧 `flutter analyze --fatal-infos`
- Flutter 全测试

## 回滚点

每完成一个 Step 可独立 commit：

```
git add -A && git commit -m "refactor(api): slim <filename> — move biz logic to domain/<domain>/service"
```
