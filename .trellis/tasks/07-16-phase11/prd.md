# Phase 11 — 收尾 Phase 9/10 余留 + Rust 后端重构

## Goal

两阶段：

### 阶段 A：Flutter 架构收尾

Phase 9/10 IR 大重构后 Flutter 侧的 4 项架构余留问题清理。

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | **engine config 迁移** | 将 `features/reader/domain/config/` 下的 `ReaderConfig`、`ReaderTypographyDefaults`、`ReadingModeUtils`、`LanguageType` 迁至 `reader_engine/shared/config/`，消除 `reader_engine` → `features/reader` 反向依赖（17 条 import） |
| 2 | **`ChapterContentRepository` 放回 data 层** | 刚合并的类现在 `domain/` 下但实际是数据访问类，移回 `data/repositories/`，更新 20 个文件的 import 路径 |
| 3 | **`ReaderRenderDataSource` 删除** | 纯委托适配器，全部方法都是 `_session.xxx` / `_content.xxx`，直接内联到消费者 |
| 4 | **`PaginationSession` 生命周期统一** | 目前被 4 处持有（create/session/dataSource/engine），统一到 `PaginationEngine` |

### 阶段 B：Rust 后端重构

- **方向 A（业务下沉）**：识别 `domain/*/service.rs` 中纯 SQL 搬运的 service，将逻辑合并到对应 repo
- **方向 B（API 聚合）**：识别 Flutter 侧需多次调用的关联 API，合并为单一函数

## 验收标准

- [ ] `flutter analyze --fatal-infos lib/` 零错误
- [ ] `cargo clippy -- -D warnings` 零告警
- [ ] `reader_engine/` 不再 import `features/reader/` 下的任何文件
- [ ] `ChapterContentRepository` 在 `data/` 下
- [ ] `ReaderRenderDataSource` 已删除（不再有纯委托类）
- [ ] `PaginationSession` 生命周期由 `PaginationEngine` 统一管理
- [ ] Rust service 层已扫描（有扫描结果记录）
