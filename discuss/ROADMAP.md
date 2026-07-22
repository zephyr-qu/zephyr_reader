# 阅读核心路线图（与边界 v1.1 绑定）

> **当前阶段 = Phase R1**（Readium 双引擎统一接入）
> **Phase 0-12** 已完成 ✅
> **Phase 13** ✅ 已完成

**完整路线图（Phase 0-20）：**

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

**目标**：统一 IR 渲染管线、块级 CSS、staging 硬保证、metrics 校准、。详见 [PHASE4_SCOPE.md](./PHASE4_SCOPE.md)。

> **2026-06-26 收敛完成**：scroll 仅走 IR，分页 miss 用骨架替代 spinner，I1 持久化清理，block font-size 贯穿 IR 管线，FFI 集成测试恢复（29 pass），金路径测试 24/24。
> **2026-07-02～03 全 bug 修复**：A/B 已修、P0 架构统一（纯文本书走 IR）、P1 sled 双缓存合并、P2 避尾标点、P3 configHash BigInt、精排 P1/P2 CSS 投射完成。真机签退推迟至 Phase 5 M5 收尾。
| # | 项 | ADR | 状态 |
|---|-----|-----|------|
| P4-0 | 文档对齐（README / DOMAIN_MODEL / glossary） | — | ✅ |
| P4-1 | Scroll → Chunked IR | 009 | ✅ |
| P4-2 | IR Text 块基础 CSS | 010 | ✅ 块级 + 行内 span；用户缩进开关；cache v2 |
| P4-3 | Staging 零可见 loading | 012 | ✅ |
| P4-4 | Flutter Metrics 回传校准 | 013 | ✅ |
| P4-5 | 双语独立 feature 模块 | 011 | ❌ 已移除 |

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

## Phase 9 — IR 优化 + Flutter 管线简化 ✅ 已完成

**目标**：优化 Rust 定义、FRB 生成的 IR 数据结构，收口 Flutter 导入边界，
消除 Rust-era 中间类型，简化两条渲染管线。

### 与 Phase 7 的分工

Phase 7 已完成（`phase/7-cleanup-redundant-code` → `master`）。以下项目原标记为 Phase 7 但属于架构改造而非纯删除，自下而上移至 Phase 9。

### 任务清单

| # | 优先级 | 项 | 说明 |
| --- | ------ | ----- | ------ |
| 0 | **P0** | **Rust 目录重组** | ✅ 已完成 — API 瘦身 + Flutter import 修复 |
| 1 | **P1** | **IR 结构优化 + Flutter 入口收口** | ✅ 已完成 — IR 由 Rust 定义并由 FRB 自动生成 Dart 类型；`ir_types.dart` 是 Flutter 阅读引擎的统一导入入口，不维护重复 Dart IR |
| 2 | **P1** | **`PaginationSession` 接口简化** | ✅ 已完成 — 假抽象类已合并，DI 工厂已删除 |
| 3 | **P2** | **`ChapterPaginationMode.plainText` 死变体删除** | ✅ 已完成 — 枚举及字段已删除，残留测试引用待清理 |
| 4 | **P2** | **`LINE_BREAKS_STORE` 行断点缓存评估** | ✅ 已完成 — `line_breaking.rs`/`char_width.rs` 已在 Phase 8 删除，Flutter 侧 `TextPainter` 完成所有断行 |
| 5 | **P2** | **CJK 标点挤压引擎** | ❌ 不实现 — ADR-013 已明确跳过，收益低于复杂度 |
| 6 | **P3** | **`get_chapter` 退化备选移除评估** | ✅ 评估完成 — 暂保留，IR 路径未覆盖全部场景 |

---

## Phase 10 — Flutter 架构扁平化与阅读引擎独立 ✅ 已完成

**目标**：将排版渲染核心从 reader feature 提取为独立 `reader_engine/` 模块，
消除假抽象接口和中间人。

**讨论**：`discuss/PHASE12_FLUTTER_ARCHITECTURE.md`

### 任务清单

