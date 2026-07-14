# 阅读核心路线图（与边界 v1.1 绑定）

> **当前阶段 = Phase 7 收尾**（2026-07-13）
> **Phase 8** 已关闭 ✅（滚动模式 Flutter 化）
> **Phase 7** 进行中 🔄（清理冗余代码）
> **上一阶段**：Phase 8 滚动模式 Flutter 化
> **下一阶段**：Phase 9 Flutter 原生 IR + 管线简化

---

## Phase 0 — 冻结边界与架构 ✅ 已完成

- [x] `READING_BOUNDARIES.md` v1.1
- [x] ADR-001 ~ 006
- [x] `DOMAIN_MODEL.md`、`TARGET_ARCHITECTURE.md`、`DECISIONS.md`
- [x] `xinxi-round3.md`：R3-1、R3-2 确认

**验收一句话**：进度存 charOffset；正文以 plain 为锚；分页目标吃 IR；staging 只负责换章快。

---

## Phase 1 — 瘦身现有链 ✅ 已完成

**目标**：减冗余、单 plain 真理；**不**做块分页；**不**砍 staging。

| # | 任务 | 状态 | 验收 |
| --- | ------ | ------ | ------ |
| 1.1 | 合并 `loadChapterContent` / firstSpine / plain 并行 | ✅ | [PHASE1_EXIT.md](./PHASE1_EXIT.md) |
| 1.2 | 全文 plain ready 后再 TTS / 搜索索引 | ✅ | finalize 后 `_postLoadTasks` |
| 1.3 | 分页路径 gate EPUB rich | ✅ | `_needsRichContent` |
| 1.4 | Orchestrator intent 文档化 | ✅ | [INTENTS.md](./INTENTS.md)（5 intent） |
| 1.5 | pageTurn 皮肤（`PaginationSkin`） | ✅ | ADR-002 + `PageTurnShell` |
| 1.6 | 分页 EPUB toast（可选） | ✅ | `epubRichSkipped` |

**R4 追加**：主链 EPUB+TXT；[ADR-007](./adr/007-plaintext-segmentation-stability.md)；已合入 `master` @ `2eebb52`。

**退出标准**：[PHASE1_EXIT.md](./PHASE1_EXIT.md) 全绿 ✅

---

## Phase 2 — IR + 块分页 MVP ✅ 已完成（ADR-003）

EPUB 分页内联图 + 大图独占页；`BlockPaginator`；charOffset 兼容 ADR-001。

| 里程碑 | 内容 | 状态 |
| -------- | ------ | ------ |
| M0 | `ContentBlock` 契约 + FRB | ✅ |
| M1 | EPUB/TXT → IR + plain 投影 | ✅ |
| M2 | `BlockPaginator` MVP | ✅ |
| M3 | 接入 `PaginationSession` | ✅ |
| M4 | Flutter 块渲染 + 图片管道 | ✅ |
| M5 | staging 回归 + S2/S3 | ✅ |

**退出标准**：[PHASE2_EXIT.md](./PHASE2_EXIT.md) 全绿 ✅

---

## Phase 3 — 体验与缓存 ✅ 已完成

预取强化、图片管道、sled 块分页索引、大章 chunked IR。详见 [PHASE3_EXIT.md](./PHASE3_EXIT.md)。

| # | 项 | 状态 |
| --- | ----- | ------ |
| P3-1 | M3.3 partial → block expand | ✅ |
| P3-2 | 段间距 Rust ↔ Flutter | ✅ |
| P3-3 | 图片预取深化 | ✅ |
| P3-4 | scroll 含图进度模型 | ✅ |
| P3-5 | 大章 chunked IR | ✅ |
| P3-6 | sled block 分页索引 | ✅ |

**退出标准**：[PHASE3_EXIT.md](./PHASE3_EXIT.md) 全绿 ✅

---

## Phase 4 — 引擎完善 ✅ 已完成（核心链路完成，真机签退待 Phase 5 M1）

