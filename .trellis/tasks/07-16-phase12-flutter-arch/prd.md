# Phase 12 — Flutter 架构扁平化与阅读引擎独立

## Goal

将排版渲染核心从 `features/reader/` 中提取为独立 `lib/reader_engine/` 模块，消除不再需要的抽象层和中间人，降低 `features/reader/` 文件数从 108 降至 ~75 以下。

## 背景

Phase 9 在做 Flutter 原生 IR + import 路径修正时，发现 Flutter 侧的代码架构出现了明显冗余：

1. **5 个抽象接口各只有 1 个实现**（`ReaderRepositoryInterface`、`ChapterContentRepository`、`ProgressRepository`、`PaginationSession`、`ReaderRenderDataSource`），不存在多态场景
2. **`ReaderRepository` 是纯中间人**，几乎所有方法原样委托给 `_chapterContent` / `_session` / `_progress`
3. **排版渲染核心（~4,133 行/22 文件）混在 reader feature 的子目录中**，与 Rust `pipeline/` 模块不对称
4. **108 个文件集中在 `features/reader/` 下**，部分目录层级与功能边界不符

## 原则

1. **不增加新抽象层** — 删除假接口，保留必要真实接口
2. **引擎独立** — `reader_engine/` 模块不依赖 FRB、不依赖读者页编排
3. **消费方简化** — reader feature 直接调用引擎，不经过 `ReaderRepository` 中间人
4. **保持常规** — 不改变命名风格、不做不必要的大范围 rename

## 架构决策

### ADR-017：Flutter 阅读排版渲染引擎

**目录结构**：

```
lib/reader_engine/
  pagination/
    engine.dart              — PaginationEngine 类
    session.dart             — FlutterPaginationSession
    block_paginator.dart     — FlutterBlockPaginator
    staging_preloader.dart   — FlutterStagingPreloader
    staging_store.dart       — PaginationStagingStore
    packed_page.dart         — PackedPage, PackedBlockSlice
    viewport_metrics.dart    — PaginationViewportMetrics
    slice_height.dart        — 高度计算工具
    slice_rich_spans.dart    — TextSpan 转换

  scroll/
    engine.dart              — ScrollEngine 类
    ir_block_list.dart       — IR → TextSpan widget 构建
    mode_renderer.dart       — ScrollModeRenderer widget

  rendering/
    paginated_page_viewport.dart
    paginated_renderer.dart
    block_page_content.dart
    page_turn_shell.dart
    page_curl_widget.dart
    reader_render_config.dart
    ir_text_block_style.dart
    highlight_painter.dart
    find_render_box.dart
    image_cache.dart
    line_break_extractor.dart
    rich_text_converter.dart

  shared/
    types.dart
    constants.dart

  engine.dart               ← 库入口 barrel export
```

### ADR-018：PaginationEngine + ScrollEngine 分开

| 引擎 | 状态 | 生命周期 | 导出 |
| ------ | ------ | --------- | ------ |
| `PaginationEngine` | 有状态 | create session → use → dispose | `pagination/engine.dart` |
| `ScrollEngine` | 无状态 | 工厂/工具方法 | `scroll/engine.dart` |

### ADR-019：删除假抽象接口 + ReaderRepository 中间人

### ADR-020：合并 domain 层

## 任务清单

| # | 优先级 | 项 | 说明 |
| --- | -------- | ----- | ------ |
| 1 | **P0** | 创建 `lib/reader_engine/` 目录结构 | 按上述结构建空文件 |
| 2 | **P0** | 移动文件到新位置 | `core/reader_engine/` → `lib/reader_engine/` |
| 3 | **P0** | 更新所有 import 路径 | 所有 `core/reader_engine/` 引用改为 `reader_engine/` |
| 4 | **P1** | 删除 `ReaderRepository` 和假抽象接口 | ADR-019 |
| 5 | **P1** | 合并 `core/domain/` 和 `domain/` | ADR-020 |
| 6 | **P2** | 合并小文件 | `features/reader/` 从 108 降至 ~75 |
| 7 | **P2** | DI 注册清理 | 移除 `@Injectable(as: ...)` 桩 |
| 8 | **P2** | 同步 Rust 侧 `BlockStyle` 抽离 | 痛点 1-2 |

## 验收标准

- [ ] `flutter analyze --fatal-infos` 零错误
- [ ] `cargo clippy -- -D warnings` 零告警
- [ ] 阅读器 scroll 模式功能正常
- [ ] 阅读器 pagination 模式功能正常
- [ ] 换章 staging 预取正常
- [ ] `features/reader/` 文件数从 108 降至 ~75 以下
- [ ] `reader_engine/` 不引用 `features/reader/` 中的任何符号
- [ ] 无 `ReaderRepositoryInterface` 等已删除类型残留