| # | 优先级 | 项 | 说明 |
| --- | -------- | ----- | ------ |
| 1 | **P0** | 创建 `lib/reader_engine/` 目录结构 | ✅ 已完成 |
| 2 | **P0** | 移动 pagination 文件 | ✅ 已完成 |
| 3 | **P0** | 移动 scroll 文件 | ✅ 已完成 |
| 4 | **P0** | 移动 rendering 文件 | ✅ 已完成 |
| 5 | **P1** | 实现 `PaginationEngine` 类 | ✅ 已完成 |
| 6 | **P1** | 实现 `ScrollEngine` 类 | ✅ 已完成 |
| 7 | **P1** | 删除 `ReaderRepository` 中间人 | ✅ 已完成 |
| 8 | **P2** | 删除 4 个假抽象接口 | ✅ 已完成 |
| 9 | **P2** | 合并 `core/domain/` 和 `domain/` | ✅ 已完成 |
| 10 | **P2** | 合并小文件 | ✅ 已完成 |

### 不做

- 不引入新的架构抽象（UseCase、BLoC 等）
- 不改 Rust 侧代码
- 不改 UI 交互行为

---

## Phase 11 — 收尾 Phase 9/10 + Rust 后端重构 ✅ 已完成

**目标**：两阶段：先收尾 Flutter 侧 Phase 9/10 架构余留问题，再对 Rust 业务层做业务下沉+API 简化。

### 阶段 A 状态：全部完成 ✅

- `reader_engine/` 现在完全独立，**zero imports from `features/reader/`** ✅
### 阶段 A：Flutter 架构收尾

| # | 优先级 | 项 | 说明 |
| --- | -------- | ----- | ------ |
| 1 | **P1** | **engine config 迁移** | ✅ 已完成 — 5 个 config 文件迁至 `reader_engine/shared/config/`，消除反向依赖 |
| 2 | **P1** | **`ChapterContentRepository` 放回 data 层** | ✅ 已完成 — 移至 `reader_engine/data/`，连带 `NextChapterStaging`/`PaginationUtils`/`PaginationViewportIndex`/`PageInfo` 一并迁移 |
| 3 | **P1** | **`ReaderRenderDataSource` 删除** | ✅ 已完成 — 内联到消费者，删 11KB 委托代码 |
| 4 | **P1** | **`PaginationSession` 生命周期统一** | ✅ 已完成 — `PaginationEngine` 为唯一所有者，`createSession`/`disposeSession` 统一入口，去除 5 处直接 `_session` 持有 |
### 阶段 B：Rust 后端重构

**讨论**：`discuss/PHASE11_BUSINESS_SIMPLIFICATION.md`

#### 方向 A：业务下沉

**应该下沉的（到 repo/SQL）：**

- Service 层用 for 循环/逐条 delete 做数据库本有能力的事（如级联删除）
- Service 层只是包了一层 SQL 的纯中间人（单个 repo 调用、无逻辑）
- 一条复杂 SQL 比多条 repo 调用更清晰（看场景，可读性优先）

**不该下沉的（留在 service）：**

- 跨模块编排（如删书→删搜索索引涉及 book + search 两个领域）
- 包含业务规则的操作（如分类删除前的安全校验）
- 计算/转换逻辑（如从笔记统计估算阅读时长）

#### 方向 B：业务简化

**应该聚合的：**

- 同屏数据来自不同表（如书架列表 + 进度 + 分类，返回相同类型 `BookshelfBook`）
- Flutter 侧用多个 if/else 分支选调不同 API（说明设计有问题，可选参数即可）
- 总是成对出现且需要事务一致性（如存进度+记会话）

**不该聚合的：**

- 不同生命周期触发（如导入书 vs 提取封面，封面失败不阻塞导入）
- 调用之间有用户交互/等待
- 返回不同类型数据，且独立使用
- 强行聚合导致接口参数爆炸

### 阶段 B 任务清单

| # | 优先级 | 项 | 说明 |
| --- | -------- | ----- | ------ |
| 1 | **P1** | 扫描 `domain/*/service.rs` | ✅ 已完成 — 13 个 service 逐文件审查，标出 7 个纯中间人（progress/chapter/stats/bookmark/vocabulary/sessions/category） |
| 2 | **P1** | 逐项整改下沉 | ✅ 已完成 — 7 个纯中间人 service 合并到对应 API 层，删除 7 个 service.rs（~470 行），保留 cover/bilingual/backup/book/dictionary/note 等有业务逻辑的 service |
| 3 | **P2** | 扫描 `api/*.rs` 聚合机会 | ✅ 已完成 — 识别 4 书架 API → 1 统一 API 机会 + upsertProgress/createSession 事务化机会 |
| 4 | **P2** | 逐项聚合整改 | ✅ 已完成 — 新增 `list_bookshelf_books` 统一接口（支持可选 category/status/sort）；待 FRB codegen 后 Flutter 端简化 |
| 5 | **P2** | 验证 | ✅ 已完成 — `cargo clippy -D warnings` 零告警，FRB codegen 成功，`flutter analyze lib/` 零错误 |

