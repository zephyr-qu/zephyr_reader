# zs 工作日志

## 2026-07-13

### Phase 7（暂停）

- 完成了：去 spike 命名、ADR/Phase 注释清理、Rust 死代码整肃、PackedPage↔PageDescriptor 合并、typeset_calibrator 死函数清理、api/types.rs 删除、compute_config_hash 删除、core.rs→reader.rs 重命名
- 未完成（P8 合并后继续）：`buildTypesetConfig` 的 `calibration` 参数残留、`TODO(p4-5)` 双语 auto-fetch 等零星清理
- 当前分支：phase/7-cleanup-redundant-code（已提交）
- 待 P8 完成后再合并到 master

### Phase 9（2026-07-14 ~ 至今）

#### 9-A：API 层薄封装化 ✅

- 15 个 api/*.rs 全部改造，创建/补齐 9 个 domain service.rs
- 修复 flutter_rust_bridge.yaml，FRB codegen 重新生成成功
- 提交：`b59cec7`

#### Flutter import 路径修复 ✅

- 完成 79 处 `library/models.dart` 等错误路径的批量替换
- 修复 18 处 `reader/content_ir.dart` → `pipeline/types.dart`
- 文件已改，待统一提交

#### Task #2：PaginationSession 接口简化 ✅

- 假抽象类已合并到具体实现，DI 工厂已删除
- 属于之前已经完成但 ROADMAP 未标记的工作

#### Task #3：ChapterPaginationMode.plainText 死变体删除 ✅

- 枚举定义已不再生成（FRB 不输出）
- `NextChapterStaging.paginationMode` 字段已删除
- `ReaderRenderDataSource.sessionMode` getter 已删除
- 生产代码 3 处残留引用已清理
- ROADMAP 已更新标记已完成

#### Task #4：LINE_BREAKS_STORE 行断点缓存评估 ✅

- 经调研，该缓存物已在 Phase 8 删除（`line_breaking.rs` + `char_width.rs` 均无）
- Flutter 侧 `TextPainter` 完成所有断行
- ROADMAP 标记已完成

#### Task #1：IR 结构优化 + 纯 Dart 化 ✅

- 创建 `lib/features/reader/data/ir_types.dart`
- 纯 Dart 类：`ReaderIrBlock`、`ReaderInlineRun`、`ReaderChapterIr` 等
- `convertChapterIrFromFrb()` 边界转换函数
- RustChapterContentRepository 中 FRB 结果立即转换
- 25+ 消费者文件 import 从 `pipeline/types.dart` 切到 `ir_types.dart`
- `ReaderIrBlockLayout` 保留在 `packed_page.dart`
- 静态工具方法从 `IrReaderIrBlock` 迁入 `ReaderIrBlock` 类
- 生产代码零编译错误

#### Phase 9 完成（2026-07-15）

- 全部 7 个子任务已完成/评估
- commit `01ec593`
- 已合并到 master
- 新分支 `phase/10-reader-engine` 已创建

### 决策记录

**Phase 19 = 测试全面修复**（2026-07-15）

鉴于 Phase 9 以来多次目录重组导致跨层测试大面积断裂，
决定将测试修复集中到 Phase 19 统一处理。
其余阶段仅在小改动时顺手修，不作为优先级。

- ROADMAP.md 已更新：Phase 19 从 TBD 改为测试修复
- 修复范围包括：Rust 集成测试 import、Dart FRB 引用、Widget 测试构造参数

### Phase 10 补丁 + Phase 11-A 前 3 项（2026-07-16）

#### 4 个假抽象接口清理 ✅

- `ProgressRepository` + `ReaderRenderDataSource` + `ChapterContentRepository` + `BilingualReaderDelegate` 全部合并到具体类
- 删除 4 个旧文件，更新 DI 配置
- 提交 `a8638cd`

#### ROADMAP 更新 ✅

- Phase 10 项 7（ReaderRepository 删除）状态从 ❌ 改为 ✅
- Phase 10 项 8（假抽象接口）状态从 ❌ 改为 ✅
- Phase 11 重写：分为 Flutter 收尾（A）+ Rust 重构（B）
- Phase 13 移除已迁移到 Phase 11 的项

#### Phase 11-A1：engine config 迁移 ✅

- `ReaderConfig`、`ReaderTypographyDefaults`、`ReadingModeUtils`、`LanguageType`、`ReaderNotice` 五文件从 `features/reader/domain/config/` 迁至 `reader_engine/shared/config/`
- 更新 39 个文件 import 路径
- 提交 `1ff046b`

#### Phase 11-A2：类型搬迁 ✅

- `ChapterContentRepository` → `reader_engine/data/`
- `NextChapterStaging` → `reader_engine/shared/`
- `PaginationEngine` 静态工具重命名为 `PaginationUtils` → `reader_engine/pagination/engine_utils.dart`
- `PaginationViewportIndex` → `reader_engine/pagination/viewport_index.dart`
- `PageInfo` → `reader_engine/shared/`
- 提交 `1ff046b`

#### Phase 11-A3：删除 ReaderRenderDataSource ✅

- 纯委托类 11KB 删除，所有消费者直接持有 `ChapterContentRepository` + `PaginationSession`
- `reader_engine/` 现在 **zero imports from `features/reader/`** ✅
- 提交 `d5901d1`

#### 待办：A4 PaginationSession 生命周期统一

- 推迟到下一 session

### Phase 8（开始于 2026-07-13）

- 滚动模式 Flutter 化：用 IR 统一 scroll 和分页渲染路径
- 目标：删除 `get_epub_chapter_rich_content`、`TypesetConfig` FRB、`RichParagraph` 全链路
- 分支：phase/8-scroll-flutter-migration

### Phase 13 核心架构审查（2026-07-18）

审查结论：核心架构方向正确，不需要推倒重来。但必须先解决 source graph 污染和几个真实竞态。

**发现的 P0 问题：**
- DI config 仍引用已移走的 piolium 证据文件 → 编译错误
- next/prev staging 共享同一个 _stagingGen → 双向预取互相取消
- 视口尺寸回传已断开 → session 一直使用 estimated height

**P1 问题：**
- scroll fetch 会污染当前章 IR
- scroll 进度被保存成 100%（pageIndex 泄漏）
- EPUB 嵌套图丢弃、大 HTML 字节切片可切断标签
- 图片同步 FFI 可能卡顿（Future.microtask 不隔离）

**P1-P2 问题：**
- ADR-018 未完成：LayoutSnapshot→PagePlan→PackedPage 两套页模型共存
- PagePlan 和 PackedPage 都通不过 deletion test

**Phase 13 重排后的执行顺序：**
N0A → N0B → N2A → N2B → N3 → N4 → N1/N5

**当前预清理阶段（N0A）：**
- 净化 source graph（piolium 污染）
- 重新生成 DI/FRB
- 增加 source-root gate

来源：architecture-review-20260718-095042.html
