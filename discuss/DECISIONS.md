# 架构决策索引（ADR）

> 阅读核心相关决策；修订须新开 ADR 并更新 [READING_BOUNDARIES.md](./READING_BOUNDARIES.md)。

| ADR | 标题 | 状态 | 日期 |
| ----- | ------ | ------ | ------ |
| [001](./adr/001-reading-position-truth.md) | 进度 = chapterIndex + charOffset（plainText） | **已接受** | 2026-06-18 |
| [002](./adr/002-pageturn-is-pagination-skin.md) | pageTurn 合并为 pagination 皮肤 | **已接受** | 2026-06-18 |
| [003](./adr/003-block-pagination-ir.md) | 分页必须 EPUB 看图 → IR + 块分页 | **已接受** | 2026-06-18 |
| [004](./adr/004-cross-chapter-staging.md) | 保留 staging，换章零感知 loading | **已接受** | 2026-06-18 |
| [005](./adr/005-bilingual-optional.md) | 双语 = 设置项，非主加载链 | **已废弃** | 2026-06-18 |
| [006](./adr/006-rust-flutter-division.md) | Rust IR+分页；Flutter 渲染+staging | **已接受** | 2026-06-18 |
| [007](./adr/007-plaintext-segmentation-stability.md) | plainText 分段冻结；charOffset 稳定 | **已接受** | 2026-06-18 |
| [017](./adr/017-reading-offset-utf16-contract.md) | charOffset 跨 Rust/Flutter/SQLite 统一为 UTF-16 code unit | **已接受** | 2026-07-16 |
| [008](./adr/008-ir-image-plain-placeholder.md) | IR 图片在 plain 中用 `\uFFFC` 占位 | **已接受** | 2026-06-18 |
| [009](./adr/009-scroll-ir-unification.md) | Scroll 统一 Chunked IR | **已接受** | 2026-06-25 |
| [010](./adr/010-block-css-in-ir.md) | IR Text 块基础 CSS；版式窄义 | **已接受** | 2026-06-25 |
| [011](./adr/011-bilingual-feature-module.md) | 双语独立 feature，主链零依赖 | **已废弃** | 2026-06-25 |
| [012](./adr/012-staging-prefetch-guarantee.md) | Staging 预取硬保证，零可见 loading | **已接受** | 2026-06-25 |
| [013](./adr/013-flutter-metrics-calibration.md) | Rust 初筛 + Flutter metrics 回传 | **Superseded by 016** | 2026-06-25 |
| [014](./adr/014-api-path-unification.md) | 分页 API 路径统一 | **已接受** | 2026-07-03 |
| [015](./adr/015-css-style-whitelist-pruning.md) | CSS 样式白名单裁剪 | **已接受** | 2026-07 |
| [016](./adr/016-flutter-pagination-engine-proposed.md) | 分页装箱迁 Flutter | **Accepted** | 2026-07-12 |

## 问卷归档

| 轮次 | 文件 | 作用 |
| ------ | ------ | ------ |
| 1 | [xinxi.md](./xinxi.md) | 边界初稿 |
| 2 | [xinxi-round2.md](./xinxi-round2.md) | 冲突拍板 |
| 3 | [xinxi-round3.md](./xinxi-round3.md) | ADR-001 / G7 确认 |
| 4 | [xinxi-round4.md](./xinxi-round4.md) | Phase 1 缺口；ADR-007；INTENTS |
| 5 | [xinxi-round5.md](./xinxi-round5.md) | Phase 4 引擎完善；ADR-009～013 |

## 相关文档

- [READING_BOUNDARIES.md](./READING_BOUNDARIES.md) — 产品边界 v1.3
- [PHASE4_SCOPE.md](./PHASE4_SCOPE.md) — Phase 4 范围（已关闭）
- [DOMAIN_MODEL.md](./DOMAIN_MODEL.md) — 领域模型
- [TARGET_ARCHITECTURE.md](./TARGET_ARCHITECTURE.md) — 目标技术架构
- [ROADMAP.md](./ROADMAP.md) — 实施阶段
- [INTENTS.md](./INTENTS.md) — 分页 intent 契约
- [PHASE1_EXIT.md](./PHASE1_EXIT.md) — Phase 1 退出验收