---

## Phase 12 — TXT 章节检测可配置化 + Flutter 排版管线优化 ⏳ 进行中

**目标**：两件事顺手一起做。① 将硬编码在 `chapter_detect.rs` 中的四组章节检测正则改为可配置，
支持用户自定义章节标题模式，覆盖更多网文/轻小说格式。② 顺手做 3 项低成本 Flutter 排版优化。

**讨论**：`discuss/archived/PHASE10_CHAPTER_DETECT_CONFIG.md`、`discuss/reader-text-engine-roadmap.md`
**讨论**：`discuss/archived/PHASE10_CHAPTER_DETECT_CONFIG.md`

### 背景

当前 `extract_chapters()` 按固定优先级尝试 4 组硬编码模式：
`ZH → ZH_ENUM → EN → DIGIT`。
网文格式多样，固定模式总有遗漏，且每次调整需修改 Rust 代码+重新编译。

### 设计决策

| 维度 | 决策 |
| ------ | ------ |
| 正则缓存 | ❌ 不缓存，parse 时直接编译（一次导入操作为主，编译开销可忽略） |
| 持久化 | Rust 侧 sqlite `app_settings` 表（`key TEXT PK, value TEXT`） |
| 优先级 | 默认 4 组先匹配 → 用户模式后匹配 |
| 重试机制 | 手动触发→从当前 `detect_pattern_index + 1` 继续向下匹配 |
| 书粒度状态 | `book_metadata.detect_pattern_index` 字段 |

### 任务清单

| # | 项 | 说明 | 优先级 |
| --- | ----- | ------ | ------ |
| 1 | `app_settings` 表 | 新增 migration：`key TEXT PRIMARY KEY, value TEXT NOT NULL` | P1 |
| 2 | `book_metadata.detect_pattern_index` | 新增 migration 加字段 | P1 |
| 3 | FRB struct: `ChapterPatterns` | 含 `patterns: Vec<String>`, `start_index: i32` | P1 |
| 4 | `extract_chapters_from()` | 接受 start_pattern_index，返回 used_index | P1 |
| 5 | `parse_txt_inner()` 适配 | 从 `parse_book()` 传 patterns + start_index | P1 |
| 6 | `redetect_chapters()` API | FRB 函数：读当前 index+1，重新解析，替换章节 | P1 |
| 7 | Flutter 默认配置写入 | 首次初始化时将 4 组内置模式写入 app_settings | P2 |
| 8 | Flutter 模式编辑 UI | 添加/删除/排序用户模式 | P3 |
| 9 | Flutter 重试 UI | 书籍详情页
| 9 | Flutter 重试 UI | 书籍详情页 | P3 |
| 10 | 图片解码移到后台 isolate | 图片密集 EPUB 翻页 UI jank，把 decode 推到后台 isolate | P2 |
| 11 | `sliceRichSpans` 预索引 | 二分查找替代每次 flushSlice 的线性扫描，EPUB 分页提速 5-15% | P2 |
| 12 | 大 TXT 切窗边界优化 | 加中文句号 `。` / 英文句号 `.` 作为备选切窗边界，减少句子中间截断 | P2 |
---

## Phase 13 — 基础质量攻坚（2026-07-18 重排）

**目标**：彻底解决项目基础质量问题 — source graph 净化、正确性 seam 修复、ADR-018 收口、Rust 健壮性、边界验证、最终双零门禁。

**执行顺序**：N0A → N0B → N2A → N2B → N3 → N4 → N1/N5

**背景**：2026-07-18 核心架构审查完成，结论为核心架构方向正确不需要推倒重来。
审查报告：[architecture-review-20260718-095042.html]。

---

### N0A — 净化 source graph（P0）

**目标**：安全审计文件已污染生产 DI。全部移动到仓库根目录，重新生成 DI/FRB，增加 source-root gate。

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | 移动 piolium 资料到仓库根目录 `./piolium/` | 已迁移。清理 DI config 残留，删除 build cache |
| 2 | 重新生成 DI codegen/FRB codegen | `flutter_rust_bridge_codegen generate` 验证 |
| 3 | 增加 CI gate | 禁止 `lib/` 和 `rust/src/` 包含 piolium 文件 |
| 4 | 禁止审计源码/PoC/exploit 进入 `lib/` 和 `rust/src/` | CI gate 合并检查 |