**目标**：统一 IR 渲染管线、块级 CSS、staging 硬保证、metrics 校准、双语模块边界。详见 [PHASE4_SCOPE.md](./PHASE4_SCOPE.md)。

> **2026-06-26 收敛完成**：scroll 仅走 IR，分页 miss 用骨架替代 spinner，双语独立模块完成，I1 持久化清理，block font-size 贯穿 IR 管线，FFI 集成测试恢复（29 pass），金路径测试 24/24。
> **2026-07-02～03 全 bug 修复**：A/B 已修、P0 架构统一（纯文本书走 IR）、P1 sled 双缓存合并、P2 避尾标点、P3 configHash BigInt、精排 P1/P2 CSS 投射完成。真机签退推迟至 Phase 5 M5 收尾。
| # | 项 | ADR | 状态 |
|---|-----|-----|------|
| P4-0 | 文档对齐（README / DOMAIN_MODEL / glossary） | — | ✅ |
| P4-1 | Scroll → Chunked IR | 009 | ✅ |
| P4-2 | IR Text 块基础 CSS | 010 | ✅ 块级 + 行内 span；用户缩进开关；cache v2 |
| P4-3 | Staging 零可见 loading | 012 | ✅ |
| P4-4 | Flutter Metrics 回传校准 | 013 | ✅ |
| P4-5 | 双语独立 feature 模块 | 011 | ✅ |

**退出标准**：[PHASE4_SCOPE.md](./PHASE4_SCOPE.md) §退出标准 — 代码交付 ✅，真机签退推迟至 Phase 5

---

## Phase 5 — 稳定性与工程化 ✅ 已完成

Phase 7 代码清理完成后，此阶段各项已自然完成。

| # | 项 | 状态 |
| --- | ----- | ------ |
| 5-1 | 22 处 catch(_) → catch(e) + Logging | ✅ |
| 5-4 | ADR-014 API 路径统一 | ✅ |
| 5-7 | Orchestrator/Coordinator/Session 测试补齐 | ✅ |
| 5-11 | BookStatus 默认值 + 废弃函数清理 | ✅ |
| 5-0 | 真机签退（收尾） | ✅ |

---

---

## Phase 6 — Flutter 分页迁移 ✅ 已完成

**目标**：将分页管线从 Rust 完全迁移到 Flutter 侧，消除对 Rust `paginate_chapter` 的依赖。

| # | 项 | 状态 |
| --- | ----- | ------ |
| 6.1 | Flutter 侧 `TextPainter` 精确装箱 MVP | ✅ |
| 6.2 | `PackedPage` / `PackedBlockSlice` 纯 Dart 类型 | ✅ |
| 6.3 | `FlutterPaginationSession` 替代 Rust session | ✅ |
| 6.4 | Staging 预加载适配 Flutter 装箱 | ✅ |
| 6.5 | 大章 chunked IR + partial → full expand | ✅ |
| 6.6 | Phase 7 清理冗余 | 🔄 进行中 |

**退出标准**：Flutter 分页覆盖全量场景，Rust 分页 API 无实际调用方。

---

## Phase 8 — 滚动模式 Flutter 化 ✅ 已完成

**目标**：将 scroll 模式的 EPUB 富文本排版从 Rust 迁移到 Flutter，用 IR 统一两条渲染路径。

| # | 项 | 状态 |
| --- | ----- | ------ |
| 1 | Flutter 侧 IR → TextSpan 渲染器（scroll_ir_block_list.dart） | ✅ |
| 2 | Scroll 数据源替换：getEpubChapterRichContent → getChapterContentIr | ✅ |
| 3 | 删除 Rust RichParagraph / RichChapterContent / RICH_CONTENT_CACHE | ✅ |
| 4 | 删除 Rust TypesetConfig/TypesetCalibration FRB 导出 | ✅ |
| 5 | 删除 char_width.rs / line_breaking.rs（无生产消费者） | ✅ |
| 6 | 删除 Dart currentRichParagraphs 全链 | ✅ |

---

