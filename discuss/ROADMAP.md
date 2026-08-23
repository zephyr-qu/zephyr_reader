# 阅读核心路线图（与当前阅读边界绑定）

> **当前阶段 = EPUB Readium MVP**（ADR-020）
> **Phase 0-11、13** 为历史完成阶段；**Phase 12** 已随 TXT/Builtin 路线退出而终止
> 当前承诺仅以“EPUB Readium MVP”及其后明确标注的范围为准

> Phase 0-13 保留用于记录技术演进，不代表相关功能仍存在。全文搜索、生词本、
> 笔记、双语和 TXT/Builtin 等已删除能力，不因历史条目而重新进入待办。

**路线图（历史阶段 + 当前实施路线）：**

---

## Phase 0 — 冻结边界与架构 ✅ 已完成

- [x] `READING_BOUNDARIES.md` v1.1
- [x] ADR-001 ~ 006
- [x] `DOMAIN_MODEL.md`、`DECISIONS.md`
- [x] 历史需求冲突已收敛为当前边界与 ADR

**验收一句话**：进度存 charOffset；正文以 plain 为锚；分页目标吃 IR；staging 只负责换章快。

---

## Phase 1 — 瘦身现有链 ✅ 已完成

**目标**：减冗余、单 plain 真理；**不**做块分页；**不**砍 staging。

| # | 任务 | 状态 | 验收 |
| --- | ------ | ------ | ------ |
| 1.1 | 合并 `loadChapterContent` / firstSpine / plain 并行 | ✅ |
| 1.2 | 全文 plain ready 后再 TTS / 搜索索引 | ✅ 历史 | 搜索子系统已于 2026-08-02 删除 |
| 1.3 | 分页路径 gate EPUB rich | ✅ | `_needsRichContent` |
| 1.4 | Orchestrator intent 文档化 | ✅ | 历史契约已归档 |
| 1.5 | pageTurn 皮肤（`PaginationSkin`） | ✅ | ADR-002 + `PageTurnShell` |
| 1.6 | 分页 EPUB toast（可选） | ✅ | `epubRichSkipped` |

**R4 追加**：主链 EPUB+TXT；历史决策见 [`archived/adr/007-plaintext-segmentation-stability.md`](archived/adr/007-plaintext-segmentation-stability.md)；已合入 `master` @ `2eebb52`。

**退出标准**：历史退出检查已完成；详细历史文件已移除，当前状态以本文和测试门禁为准。

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

**退出标准**：历史退出检查已完成；当前状态以本文和测试门禁为准。

---

## Phase 3 — 体验与缓存 ✅ 已完成

预取强化、图片管道、缓存和大章 chunked IR。历史退出检查已完成。

| # | 项 | 状态 |
| --- | ----- | ------ |
| P3-1 | M3.3 partial → block expand | ✅ |
| P3-2 | 段间距 Rust ↔ Flutter | ✅ |
| P3-3 | 图片预取深化 | ✅ |
| P3-4 | scroll 含图进度模型 | ✅ |
| P3-5 | 大章 chunked IR | ✅ |
| P3-6 | sled block 分页索引 | ✅ |

**退出标准**：历史退出检查已完成；当前状态以本文和测试门禁为准。

---

## Phase 4 — 引擎完善 ✅ 已完成（核心链路完成，真机签退待 Phase 5 M1）

**目标**：统一历史 IR 渲染管线、块级 CSS、staging 硬保证和 metrics 校准；本阶段已结束。

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

**退出标准**：代码交付已完成，历史真机签退记录不再作为当前路线门禁。

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
| 6.6 | Phase 7 清理冗余 | ✅ 已完成 |

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

**历史讨论**：`discuss/archived/PHASE12_FLUTTER_ARCHITECTURE.md`

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

- 跨模块编排（如删书同时清理关联资源）
- 包含业务规则的操作（如分类删除前的安全校验）
- 计算/转换逻辑（如从阅读会话估算阅读时长）

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
| 2 | **P1** | 逐项整改下沉 | ✅ 已完成 — 7 个纯中间人 service 合并到对应 API 层，删除 7 个 service.rs（~470 行）；当前保留 book/cover/backup service |
| 3 | **P2** | 扫描 `api/*.rs` 聚合机会 | ✅ 已完成 — 识别 4 书架 API → 1 统一 API 机会 + upsertProgress/createSession 事务化机会 |
| 4 | **P2** | 逐项聚合整改 | ✅ 已完成 — 新增 `list_bookshelf_books` 统一接口（支持可选 category/status/sort）；待 FRB codegen 后 Flutter 端简化 |
| 5 | **P2** | 验证 | ✅ 已完成 — `cargo clippy -D warnings` 零告警，FRB codegen 成功，`flutter analyze lib/` 零错误 |

---

## Phase 12 — TXT 章节检测可配置化 + Flutter 排版管线优化 ⏹ 已终止（历史方案）

> ADR-020 将当前路线收敛为 EPUB-only Readium MVP，TXT/Builtin 链随后删除。
> 下列条目仅保留为历史设计记录，不是未完成待办，也不得据此恢复 TXT 支持。

**目标**：两件事顺手一起做。① 将硬编码在 `chapter_detect.rs` 中的四组章节检测正则改为可配置，
支持用户自定义章节标题模式，覆盖更多网文/轻小说格式。② 顺手做 3 项低成本 Flutter 排版优化。