---

### N0B — 建立可信基线

**目标**：统一门禁标准、修复两个现有 lib-test 失败、建立完整的失败清单。

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | 文档统一当前 Phase 13 | ROADMAP 已更新 |
| 2 | 区分 `lib` gate 与 `all-targets` gate | 生产代码 vs 测试/集成门禁分开 |
| 3 | 修复两个现有 lib 测试失败 | 嵌套图片丢失（真实 bug）、oversized EPUB fixture（不稳定） |
| 4 | 记录完整失败清单 | `cargo clippy --all-targets` 失败、跨层测试断裂 |

---

### N2A — 修正确性 seam（P0/P1）

**目标**：修复审查发现的正确性问题 — staging/scroll generation 独立化、viewport metrics 断链、scroll progress 污染。

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | staging 双向 next/prev generation 独立 | `nextToken+nextSlot` / `prevToken+prevSlot`，`clearAll` 才取消两边 |
| 2 | scroll append/prepend generation 独立 | 双向加载不互相取消 |
| 3 | viewport metrics 断链修复 | 正式 `buildPagePlanContent` 的 LayoutBuilder 上报正文尺寸 |
| 4 | scroll fetch 不污染当前章 | 建立 `ChapterDocument` module，fetch 无副作用 |
| 5 | scroll progress 100% 修复 | 统一 `ReadingPosition` + 章节长度，删除 `pageIndex` 进度计算 |
| 6 | 旧 renderer (`buildBlockPageContent`) 移除准备 | 确认无生产调用后删除 |

---

### N2B — 完成 ADR-018（P1/P2）

**目标**：删除 `PackedPage` 和旧 renderer，renderer/navigation/staging 直消费 `LayoutSnapshot`。

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | renderer 直接消费 `LayoutSnapshot.pages` | 删除 `PackedPage` 转换步骤 |
| 2 | navigation 直接二分 `PagePlan` | 删除 `PackedPage` 导航查询 |
| 3 | staging 保存原生 snapshot/page plans | 不转 `PackedPage` |
| 4 | 图片预取直接消费 `PageFragment` | 不经过 `PackedBlockSlice` |
| 5 | 删除 `PackedPage` / `PackedBlockSlice` | 完整 deletion test |
| 6 | 删除旧 renderer 和旧行断模块 | 确认无生产调用后删除 |

---

### N3 — Rust 健壮性

**目标**：EPUB 解析健壮性、FFI 阻塞隔离、cache 新鲜度、所有 FFI Result、panic 审计。

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | EPUB 嵌套图修复 + 大 HTML DOM seam | `<span><img/></span>` 图片不被丢弃，字节切片不切断标签 |
| 2 | sync FFI 阻塞隔离 | `spawn_blocking` 包装 ZIP/read/decode/resize |
| 3 | IR cache 新鲜度 | mtime/size 判断 + singleflight |
| 4 | Rust cache 淘汰策略 | 按时间而非字典序 |
| 5 | 所有 FFI `Result<T, AppError>` | 审计非特殊导出函数 |
| 6 | `panic/unwrap` 审计 | 区分常量不变量和真实风险 |

---

### N4 — 边界压力验证

**目标**：大文件、含图 EPUB、快速交互等边界压力测试。

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | 大 TXT 打开与翻页 | 百万字级别文件 |
| 2 | 含图 EPUB 章节切换 | 高清图片密集章节流畅度 |
| 3 | 切换排版即时生效 | 字号/行距/主题切换无延迟 |
| 4 | 快速连续翻页 | 5+ 页/秒状态不混乱 |
| 5 | 打断操作 | 翻页动画中点击目录不崩溃 |
| 6 | 反复换章 | 多章来回切换稳定性 |
| 7 | scroll 跨章进度与批注 | 自然跨章不丢失批注 |

---

### N1/N5 — 最后清理 + 双零门禁

**目标**：清扫 N2-N4 遗留死代码、依赖审计、最终 `cargo clippy -D warnings` + `flutter analyze --fatal-infos` 双零。

