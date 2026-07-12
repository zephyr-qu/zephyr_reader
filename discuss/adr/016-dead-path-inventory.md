# ADR-016 待删路径清单（stage6 标记）

在合入 `explore/flutter-side-pagination`（`308e706`）之前，于本分支标注以下路径为 **DEAD PATH**。  
行为未改；仅禁止继续扩展。合入后关主路径并删 explore 旁路命名。

| 层 | 路径 | 标记点 |
|----|------|--------|
| Rust 装箱 | `rust/src/text/block_paginator.rs` | 模块头 |
| Rust session | `rust/src/reading/session.rs` | `create_pagination_session` / `apply_session_calibration` |
| FFI | `rust/src/api/core.rs` | 同上 |
| Dart session | `lib/.../rust_pagination_session.dart` | 类文档 |
| 校准测量 | `lib/.../typeset_calibrator.dart` | 库头 |
| 校准缓存 | `lib/.../layout_calibration_store.dart` | 类文档 |
| 回传 | `pagination_coordinator.repaginateAfterMetricsBackfeed` | 方法文档 |
| 回传 | `chapter_load_orchestrator._captureMetricsBackfeed` | 方法文档 |

| 检索 | `ADR-016 DEAD PATH` |
| 产品路径 | `lib/features/reader/flutter_pagination/`（已去 spike 命名） |
| session 工厂 | 固定 `FlutterPaginationSession` |
| staging | 固定 `FlutterStagingPreloader` |
