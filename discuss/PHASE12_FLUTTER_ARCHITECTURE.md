# Phase 12 — Flutter 架构扁平化与阅读引擎独立

> 讨论时间：2026-07-15  
> 参与者：zs  
> 来源：Phase 9 进行中的架构复盘讨论

---

## 动机

Phase 9 在做 Flutter 原生 IR + import 路径修正时，发现 Flutter 侧的代码架构出现了明显冗余：

1. **5 个抽象接口各只有 1 个实现**（`ReaderRepositoryInterface`、`ChapterContentRepository`、`ProgressRepository`、`PaginationSession`、`ReaderRenderDataSource`），不存在多态场景
2. **`ReaderRepository` 是纯中间人**，几乎所有方法原样委托给 `_chapterContent` / `_session` / `_progress`
3. **排版渲染核心（~4,133 行/22 文件）混在 reader feature 的子目录中**，与 Rust `pipeline/` 模块不对称
4. **108 个文件集中在 `features/reader/` 下**，部分目录层级与功能边界不符

## 目标

将排版渲染核心从 reader feature 中提取为独立模块，同时消除不再需要的抽象层和中间人。

### 核心原则

1. **不增加新抽象层** — 删除假接口，保留必要真实接口
2. **引擎独立** — `reader_engine/` 模块不依赖 FRB、不依赖读者页编排
3. **消费方简化** — reader feature 直接调用引擎，不经过 `ReaderRepository` 中间人
4. **保持常规** — 不改变命名风格、不做不必要的大范围 rename

---

## 架构决策

### ADR-017：Flutter 阅读排版渲染引擎

**状态**：已接受 ✅

**目录名**：`lib/reader_engine/`

**内部结构**：

```
lib/reader_engine/
  pagination/               ← PaginationEngine（有状态）
    engine.dart               — PaginationEngine 类
    session.dart              — FlutterPaginationSession（内部实现）
    block_paginator.dart      — FlutterBlockPaginator（内部实现）
    staging_preloader.dart    — FlutterStagingPreloader
    staging_store.dart        — PaginationStagingStore
    packed_page.dart          — PackedPage, PackedBlockSlice
    page_curtain.dart         — 进度/窗口管理
    viewport_metrics.dart     — PaginationViewportMetrics
    slice_height.dart         — 高度计算工具
    slice_rich_spans.dart     — TextSpan 转换
    
  scroll/                   ← ScrollEngine（无状态/工厂）
    engine.dart               — ScrollEngine 类
    ir_block_list.dart        — IR → TextSpan widget 构建
    mode_renderer.dart        — ScrollModeRenderer widget

  rendering/                ← 通用的渲染 widget（两个模式共用）
    paginated_page_viewport.dart
    paginated_renderer.dart
    block_page_content.dart
    page_turn_shell.dart
    page_curl_widget.dart
    reader_render_config.dart
    ir_text_block_style.dart
    highlight_painter.dart
    find_render_box.dart
    image_cache.dart          — epub_block_image_cache
    line_break_extractor.dart — 行断点提取
    rich_text_converter.dart

  shared/                   ← 两个引擎公用的类型和常量
    types.dart                — PackedPage、PackedBlockSlice 等（从 reader_engine/ 顶层移入）
    constants.dart            — firstScreenMaxChars 等
    reader_notice.dart        — 通知类型

  engine.dart               ← 库入口 barrel export
```

### ADR-018：PaginationEngine + ScrollEngine 分开（Option B）

**状态**：已接受 ✅

不提供一个 `ReaderEngine` 上帝类，而是两个独立的引擎：

| 引擎 | 状态 | 生命周期 | 导出 |
| ------ | ------ | --------- | ------ |
| `PaginationEngine` | 有状态 | create session → use → dispose | `pagination/engine.dart` |
| `ScrollEngine` | 无状态 | 工厂/工具方法 | `scroll/engine.dart` |

**理由**：

- 分页和滚动没有共享运行时状态
- 生命周期不同：分页由 orchestrator 管理，滚动随 widget 树重建
- 消费方不同：`PaginationCoordinator` 关心分页，`ReaderContentArea` 只关心滚动
- 未来其他功能（如搜索预览）可能只需要滚动引擎

