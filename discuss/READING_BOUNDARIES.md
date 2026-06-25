# Zephyr Reader — 阅读核心边界 v1.1

> **状态**：已冻结 · **Phase 0 已闭环**（2026-06-18）  
> 来源：`xinxi.md` → `xinxi-round2.md` → `xinxi-round3.md`  
> 冲突时以本文为准；技术细节见 [DECISIONS.md](./DECISIONS.md)、[DOMAIN_MODEL.md](./DOMAIN_MODEL.md)。

---

## 一页纸

| 项 | 内容 |
|----|------|
| **一句话** | 离线手机/平板阅读器：休闲 + 学习（含双语），给爱读书的人。 |
| **主格式** | **EPUB 第一**，TXT 第二 |
| **默认模式** | scroll；pagination + pageTurn 皮肤为 Must |
| **80%** | 进度/书签/笔记稳定 · 排版可调 · 搜索快 · **换章丝滑** |
| **进度真理** | `chapterIndex` + `charOffset`（plainText）— [ADR-001](./adr/001-reading-position-truth.md) |
| **技术分工** | Rust IR+块分页+缓存；Flutter 渲染+staging — [ADR-006](./adr/006-rust-flutter-division.md) |
| **当前阶段** | **Phase 3 已退出**（2026-06-24）— [ROADMAP.md](./ROADMAP.md) / [PHASE3_EXIT.md](./PHASE3_EXIT.md) |
| **明确不做** | PDF 阅读、账号/同步、复杂 CSS、WebView 全引擎 |

---

## 架构原则

> 在现有臃肿上：**先理清、减冗余** → 再在清晰边界上加 IR/块分页；**保留 staging**。

---

## Must / Should / Won't

### Must

| 类别 | 内容 |
|------|------|
| 阅读 | 目录、scroll、pagination、进度、书签、划线笔记 |
| 排版 | 字体/字号/行距 |
| EPUB scroll | 看图 + 基础样式 |
| **EPUB pagination** | **看图**（内联图；大图缩小或独占页） |
| 扩展 | TTS、词汇标注 |
| 场景 | S1 TXT 百万字分页、S2 EPUB 插图、S3 书签恢复 |

### Should

- pageTurn 合并为 pagination 皮肤（ADR-002）
- 章内搜索、主题色、大章降级 + 提示
- 分页基础样式（非完整 CSS）
- 双语：设置开关；非主加载链（ADR-005）

### Won't

- PDF 阅读（主仓可移除 PDF 阅读链）
- 多设备同步、账号
- WebView / 完整 HTML 排版引擎
- CSS float / 多栏 / 复杂表格
- 对标微信读书全量能力

---

## 已接受 ADR（全部闭环）

| ADR | 内容 |
|-----|------|
| [001](./adr/001-reading-position-truth.md) | charOffset 进度 |
| [002](./adr/002-pageturn-is-pagination-skin.md) | pageTurn 皮肤 |
| [003](./adr/003-block-pagination-ir.md) | IR + 块分页看图 |
| [004](./adr/004-cross-chapter-staging.md) | 保留 staging |
| [005](./adr/005-bilingual-optional.md) | 双语可选 |
| [006](./adr/006-rust-flutter-division.md) | Rust/Flutter 分工 |
| [007](./adr/007-plaintext-segmentation-stability.md) | plainText 分段冻结 |

---

## North Star 加载路径

```
章节 → Rust: ContentBlock[] (IR)
     → Rust: BlockPaginator → PageInfo[]
     → 缓存 (config_hash)
     → Flutter: 按页渲染 Text/Image
     → staging 预取相邻章
     → ReadingPosition (chapterIndex, charOffset)
```

**Phase 1 前禁止**：第三条并行读章；无 ADR 的 intent/staging 扩展。

---

## 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| v1.0 | 2026-06-18 | 第二轮冻结 |
| v1.1 | 2026-06-18 | 第三轮闭环；Phase 0 完成 |
