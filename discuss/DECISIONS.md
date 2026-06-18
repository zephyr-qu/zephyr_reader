# 架构决策索引（ADR）

> 阅读核心相关决策；修订须新开 ADR 并更新 [READING_BOUNDARIES.md](./READING_BOUNDARIES.md)。

| ADR | 标题 | 状态 | 日期 |
|-----|------|------|------|
| [001](./adr/001-reading-position-truth.md) | 进度 = chapterIndex + charOffset（plainText） | **已接受** | 2026-06-18 |
| [002](./adr/002-pageturn-is-pagination-skin.md) | pageTurn 合并为 pagination 皮肤 | **已接受** | 2026-06-18 |
| [003](./adr/003-block-pagination-ir.md) | 分页必须 EPUB 看图 → IR + 块分页 | **已接受** | 2026-06-18 |
| [004](./adr/004-cross-chapter-staging.md) | 保留 staging，换章零感知 loading | **已接受** | 2026-06-18 |
| [005](./adr/005-bilingual-optional.md) | 双语 = 设置项，非主加载链 | **已接受** | 2026-06-18 |
| [006](./adr/006-rust-flutter-division.md) | Rust IR+分页；Flutter 渲染+staging | **已接受** | 2026-06-18 |

## 问卷归档

| 轮次 | 文件 | 作用 |
|------|------|------|
| 1 | [xinxi.md](./xinxi.md) | 边界初稿 |
| 2 | [xinxi-round2.md](./xinxi-round2.md) | 冲突拍板 |
| 3 | [xinxi-round3.md](./xinxi-round3.md) | ADR-001 / G7 确认 |

## 相关文档

- [READING_BOUNDARIES.md](./READING_BOUNDARIES.md) — 产品边界 v1.1
- [DOMAIN_MODEL.md](./DOMAIN_MODEL.md) — 领域模型
- [TARGET_ARCHITECTURE.md](./TARGET_ARCHITECTURE.md) — 目标技术架构
- [ROADMAP.md](./ROADMAP.md) — 实施阶段
