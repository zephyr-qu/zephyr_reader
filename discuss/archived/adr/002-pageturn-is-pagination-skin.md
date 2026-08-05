# ADR-002：pageTurn 合并为 pagination 的皮肤

- **状态**：已接受 · **已实现**（Phase 1 退出 @ `527354d`）
- **日期**：2026-06-18

## 决策

- 删除「pageTurn 独立模式」概念；UI 上保留卷曲交互，底层与 **pagination** 共用 `PaginationView` + `PageStreamer` + 同一 orchestrator 加载链。
- **`ReadingMode.pageTurn` 枚举已移除**；卷曲 vs 滑动由 **`PaginationSkin`** 表达，持久化于 `ReaderConfig.paginationSkin`（`SettingsKeys.readerPaginationSkin`）。
- 设置面板仍展示 4 项（滚动 / 卷曲 / 左右分页 / 双语），其中「卷曲」= `ReadingMode.pagination` + `PaginationSkin.curl`。

## 理由

- 问卷：仿真翻页为 Should，合并进 pagination 为显式选择。
- 减少 `ReaderContent` 早退分支与重复 pageBuilder；消除「独立模式」与「同一 Rust session」之间的语义冲突（R4-3 / appendix04 风险 B）。

## 实现（Phase 1）

| 层 | 落点 |
|----|------|
| 类型 | `lib/features/reader/domain/config/reading_mode_utils.dart` — `PaginationSkin { slide, curl }`；`usesPageCurlSkin()` / `needsRustPagination()` |
| 配置 | `ReaderConfig.paginationSkin`（默认 `slide`）；`ReadingMode` 仅 `scroll \| pagination \| bilingual` |
| UI | `TypesettingPanel` — 四选一同时写 `readingMode` + `paginationSkin` |
| 渲染 | `PaginatedModeRenderer` + `PageTurnShell` — 按 `paginationSkin` 选 `PageCurlWidget` 或 `PageView` slide |
| 交互 | `ReaderInteractionLayer` — `usesPageCurlSkin()` 决定 tap 布局 |
| Intent | pagination 与 curl **共用** `configReload` / `normalLoad`（R4-4）；无 pageTurn 专用 intent |

## 后果

- **配置迁移**：旧版若曾持久化 `ReadingMode.pageTurn`，需一次性映射为 `pagination` + `curl`（当前 simplify 分支未保留兼容层；新安装无影响）。
- **术语**：文档 / glossary 中的「pageTurn」指 **curl 皮肤**，不是独立 `ReadingMode`。
- **测试**：widget 测试以 `paginationSkin: PaginationSkin.curl` 覆盖原 pageTurn 场景（`reader_content_test` 等）。

## 非目标（仍为后续）

- 不改变 staging 虚拟页协议（G2-b 已验收）。
- 不在 Phase 1 引入 IR / `BlockPaginator`（Phase 2）。

## 相关

- [PHASE1_EXIT.md](../PHASE1_EXIT.md) — 1.5、诚实债务 §PaginationSkin
- [INTENTS.md](../INTENTS.md) — pagination / curl 共用 orchestrator
- [xinxi-round4.md](../xinxi-round4.md) — R4-3、R4-4
