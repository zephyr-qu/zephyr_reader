# ADR-012：Staging 预取硬保证（零可见 Loading）

- **状态**：已接受（D8-C，2026-06-25）
- **日期**：2026-06-25

## 决策

1. **G2-b「换章丝滑」验收标准升级**：用户执行 adjacent 跨章（forward/backward）时，**不得**出现 `CircularProgressIndicator` 或其它可见 loading 占位。
2. 若相邻章 staging 未就绪，**宁可短暂阻塞翻页手势/动画**，也不展示 spinner（离线本地资源下预取应可 deterministic 命中）。
3. `preloadAdjacentFirstPages` / `ensurePrevChapterStaging` 状态机须在用户到达章界 **之前** 完成首屏/末屏 + 块数据就绪。

## 理由

- 用户心理学：任何可见 spinner 即「卡了一下」，违背零 loading 承诺。
- 离线阅读器：分页与 IO 均可预测；应把预取当作**硬指标**而非 best-effort。
- 倒逼完善 ADR-004 staging 与 adopt 路径，而非 UI 层用 loading 掩盖 miss。

## 后果

- **接受**：staging miss 时记录 error/telemetry，开发环境 assert；生产环境阻塞或重试预取。
- **拒绝**：`_buildPreviousChapterPage` / `_buildCrossChapterPage` 长期返回 spinner 作为常态路径。
- **验收**：真机 forward/backward 跨章无 spinner；可选 `[Timing]` 日志（非阻塞 exit 条件）。

## 关联

- [ADR-004](./004-cross-chapter-staging.md)、[PHASE4_SCOPE.md](../PHASE4_SCOPE.md) P4-3
- [DOMAIN_MODEL.md](../DOMAIN_MODEL.md) I7