### ADR-019：删除 5 个假抽象接口 + ReaderRepository 中间人

**状态**：草案

需要删除：

| 文件 | 理由 |
| ------ | ------ |
| `core/domain/reader_repository_interface.dart` | 唯一实现 `ReaderRepository`，所有方法纯委托 |
| `core/domain/chapter_content_repository.dart` | 唯一实现 `RustChapterContentRepository` |
| `core/domain/progress_repository.dart` | 唯一实现 `RustProgressRepository`，仅 1 个方法 |
| `core/domain/pagination_session.dart` | 唯一实现 `FlutterPaginationSession` |
| `core/data/reader_render_data_source.dart` | 唯一实现 `ReaderRepository` |
| `data/repositories/rust_reader_repository.dart` | 中间人，删除后调用方直接使用具体类 |
| `core/data/pagination_session_factory.dart` | 不再需要，session 由 PaginationEngine 管理 |

### ADR-020：合并 `core/domain/` 和 `domain/` 两层

**状态**：草案

```
lib/features/reader/domain/     ← 统一 domain 层
  config/                       ← ReaderConfig、ReaderTypographyDefaults
  model/                        ← PageInfo、FontInfo
  service/                      ← TtsService、CustomFontService
  repository/                   ← 保留的必要仓库接口（如果有）
```

---

## 任务清单

| # | 优先级 | 项 | 说明 |
| --- | -------- | ----- | ------ |
| 1 | **P0** | 创建 `lib/reader_engine/` 目录结构 | 按上述结构建空文件 |
| 2 | **P0** | 移动 pagination 文件 | `flutter_pagination/` → `reader_engine/pagination/` |
| 3 | **P0** | 移动 scroll 文件 | 相关文件 → `reader_engine/scroll/` |
| 4 | **P0** | 移动 rendering 文件 | `rendering/` → `reader_engine/rendering/` |
| 5 | **P0** | 移动 shared 类型 | `packed_page.dart`、`pagination_params.dart` 等 |
| 6 | **P1** | 实现 `PaginationEngine` 类 | 封装 `FlutterPaginationSession` 创建/复用/释放 |
| 7 | **P1** | 实现 `ScrollEngine` 类 | `buildScrollView(ir, params)` 工厂方法 |
| 8 | **P1** | 更新 reader 消费方 import | 更新所有 import 路径 |
| 9 | **P1** | 删除 `ReaderRepository` 中间人 | 调用方直接使用 PaginationEngine + RustChapterContentRepository |
| 10 | **P2** | 删除 5 个假抽象接口 | 接口和实现合并 |
| 11 | **P2** | 合并 `core/domain/` 和 `domain/` | 统一 domain 目录 |
| 12 | **P2** | 合并小文件 | 将 ~108 文件合并到 ~65-75 个 |
| 13 | **P2** | DI 注册清理 | 移除 `@Injectable(as: ...)` 桩 |
| 14 | **P3** | 清理 `ScrollModeRenderer` 回退的 dead code | Phase 8 遗留 |

## 验收标准

- [ ] `flutter analyze --fatal-infos` 零错误
- [ ] `cargo clippy -- -D warnings` 零告警（Rust 无变化）
- [ ] 阅读器 scroll 模式功能正常
- [ ] 阅读器 pagination 模式功能正常
- [ ] 换章 staging 预取正常
- [ ] `features/reader/` 文件数从 108 降至 ~75 以下
- [ ] `reader_engine/` 不引用 `features/reader/` 中的任何符号
- [ ] 无 `ReaderRepositoryInterface` 等已删除类型残留

## 不做

- 不引入新的架构抽象（UseCase、BLoC 等）
- 不改 Rust 侧代码
- 不改 UI 交互行为
- 不改命名规范/格式化

---

## Phase 9 IR 类型 Flutter 侧消费反馈

在将 `ContentBlock`/`RichTextSpan`/`BlockPlainRange` 扁平成 `ReaderIrBlock` 后，
Flutter 侧使用以下痛点，**可以在当前 Phase 9 反推 Rust 侧修改**：

### 痛点 1：`ReaderIrBlock` 构造负担过重 🎯