**历史讨论**：`discuss/archived/PHASE10_CHAPTER_DETECT_CONFIG.md`、`discuss/archived/reader-text-engine-roadmap.md`
**历史讨论**：`discuss/archived/PHASE10_CHAPTER_DETECT_CONFIG.md`

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
| 1 | 大 TXT 打开与翻页 | ⏹ 随 TXT/Builtin 路线退出，不再验收 |
| 2 | 含图 EPUB 章节切换 | 高清图片密集章节流畅度 |
| 3 | 切换排版即时生效 | 字号/行距/主题切换无延迟 |
| 4 | 快速连续翻页 | 5+ 页/秒状态不混乱 |
| 5 | 打断操作 | 翻页动画中点击目录不崩溃 |
| 6 | 反复换章 | 多章来回切换稳定性 |
| 7 | scroll 跨章进度与批注 | ⏹ Builtin scroll 与完整批注均已退出当前路线 |

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

## EPUB Readium MVP 🔄 当前进行中

**目标**：用单一 Readium 链路交付可真机验证的 EPUB 阅读 MVP。
TXT/Builtin、双引擎 seam 和跨引擎位置映射退出当前路线。

**决策**：[ADR-020](./adr/020-epub-readium-mvp.md)（取代 ADR-019 作为当前实施路线）

### 执行顺序

```
M1 路线与边界对齐
 → M2 open/viewport/close 生命周期
 → M3 阅读页 UI 接入
 → M4 目录/进度/设置/TTS
 → M5 Android+iOS 真机回归与收口
```

### 任务清单

| # | 项 | 验收重点 | 状态 |
|---|---|---|---|
| **M1** | 文档路线更正 | ADR、边界、领域模型、Roadmap 一致 | 🔄 进行中 |
| **M2** | Readium 核心链路 | viewport ready 后再应用设置/发布 ready；关闭幂等 | 🔄 进行中 |
| **M3** | 渲染页 UI | 返回、目录、工具栏显隐、上/下页、错误可见 | 🔄 进行中 |
| **M4** | 功能接入 | Locator 恢复/节流保存、字号、主题、目录跳转、基础 TTS | 🔄 进行中 |
| **M5** | 真机收口 | 纯文本/含图/复杂 CSS EPUB；快速退出/重试/后台恢复 | ⏳ 待开始 |

### 当前原则

| 原则 | 说明 |
|---|---|
| EPUB only | 非 EPUB 在阅读入口显式拒绝，不静默回退 |
| Locator 恢复 | MVP 按 `bookId` 保存 Locator，不保存页码 |
| Ready 门槛 | 原生 viewport `onReady` 前不导航、不应用 preference、不发布 ready |
| 单一状态源 | ViewModel 统一接收 locator/status/error 并驱动 Flutter 壳层 |
| 真机为准 | Platform View 的渲染、旋转、后台与 TTS 必须由 Android/iOS 回归确认 |

### 能力边界

- 全文/章内内容搜索子系统已删除；仅保留书架中的书名查询能力。
- 生词本、笔记、双语和 TXT/Builtin 阅读链已删除，不属于后续默认规划。
- 书签当前仅保留 Readium 阅读页的基础添加、列表与跳转，不扩展为批注系统。
- 任何已退出能力若要恢复，必须重新立项并更新 ADR、边界和数据模型，不能直接从历史 Phase 续做。

---
## Phase 14 — Readium 阅读体验收口（候选，未立项）

**目标**：只在 EPUB Readium 主链上改善已存在能力；不恢复已删除子系统。

| 模块 | 预期优化 |
| ------ | --------- |
| TTS | 基础朗读稳定性与真机回归 |
| 书签 | 基础添加、列表和 Locator 跳转的稳定性与真机回归 |
| 阅读壳层 | 工具栏、目录、排版设置与连续滚动体验收口 |

> 全文搜索、章内搜索、生词本、笔记、双语不在本阶段。以上候选项也只有在
> EPUB Readium MVP 真机签退后，才可按新的范围决策进入执行。

---

## Phase 15 — 阅读外完善（规划中）

**目标**：完善用户离开阅读器后使用的功能模块。

| 模块 | 预期优化 |
| ------ | --------- |
| 书架 | 视图切换流畅度、批量操作交互 |
| 阅读统计 | 周报/月报摘要 |
| 本地备份 | 自动备份计划、完整性校验 |
| 主题/外观 | 预设主题包（<!-- TBD -->） |

> 本阶段不包含全文搜索、生词本、笔记管理或已删除学习功能的恢复。

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

## Phase 19 — 测试基线收口 ✅ 已完成

**目标**：修复历史重构造成的 Rust/Dart 测试断裂，并恢复可重复执行的本地质量门禁。

### 当前结果（2026-08-03）

| 门禁 | 结果 |
| --- | --- |
| FRB codegen | ✅ 生成成功，生成文件与 Rust 接口同步 |
| `cargo clippy -- -D warnings` | ✅ 通过 |
| Rust 测试 | ✅ 99 passed，7 ignored |
| `dart analyze --fatal-infos` | ✅ 通过 |
| Flutter 测试 | ✅ 26 passed |

历史 import、FRB 类型构造和 Widget fixture 断裂已处理，不再作为未来 Phase 待办。
后续新增或修改功能必须同步维护对应测试；CI 与 Android/iOS 真机回归仍按各自阶段验收。

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
