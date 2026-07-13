# ADR-016 已删路径清单（P6–P8 完成）

P6（Dart 死路径）、P7（Rust 分页 FFI）、P8（校准环）已全部删除。
历史 DEAD PATH 标记自 `commit cdbd01b` 起不再存在。

| 层 | 路径 | 状态 |
| ---- | ------ | ------ |
| Rust 装箱 | `rust/src/reading/session.rs` → 已删 | ✅ P7.3 |
| Rust 分页 | `rust/src/reading/pagination.rs` → 已删 | ✅ P7.3 |
| FFI | `rust/src/api/core.rs` → 已拆 thin FFI | ✅ P7.2 |
| Dart session | `lib/.../rust_pagination_session.dart` → 已删 | ✅ P6.4 |
| 校准缓存 | `lib/.../layout_calibration_store.dart` → 已删 | ✅ P8.1 |
| 回传 | `repaginateAfterMetricsBackfeed` → 已删 | ✅ P6.3 |
| 回传 | `_captureMetricsBackfeed` → 已删 | ✅ P6.2 |

| 检索 | `ADR-016 DEAD PATH` → 已从源码中全部移除 |
| 产品路径 | `lib/features/reader/flutter_pagination/`（已产品化） |
| session 工厂 | 固定 `FlutterPaginationSession` |
| staging | 固定 `FlutterStagingPreloader` |