| # | 项 | 说明 | 状态 |
| --- | ----- | ------ | ------ |
| 1 | 死代码清扫 | N2-N4 变更后遗留的老接口、未用 import | ✅ 零遗留 |
| 2 | `#[allow(...)]` 审计 | 移除不再需要的 suppress | ✅ 仅剩 10 处 `too_many_arguments`（FRB 构造器结构限制） |
| 3 | sled KV 存储评估 | 查 sled 消费者，基准测试辅助决策 | ✅ 已迁移至 redb，sled 未引入 |
| 4 | 废弃 Cargo/Flutter 依赖 | 检查 `Cargo.toml`、`pubspec.yaml` 未用依赖 | ✅ `cargo clippy --lib` 零告警 |
| 5 | `cargo clippy -- -D warnings` | 零告警（lib 门禁） | ✅ 通过（all-targets 归 Phase 19） |
| 6 | `flutter analyze --fatal-infos` | 零告警 | ✅ 通过 |
| 7 | FRB codegen 验证 | 生成代码同步、接口稳定 | ⏳ 需 CI codegen job 验证 |
| 8 | CI 流水线全部通过 | | ⏳ 需 CI 运行验证 |
| 9 | 文档同步 | 更新架构图、记录关键 Bug 与修复 | ✅ ROADMAP 已更新 |

---

### 不做

- ❌ 不加新功能
- ❌ 不写大量单元测试（等 Phase 19）
- ❌ 不盲目做性能调优（除非边界测试暴露必须修的瓶颈）
- ❌ 不改 UI/UX 细节

---

## Phase R1 — Readium 正式接入（15 阶段计划） 🔄 当前进行中

**目标**：统一阅读入口、页面壳层和产品功能；正文排版由 Builtin / Readium 两个 Adapter 分别实现。
Readium 首期只接 EPUB，不接 PDF 或漫画。
PoC 阶段已取消，正式按 R1-R15 15 阶段实施。

**讨论**：`discuss/adr/019-engine-unification.md`

**工作量估算**：约 95-105h（约 2.5-3 周满负荷）

### 执行顺序

```
R1  Docs ──→ R2  Core Models ──→ R3  Persistence
                                       ├── R4  Builtin Adapter
                                       └── R5  Readium Adapter
                                                │
                                      R6  Position Bridge
                                                │
                             R7  Policy + R8  SessionFactory
                                        │
                                  R9  Unified Page
                                   ├── R10 TOC & Progress
                                   ├── R11 Preferences
                                   ├── R12 Bookmarks & Annotations
                                   └── R13 TTS/Search/Vocab
                                        │
                                  R14 Cleanup PoC
                                        │
                                  R15 Verification & Signoff
```

### 任务清单

| # | 阶段 | 工作量 | 说明 | 状态 |
|---|------|--------|------|------|
| **R1** | 冻结正式架构 | ~2h | ADR-019 Accepted，文档对齐，声明 ReadingBackend seam | ⏳ 待开始 |
| **R2** | 多引擎核心模型 | ~5h | lib/core/reading/ 下纯 Dart seam 文件 | ⏳ 待开始 |
| **R3** | 引擎位置持久化 | ~8h | reading_engine_positions 表 + FRB API + EnginePositionHintRepository | ⏳ 待开始 |
| **R4** | Builtin Adapter | ~10h | 包装 ReaderVM/PaginationEngine → ReadingBackend | ⏳ 待开始 |
| **R5** | Readium Adapter | ~14h | Flureadium 生命周期+viewport+状态机 | ⏳ 待开始 |
| **R6** | 位置桥 | ~8h | Locator ↔ ReadingPosition 映射，含边界测试 | ⏳ 待开始 |
| **R7** | 引擎策略与回退 | ~3h | ReadingBackendPolicy + 每书覆盖 | ⏳ 待开始 |
| **R8** | SessionFactory | ~5h | 带 scope 的 scoped ReadingSession | ⏳ 待开始 |
| **R9** | 统一阅读页面 | ~12h | UnifiedReaderShell，基于 ReaderChromeShell + 删除重复壳层 | ⏳ 待开始 |
| **R10** | 目录与进度 | ~5h | ReadingChapter 统一 + 节流持久化 | ⏳ 待开始 |
| **R11** | 排版设置映射 | ~3h | ReadingPreferences → EPUBPreferences | ⏳ 待开始 |
| **R12** | 书签与批注 | ~6h | 统一书签 + decoration 桥 | ⏳ 待开始 |
| **R13** | TTS/搜索/生词 | ~3h | 应用层功能 Readium 适配 | ⏳ 待开始 |
| **R14** | 清理 PoC | ~2h | 删除 PoC 文件和路由（零结果门禁） | ⏳ 待开始 |
| **R15** | 全量验证 | ~12h | 契约测试 + 真机 20+ 用例 + 门禁 | ⏳ 待开始 |
|
**合计：约 95-105h**

