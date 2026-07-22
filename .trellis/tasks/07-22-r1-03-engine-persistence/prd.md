# R3: 引擎位置持久化

## Goal

新增 `reading_engine_positions` 表存储引擎私有恢复信息（Readium Locator），与逻辑 `ReadingPosition` 分离持久化。职责清晰分离。

## Requirements

### 数据库

- 新建表 `reading_engine_positions (book_id TEXT PK, engine_kind TEXT, publication_fingerprint TEXT, opaque_position TEXT, updated_at INTEGER)`
- 新增 migration
- 新增 FRB API: `getEnginePositionHint(bookId)` / `saveEnginePositionHint(hint)` / `deleteEnginePositionHint(bookId)`

### Dart 仓库

- `EnginePositionHintRepository`：封装 FRB 调用
- `ProgressRepository` 不触及 engine hint 表

### 行为契约

- 老用户进度无需迁移即可读取
- 没有 Locator 时可以正常打开（降级逻辑）
- Locator 损坏时显式丢弃，不影响正常阅读
- 文件 fingerprint 变化时 Locator 失效
- Builtin 不读取 Readium Locator

## Acceptance Criteria

- [ ] 表定义 + migration 完成
- [ ] FRB API 可用
- [ ] EnginePositionHintRepository 实现
- [ ] 降级/失效路径覆盖
- [ ] 检查点：`feat: persist engine-specific reading position hints`
