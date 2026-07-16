# 阅读核心路线图（与边界 v1.1 绑定）

> **当前阶段 = Phase 9**（Rust 目录重组 + FRB import 修复 ✅ / 后续优化待执行）
> **Phase 0-8** 已完成 ✅
> **Phase 9** 进行中 🔄（Rust 目录重组 + API 层薄封装化）
> **下一阶段**：Phase 10 TXT 章节检测可配置化

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
| 0 | **P0** | **Rust 目录重组** | ✅ 已完成 — API 瘦身 + Flutter import 修复 |
| 1 | **P1** | **IR 结构优化 + 纯 Dart 化**（两项合并） | ✅ 已完成 — 创建 `ir_types.dart`，`ReaderChapterIr`/`ReaderIrBlock`/`ReaderInlineRun` 等为纯 Dart 类，`RustChapterContentRepository` 边界处 `convertChapterIrFromFrb` 转换 |
| 2 | **P1** | **`PaginationSession` 接口简化** | ✅ 已完成 — 假抽象类已合并，DI 工厂已删除 |
| 3 | **P2** | **`ChapterPaginationMode.plainText` 死变体删除** | ✅ 已完成 — 枚举及字段已删除，残留测试引用待清理 |
| 4 | **P2** | **`LINE_BREAKS_STORE` 行断点缓存评估** | ✅ 已完成 — `line_breaking.rs`/`char_width.rs` 已在 Phase 8 删除，Flutter 侧 `TextPainter` 完成所有断行 |
| 5 | **P2** | **CJK 标点挤压引擎** | ❌ 不实现 — ADR-013 已明确跳过，收益低于复杂度 |
| 6 | **P3** | **`get_chapter` 退化备选移除评估** | ✅ 评估完成 — 暂保留，IR 路径未覆盖全部场景 |

---

## Phase 10 — Flutter 架构扁平化与阅读引擎独立（规划中）

**目标**：将排版渲染核心从 reader feature 提取为独立 `reader_engine/` 模块，
消除假抽象接口和中间人。

**讨论**：`discuss/PHASE12_FLUTTER_ARCHITECTURE.md`

### 任务清单

| # | 优先级 | 项 | 说明 |
| --- | -------- | ----- | ------ |
| 1 | **P0** | 创建 `lib/reader_engine/` 目录结构 | 按 ADR-017 结构建空文件 |
| 2 | **P0** | 移动 pagination 文件 | `flutter_pagination/` → `reader_engine/pagination/` |
| 3 | **P0** | 移动 scroll 文件 | 相关文件 → `reader_engine/scroll/` |
| 4 | **P0** | 移动 rendering 文件 | `rendering/` → `reader_engine/rendering/` |
| 5 | **P1** | 实现 `PaginationEngine` 类 | 封装 `FlutterPaginationSession` 创建/复用/释放 |
| 6 | **P1** | 实现 `ScrollEngine` 类 | `buildScrollView(ir, params)` 工厂方法 |
| 7 | **P1** | 删除 `ReaderRepository` 中间人 | 调用方直接使用 PaginationEngine + RustChapterContentRepository |
| 8 | **P2** | 删除 5 个假抽象接口 | 接口和实现合并 |
| 9 | **P2** | 合并 `core/domain/` 和 `domain/` | 统一 domain 目录 |
| 10 | **P2** | 合并小文件 | 将 ~108 文件合并到 ~65-75 个 |

### 不做

- 不引入新的架构抽象（UseCase、BLoC 等）
- 不改 Rust 侧代码
- 不改 UI 交互行为

---

## Phase 11 — 业务下沉和业务简化（规划中）

**目标**：两条纲领，Phase 11 启动时扫描审查。

**讨论**：`discuss/PHASE11_BUSINESS_SIMPLIFICATION.md`

### 判断框架

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

### 启动方式

Phase 11 启动时对整个代码库做一次 `业务下沉 + 简化` 审查扫描，
使用判断框架列出待整改项，然后逐一整改。

---

## Phase 12 — TXT 章节检测正则可配置化（规划中）

**目标**：将硬编码在 `chapter_detect.rs` 中的四组章节检测正则改为可配置，
支持用户自定义章节标题模式，覆盖更多网文/轻小说格式。

**讨论**：`discuss/PHASE10_CHAPTER_DETECT_CONFIG.md`

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

---

## Phase 13 — 核心收束扫尾（规划中）

**目标**：给 Phase 9-12 的架构大修做竣工验收，清理遗留碎片，确认核心功能 99% 可用。

### 工作项

| # | 项 | 说明 |
| --- | ----- | ------ |
| 1 | 死代码清扫 | 重构后老接口、旧导入、废弃文件、未用依赖 |
| 2 | `#[allow(...)]` 审计 | 确认重构过程中加的 suppress 不再需要 |
| 3 | 架构一致性检查 | API 薄封装、reader_engine 不反引用、假接口已删 |
| 4 | 核心链路可用确认 | 开书画笔记→存进度→关 app→恢复→搜索 |
| 5 | 边界场景验证 | 大 TXT（百万字）、含图 EPUB、切换排版立刻生效 |
| 6 | sled KV 存储评估 | 查 sled 消费者（当前仅 IR 缓存 1 个），<br>≤1 个则迁到 SQLite 或 redb，删 sled + bincode 依赖 |
| 7 | 工具链确认 | `cargo clippy -D warnings`、`flutter analyze --fatal-infos`、FRB codegen |

### 不做

- ❌ 不加新功能
- ❌ 不写大量单元测试（等 Phase 17）
- ❌ 不做性能调优
- ❌ 不改 UI/UX 细节

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
