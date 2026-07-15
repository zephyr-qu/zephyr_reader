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

### 与 Phase 7 的分工

Phase 7 已完成（`phase/7-cleanup-redundant-code` → `master`）。以下项目原标记为 Phase 7 但属于架构改造而非纯删除，自下而上移至 Phase 9。

### 任务清单

| # | 优先级 | 项 | 说明 |
| --- | ------ | ----- | ------ |
| 0 | **P0** | **Rust 目录重组** | 按 [`docs/rust-restructure-plan.md`](../docs/rust-restructure-plan.md) 执行：common/infra/library/reader/profile/language 6 层重组，44+ 文件移动，163 处 Dart 导入变更，FRB codegen 重新生成 |
| 1 | **P1** | **IR 结构优化**：`BlockPlainRange`/`ContentBlock` 枚举 → 扁平 Dart 类型 | 消除 Rust→Flutter 转换层 |
| 2 | **P1** | **RichTextSpan / TextBlockStyle 纯 Dart 化** | 消除 FRB 序列化开销 |
| 3 | **P1** | **`PaginationSession` 接口简化** | 仅一个实现，去掉抽象层 |
| 4 | **P2** | **`api/data/init.rs` 迁出 api 层** | 数据库初始化不属于 FRB 接口 |
| 5 | **P2** | **`api/vocab_marker.rs` DB CRUD 整合** | 迁入 `api/data/vocabulary.rs` |
| 6 | **P2** | **`ChapterPaginationMode.plainText` 死变体删除** | 不再使用的枚举变体 |
| 7 | **P2** | **`LINE_BREAKS_STORE` 行断点缓存评估** | Rust 侧 HashMap 缓存是否还有必要 |
| 8 | **P2** | **死 FRB 函数删除** | `get_bilingual_highlight_pairs`、`get_dictionary`、`suggest_mdict`、`get_epub_metadata` |
| 9 | **P2** | **CJK 标点挤压引擎** | UI toggle 当前无效但用户能看到，属于 visible gap。方案：IR 预处理阶段对标点序列做紧凑替换（全角→半宽变体），约 1-2 天。**好处大于投入** |
| 10 | **P3** | **`get_chapter` 退化备选移除评估** | IR 可靠时可删除 plain text fallback |

---

## Phase 10 — TXT 章节检测正则可配置化（规划中）

**目标**：将硬编码在 `chapter_detect.rs` 中的四组章节检测正则改为由 Flutter 侧传入配置，
支持用户自定义章节标题模式，覆盖更多网文/轻小说格式。

### 背景

当前 `extract_chapters()` 按固定优先级尝试 4 组硬编码模式：
`ZH → ZH_ENUM → EN → DIGIT`。
网文格式多样，固定模式总有遗漏，且每次调整需修改 Rust 代码+重新编译。

### 设计方向

| 维度 | 方案 A（推荐） | 方案 B（不推荐） |
| ------ | ---------------- | ------------------ |
| 配置传递 | 每次 `parse()` 传入 `Option<ChapterPatterns>` | 全局 `Mutex` 可变状态 |
| 正则缓存 | 按模式串 hash 编译后缓存 | 每次 parse 重新编译 |
| 向后兼容 | `None` → 当前硬编码行为 | 需 migration |
| 竞态风险 | 无（一次调用一次配置） | 多书同时解析时可能竞态 |

### 任务清单

| # | 项 | 说明 | 优先级 |
| --- | ----- | ------ | ------ |
| 1 | Rust `ChapterPatterns` FRB struct | `Vec<String>` patterns + 优先级顺序 | P1 |
| 2 | `extract_chapters()` 改接受配置参数 | 向后兼容默认行为 | P1 |
| 3 | 正则编译结果 LRU 缓存 | 避免每次 parse 重新编译 | P1 |
| 4 | Flutter 默认配置层 | 内置默认值 ≈ 当前 4 组 pattern | P2 |
| 5 | Flutter 设置 UI | 用户可添加/删除/排序 pattern | P3 |
| 6 | `parse_txt_inner` 调用链适配 | 从 `parse()` 入口传递配置到 `extract_chapters()` | P1 |

### 不做

- 每本书独立 pattern 配置（复杂度过高，除非用户需求明确）
- 自动 pattern 推荐/学习（可等数据积累后再考虑）
- EPUB 章节检测（EPUB 有 TOC 结构，不需要正则）

### 不做

- 每本书独立 pattern 配置（复杂度过高，除非用户需求明确）
- 自动 pattern 推荐/学习（可等数据积累后再考虑）
- EPUB 章节检测（EPUB 有 TOC 结构，不需要正则）

### 不做

PDF 阅读、WebView、账号/多端同步、章内搜索 UI、Rust CancellationToken。

---

## Phase 11 — 业务下沉和业务简化（规划中）

**目标**：两条纲领，Phase 11 启动时扫描审查。

### 方向 A：业务下沉

本来在 Repo/SQL 层就能做的事，就不要在业务 Service 层实现。

示例：删除书籍的级联操作应一条 SQL `ON DELETE CASCADE` 或 repo 层事务内完成，
而不是 Service 层逐表调 delete + API 层再额外跨模块调搜索索引清理。

### 方向 B：业务简化

减少 Flutter → Rust FFI 调用次数。Flutter 需要调多次才能完成的功能，
Rust 层聚合成一个接口输出。

示例：保存阅读进度和记录阅读会话当前是两个独立 FFI 调用，
应合并为一个 `save_reading_state` 在 Rust 侧一个事务内完成。

### 启动方式

Phase 11 启动时对整个代码库做一次 `业务下沉 + 简化` 审查扫描，
列出所有可下沉的 for 循环 SQL 和可聚合的多段 FFI 调用链，然后逐一整改。
不在启动前预列详细清单。
