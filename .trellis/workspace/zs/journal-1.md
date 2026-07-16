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

### 决策记录

**Phase 19 = 测试全面修复**（2026-07-15）

鉴于 Phase 9 以来多次目录重组导致跨层测试大面积断裂，
决定将测试修复集中到 Phase 19 统一处理。
其余阶段仅在小改动时顺手修，不作为优先级。

- ROADMAP.md 已更新：Phase 19 从 TBD 改为测试修复
- 修复范围包括：Rust 集成测试 import、Dart FRB 引用、Widget 测试构造参数

### Phase 8（开始于 2026-07-13）

- 滚动模式 Flutter 化：用 IR 统一 scroll 和分页渲染路径
- 目标：删除 `get_epub_chapter_rich_content`、`TypesetConfig` FRB、`RichParagraph` 全链路
- 分支：phase/8-scroll-flutter-migration
