# 实施计划：修复阅读器滚动模式

## Step 1 — open() 预置 setDefaultPreferences（根因 A）

文件：`lib/features/reader/epub/readium_view_model.dart`

- `open()` 中，`reader.openPublication(uriPath)` 之前插入：

```dart
reader.setDefaultPreferences(
  EPUBPreferences(scroll: config.readingMode.value == ReadingMode.scroll),
);
```

- 验证：`open()` 现有 `readingMode.value = config.readingMode.value` 赋值保留。

## Step 2 — 删除 Flutter 手势跳章 hack（根因 B）

文件：`lib/features/reader/epub/readium_reader_content.dart`

1. 删除 `scrollPointerStartY` / `scrollStartProgression` useRef 定义
2. 删除 `Listener` 的 `onPointerDown` / `onPointerUp` / `onPointerCancel`（scroll 分支），
   或整个 Listener 若分页模式不再需要
3. 删除对 `vm.advanceFromScrollBoundary` / `vm.retreatFromScrollBoundary` 的调用

文件：`lib/features/reader/epub/readium_view_model.dart`

1. 删除 `advanceFromScrollBoundary` / `retreatFromScrollBoundary` / `_navigateScrollBoundary`
2. 检查 `_hrefPath` 引用，若无其他消费者则删除
3. 保留 `goLeft()` / `goRight()`（分页模式用）

## Step 3 — 分页模式手势保持原样

- 不动 `GestureDetector` 的 horizontal drag / tap / `isPagination` 分支

## Step 4 — 测试

文件：`test/features/reader/epub/readium_view_model_test.dart`

- 删除/改写 `advanceFromScrollBoundary` / `retreatFromScrollBoundary` 用例
- 新增：`open()` 按 readingMode 调 `setDefaultPreferences`（mock reader 断言）
- 新增：`setReadingMode(scroll)` 后 `_applyPreferences` prefs.scroll == true

文件：`test/features/reader/epub/readium_reader_content_test.dart`

- scroll 模式手势用例改为"滑动不触发跳章"

## Step 5 — 文档

- `discuss/adr/021-flutter-readium-migration.md` 补修订记录

## 质量门禁

1. `dart analyze --fatal-infos` 0 issue
2. `flutter test` 全绿
3. `cargo clippy -- -D warnings` + `cargo test` 不回归（本任务不触碰 Rust，跑一次确认）
4. Android 真机验证清单（design.md 尾部）
