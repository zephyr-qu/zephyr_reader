# ADR-002：pageTurn 合并为 pagination 的皮肤

- **状态**：已接受（`xinxi.md` §2.2、§9）
- **日期**：2026-06-18

## 决策

- 删除「pageTurn 独立模式」概念；UI 上保留卷曲交互，底层与 **pagination** 共用 `PaginationView` + `PageStreamer`。
- `ReadingMode` 可保留 `pageTurn` 枚举值作偏好，但加载路径与 `pagination` 相同。

## 理由

- 问卷：仿真翻页为 Should，合并进 pagination 为显式选择。
- 减少 `ReaderContent` 早退分支与重复 pageBuilder。

## 后果

- 配置项：「翻页动画：滑动 / 卷曲」而非独立阅读模式（可后续改 UI）。