## Phase 9 — Flutter 原生 IR + 管线简化（规划中）

**目标**：IR 数据结构从 Rust 遗留设计优化为 Flutter 原生形式，
消除 Rust-era 中间类型，简化两条渲染管线。

### 任务清单

#### A — Rust 侧精简

| # | 项 | 说明 |
| --- | ----- | ------ |
| A1 | 删除 `storage/repos/` 中不必要的 CRUD repo 文件 | 12 个文件，每个都是薄 DB 包装，可合为 2-3 个 |
| A2 | 评估 `api/data/init.rs` 迁出 api 层 | 数据库初始化不属于 FRB 接口（受 FRB 约束暂缓） |
| A3 | 清理 `api/bilingual.rs` 死函数 | `get_bilingual_highlight_pairs` 无 Dart 调用方 |
| A4 | 清理 `api/dictionary.rs` 死函数 | `get_dictionary`、`suggest_mdict` 无 Dart 调用方 |
| A5 | 清理 `api/epub.rs` 死函数 | `get_epub_metadata` 无 Dart 调用方 |
| A6 | 评估 `api/vocab_marker.rs` DB CRUD 整合 | 迁入 `api/data/vocabulary.rs` |
| A7 | `LINE_BREAKS_STORE` 行断点缓存机制评估 | 当前是 `api/reader.rs` 中的 `HashMap`，是否够用？ |

#### B — Flutter 侧接口简化

| # | 项 | 说明 |
| --- | ----- | ------ |
| B1 | `PaginationSession` 接口评估 | 仅一个实现（`FlutterPaginationSession`），当时为 Rust/Flutter 双 session 设计，现可考虑简化 |
| B2 | `ReaderRepositoryInterface` 精简 | pageBlocks() / descriptors getter 仍保留分页时代接口，可扁平化 |
| B3 | `ChapterPaginationMode` 枚举评估 | plainText 变体曾是 Rust session fallback，现始终为 contentBlocks |
| B4 | `FlutterPaginationSession.descriptors` 简化 | 已换为 `PackedPage[]`，但 interface 层仍可能有冗余 |

#### C — FRB 类型最小化

| # | 项 | 说明 |
| --- | ----- | ------ |
| C1 | `block_pagination.dart` | 已删源文件，产物残留，下次 codegen 自动消失 |
| C2 | `pagination.dart` | `SearchResult`/`IndexStats` 搜索在用；`PageContent`/`ChapterPaginationMode` 待评估 |
| C3 | `metadata.dart` | `EpubMetadata` 仅被 `get_epub_metadata`（死函数）使用 |
| C4 | `rich_text.dart` | `RichTextSpan`/`SpanStyle` Rust 和 Dart 各存一份，可考虑纯 Dart 化 |
| C5 | `content_ir.dart` | `ChapterContentIr` 为核心 IR 类型，暂保留 |

#### D — 文档 / Spec 刷新

| # | 项 | 说明 |
| --- | ----- | ------ |
| D1 | `pagination-guidelines.md` | 仍引已删的 Rust pagination API，需重写 |
| D2 | `quality-guidelines.md` | calibration 测试引用已过时 |
| D3 | `DOMAIN_MODEL.md` / `DECISIONS.md` | 多出架构描述需要同步更新 |

### 与 Phase 8 对比的增量发现

- **12 个 repo 文件**冗余（每个 CRUD 操作一个文件）
- **PaginationSession 接口**是 Rust session 时代的遗物，现在只有一个实现
- **blancing 测试/规格**多处引用已删的 Rust pagination API
- **FRB 类型最小化**可消除 3 个生成的类型文件

### 注意

- Phase 9 是架构优化，非功能开发，以代码减少和可维护性为衡量标准
- 部分改动（如纯 Dart IR 类型）可能影响性能，需 benchmark

## 不做（Phase 4 仍适用）

PDF 阅读、WebView、账号/多端同步、章内搜索 UI、Rust CancellationToken、CJK 标点挤压引擎。