### 关键原则

| 原则 | 说明 |
|------|------|
| charOffset 为领域真理 | Readium Locator 仅为 Adapter 私有位置加速提示 |
| 三小接口 | ReadingBackend / ReadingSnapshot / ReadingViewportAdapter |
| 能力显式暴露 | ReadingCapabilities 列出引擎支持/不支持的能力，禁止空实现 |
| UI 零引擎感知 | UI 不 import flureadium，不判断具体引擎类型 |
| 灰度和回滚 | Feature flag 可完整关闭 Readium；删除 Adapter 不断裂 UI |
| 允许删除 | 如维护成本超过收益可删除 ReadiumReadingAdapter |
---
## Phase 14 — 阅读中增强（规划中）

**目标**：优化用户在阅读过程中直接使用的外围功能。

| 模块 | 预期优化 |
| ------ | --------- |
| 搜索 | 搜索结果分段预览、跳转体验优化 |
| TTS | 跨章连续播放、后台播放、朗读进度恢复 |
| 双语 | 翻译缓存减少重复请求、离线回退 |
| 生词本 | 阅读中快捷操作、标记后即时反馈 |

---

## Phase 15 — 阅读外完善（规划中）

**目标**：完善用户离开阅读器后使用的功能模块。

| 模块 | 预期优化 |
| ------ | --------- |
| 书架 | 视图切换流畅度、批量操作交互 |
| 笔记管理 | 按书/章筛选、批量导出 |
| 阅读统计 | 周报/月报摘要 |
| 备份/WebDAV | 自动备份计划、完整性校验 |
| 主题/外观 | 预设主题包（<!-- TBD -->） |

---

## Phase 16 — TBD

**未确定**，暂留空。

---

## Phase 17 — TBD

**未确定**，暂留空。

---

## Phase 18 — TBD

**未确定**，暂留空。

---

## Phase 19 — 测试全面修复

**目标**：统一修复 Phase 0-18 架构重构积累的所有测试编译/运行时错误，
包括但不限于 Rust 集成测试 import 路径、Dart 侧 FRB 类型引用、
Widget 测试构造参数。**其他阶段允许顺带修，但不作为优先级**。

### 背景

Phase 9 以来多次目录重组（api/*→ domain/*/service.rs、FRB 生成结构变动）
导致跨层测试大面积断裂（79 处 `library/models.dart`、18 处 `reader/content_ir.dart` 等）。
为了避免每次重构被测试同步拖慢，决定将测试修复集中到 Phase 19，
其余阶段仅在改动极小或恰好涉及时顺手修复。

### 工作项

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | Rust 集成测试 import 修复 | `api::*` → 对应 `domain::*::service` |
| 2 | Dart 测试 FRB import 路径修复 | 反映 FRB 生成文件最终结构 |
| 3 | Dart 测试 FRB 类型构造修复 | 反映 Rust struct 字段最终形状 |
| 4 | Widget 测试 Rust 数据依赖修复 | `paginated_renderer_test.dart` 等 |
| 5 | `flutter analyze --fatal-infos` 零错误 | |
| 6 | `cargo clippy -- -D warnings` 零告警（test 目标） | |
| 7 | **可选：引入测试数据工厂** | 用 `fixture()` builder 取代直接 `const` FRB 类型，避免下次重构再碎 |

### 此前已积累的测试问题

- `test/` 下 31 处 `src/rust/...` import 可能已过期
- `rust/tests/` 下 19 个文件依赖旧 API 模块路径
- 部分测试用 `const` 构造 Rust 生成的 struct（字段变更时全部断裂）

### Phase 19 启动条件

- Phase 18 及以前架构变动全部稳定
- `cargo clippy -- -D warnings`（非 test 目标）通过
- `flutter analyze --fatal-infos`（不含测试文件）通过

---

## Phase 20 — 内测版发布

**目标**：走通发布流程，发布第一个端到端可用的内测版本。

### 预期工作项

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | 最终 QA | 全量功能回归 |
| 2 | 内测准备 | APK/IPA 打包、渠道分发 |
| 3 | 内测发布 | 封闭内测/TestFlight |
| 4 | 内测反馈收集 | 崩溃率、用户反馈 |
