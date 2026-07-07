# 实现方案：Rust 行宽校准管道化（阶段 6 最终版）

## 核心：消灭 `full_line_width_px` 魔数

```
当前: full_line_width_px = (page_width_px - 2.0) × 0.97    ← 硬编码
目标: full_line_width_px = page_width_px × calibration.ratio  ← Flutter 实测
```

Flutter 用 `TextPainter` 测出真实有效行宽比例，通过已有 `TypesetCalibration` 管道传给 Rust。

## P0 范围（本 PR）

| # | 文件 | 改动 |
| --- | ------ | ------ |
| 1 | `typeset_calibrator.dart` | 新增 `measureEffectiveLineWidthRatio()` |
| 2 | `typeset_calibrator.dart` | `CalibrationData` + `effectiveLineWidthRatio` 字段（3 构造点） |
| 3 | `typeset_calibrator.dart` | `calibrationToRust` 直传 ratio |
| 4 | `typeset_calibrator.dart` | `buildTypesetConfig` 注入 ratio |
| 5 | `rust/.../typeset.rs` | `TypesetCalibration` + `effective_line_width_ratio` |
| 6 | `rust/.../block_paginator.rs` | 删除 `SAFETY_MARGIN_PX`/`LINE_WIDTH_SAFETY_RATIO`，用校准值 |
| 7 | `rust/.../char_width.rs` | 测试更新 |
| 8 | `rust/.../block_paginator.rs` | 测试更新 (~3 处) |
| 9 | `rust/tests/pagination_session_test.rs` | 测试更新 (~2 处) |
| 10 | `rust/tests/unit_text_test.rs` | 测试更新 (~1 处) |
| 11 | `test/.../typeset_calibrator_test.dart` | 测试更新 (~6 处) |
| 12 | FRB generate | 重新生成 |
| 13 | `paginated_page_viewport.dart` | 补 `ClipRect` 防御线 |

## 延后到独立 PR 的

- `_measureWidth` ParagraphBuilder → TextPainter 统一栈（letterSpacing=0 时不影响字宽测量）
- `line_height_px` 实测（`forceStrutHeight` 已保证精确）
- `LayoutFingerprint` 本地缓存
- 强制"测完再 paginate"时序（当前已满足）

## 验收

| # | 检查项 | 方法 |
| --- | -------- | ------ |
| 1 | `cargo check` / `cargo clippy -- -D warnings` | 零警告 |
| 2 | `cargo test` | 全绿 |
| 3 | `dart analyze --fatal-infos` | 零警告 |
| 4 | `flutter test test/features/reader/typeset_calibrator_test.dart` | 通过 |
| 5 | `[LineWidthCalib] ratio=0.XXX` 日志 | 非 0.97 |
| 6 | 页面内不可滑动 | 手动验证 |
| 7 | 末页内容完整 | 手动验证 |