当前 `ReaderIrBlock` 有 **14 个 required named parameter**（FRB 映射后 scalar/Option 都变成 required），
test fixture 构造时即使只关心 style 也要填全部 14 个：

```dart
// 当前：只想做个默认 style 传给 PackedBlockSlice
const _defaultStyle = ReaderIrBlock(
  kind: ReaderIrBlockKind.text,          // ← 必填
  plainStart: 0, plainLen: 0,             // ← 对 style 无意义
  text: '', runs: [],                      // ← 对 style 无意义
  isHeading: false, headingLevel: 0,       // ← 风格字段
  textIndentEm: null, marginTopEm: null,   // ← 风格字段
  marginBottomEm: null, textAlign: null,   // ← 风格字段
  fontSize: null,                           // ← 风格字段
  imageAssetId: null, imageAlt: null,      // ← 对 style 无意义
  imageIntrinsicWidth: null,               // ← 对 style 无意义
  imageIntrinsicHeight: null,              // ← 对 style 无意义
);
```

**建议反推 Rust：** 将风格字段独立为 `BlockStyle` struct，`ReaderIrBlock` 引用它：

```rust
pub struct BlockStyle {
    pub is_heading: bool,
    pub heading_level: u8,
    pub text_indent_em: Option<f32>,
    pub margin_top_em: Option<f32>,
    pub margin_bottom_em: Option<f32>,
    pub text_align: Option<String>,
    pub font_size: Option<f32>,
}

pub struct ReaderIrBlock {
    pub kind: ReaderIrBlockKind,
    pub plain_start: u32,
    pub plain_len: u32,
    pub text: String,
    pub runs: Vec<ReaderInlineRun>,
    pub style: BlockStyle,                // ← 独立引用
    pub image_asset_id: Option<String>,
    pub image_alt: Option<String>,
    pub image_intrinsic_width: Option<u32>,
    pub image_intrinsic_height: Option<u32>,
}
```

测试侧可以这样 const 构造：

```dart
const _defaultStyle = BlockStyle(
  isHeading: false,
  headingLevel: 0,
  textIndentEm: null,
  marginTopEm: null,
  marginBottomEm: null,
  textAlign: null,
  fontSize: null,
);
```

仅需 **7 个参数**，且每个参数都对 style 有意义。

### 痛点 2：`PackedBlockSlice.style` 类型不合适 🎯

`packed_page.dart` 中 `PackedBlockSlice.text` 的 `style` 参数类型是 `ReaderIrBlock?`，
但这个对象里的 `text`, `runs`, `plain_start`, `plain_len`, `kind`, `image_*` 等字段
对 style 语义是**无意义的**。

改用 `BlockStyle?`（从新的独立 struct 映射来）语义更清晰，且不会把 test 玩家带偏。

### 痛点 3：`when()` pattern matching 缺失 📝

旧 `ContentBlock` 有 freezed 风格的 `when()` 方法，提供 exhaustiveness checking。
新扁平类型用 `block.kind == ReaderIrBlockKind.image`，容易漏分支。

Flutter 侧可以自己补个 extension 方法：

```dart
extension ReaderIrBlockX on ReaderIrBlock {
  T when<T>({required T Function() text, required T Function() image}) =>
    switch (kind) { ReaderIrBlockKind.text => text(), ReaderIrBlockKind.image => image() };
}
```

这不是 Rust 侧问题，Flutter 侧加个 extension 即可。可以用一个 commit 做。

### 总结

| # | 痛点 | 等级 | 是否反推 Rust | 修法 |
| --- | ----- | ---- | ------------- | ---- |
| 1 | `ReaderIrBlock` 14 参数构造 | P1 | ✅ 是 | Rust 侧抽 `BlockStyle` struct |
| 2 | `PackedBlockSlice.style` 类型 | P1 | ✅ 是 | 同上，类型改为 `BlockStyle?` |
| 3 | 缺少 `when()` exhaustiveness | P3 | ❌ 否 | Flutter 侧加 extension |

反推 Rust 改造可在 Phase 9 当前分支做，改动范围可控：新增 struct + FRB codegen 重跑 + Flutter 侧适配。
