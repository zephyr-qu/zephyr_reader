# 设计：修复阅读器滚动模式（章节内连续滚动 + 边界顺滑衔接）

## 目标行为

滚动模式（ReadingMode.scroll）下：

```
章节内部   → 原生 WebView 连续垂直滚动（scroll:true 必须从 WebView 创建起就生效）
章节边界   → 滚到当前资源末尾 → 触发原生 goForward() → 原生 goForwardVertical 判定
             nextProgression>=1.0 才加载下一章；否则仅 scrollToProgression 内部滚动
分页模式   → 保持现状（横向滑动 goLeft/goRight、tap 显隐、边缘点击）
```

不做：跨 spine 无缝连续滚动（原生 toolkit 官方不支持，ADR-021 已接受显式切换）。

## 根因回顾

| # | 根因 | 位置 |
|---|------|------|
| A | 原生 WebView 以分页模式创建（`_defaultPreferences` 恒 null，从不调 `setDefaultPreferences`），ready 后才热切 scroll，重建时机与 Flutter 手势竞争 | `readium_view_model.dart` open() / `readium_reader_content.dart` |
| B | Flutter `Listener` 手势 hack：垂直滑 ≥48px + 200ms 内 progression 未变 → `goToLocator` 硬跳章，抢在原生滚动前消费手势 | `readium_reader_content.dart` / `readium_view_model.dart` `_navigateScrollBoundary` |

## 方案

### Step 1：open() 时用 setDefaultPreferences 预置正确模式（根因 A）

`ReadiumViewModel.open()` 在 `reader.openPublication(uriPath)` 之前调用：

```dart
// 构造与 _applyPreferences 相同的最小 prefs，至少带上 scroll
reader.setDefaultPreferences(
  EPUBPreferences(
    scroll: config.readingMode.value == ReadingMode.scroll,
    // 其余字段可后续在 _applyPreferences 中完整应用
  ),
);
```

原理：`flutter_readium` 的 `ReadiumReaderWidget.initState` 读取
`_defaultPreferences?.scroll ?? false` 决定 `_scrollMode`，并把 `defaultPreferences`
作为 `creationParams.preferences` 传给原生创建 WebView。提前设置后：

- 原生 WebView **首次创建**即为正确布局（scroll 时 `Layout.SCROLLED` + 滚动 CSS 生效）
- 初始 Locator 定位基于正确布局
- `_markViewportReady` 之后的 `setEPUBPreferences` 变成"确认/补充"，不再承担"从分页翻到滚动"的重建

注意：`setDefaultPreferences` 是 FlutterReadium 单例的全局默认值，仅影响**之后**打开的
publication（`creationParams` 在 widget 创建时快照），不会影响当前已打开视图；每次 open
前按 `config.readingMode.value` 设置即可，无跨书污染。

### Step 2：删除 Flutter 手势跳章 hack（根因 B）

`readium_reader_content.dart`：

- 删除 scroll 模式的 `Listener(onPointerDown/onPointerUp/onPointerCancel)` 三个分支
- 删除 `scrollPointerStartY` / `scrollStartProgression` 两个 useRef
- 删除对 `vm.advanceFromScrollBoundary` / `vm.retreatFromScrollBoundary` 的调用

`readium_view_model.dart`：

- 删除 `advanceFromScrollBoundary` / `retreatFromScrollBoundary` / `_navigateScrollBoundary`
- 保留 `goLeft()`/`goRight()`（= `reader.goBackward`/`goForward`），分页模式横向手势继续用
- 删除后 `_hrefPath` 若仅被 `_navigateScrollBoundary` 使用则一并删除（检查引用）

边界衔接交给原生：用户滚到章节末尾继续拖 → 由原生 ViewPager/WebView 边缘行为或后续
手势映射到 `goForward()`。真机验证 scroll 模式滚到底的表现后，若原生不自动衔接，
再在 Flutter 侧加一个**轻量**边界信号（只在 `progression ≈ 1.0` 或 ≈0.0 时映射到
`goRight()`/`goLeft()`，不做 200ms 竞态检测）。

### Step 3：分页模式手势保持原样

`GestureDetector` 的 horizontal drag + tap 逻辑不动，`isPagination` 分支不动。

### Step 4：测试与文档

- 更新 `test/features/reader/epub/readium_view_model_test.dart`：
  - `advanceFromScrollBoundary`/`retreatFromScrollBoundary` 相关用例删除或改写
  - 新增：`open()` 会按 readingMode 调用 `setDefaultPreferences`
  - 新增：`setReadingMode(scroll)` 后 `_applyPreferences` 的 prefs 带 `scroll:true`
- 更新 `test/features/reader/epub/readium_reader_content_test.dart`：
  - scroll 模式手势用例改为"不再触发跳章"
- ADR-021 补一条修订记录：滚动模式实现从"Flutter 手势跳章"改为"原生 scroll + 原生
  goForward 边界衔接"

## 风险与回退

- **原生 scroll 滚到底是否自动进下一章**：原生 `goForwardVertical` 是显式调用路径；
  若用户"滚到底继续拖"无任何原生触发，需 Step 2 的轻量边界信号兜底。先真机验证再定。
- **setDefaultPreferences 副作用**：全局默认值，若后续有其他 publication 打开路径
  不经过 open()，可能读到旧 scroll 值；全项目仅 ReadiumViewModel.open 一条打开路径（已确认）。
- 回退：若改动导致分页回归，仅还原 Step 1/2 对应 diff，不连带其他。

## 验证清单（真机）

1. scroll 模式打开书：章节内可连续滚动，不跳章
2. scroll 模式滚到章尾：进入下一章（自动 or goForward 路径）
3. 滚动↔分页切换：布局立即正确，无"分页布局残留"
4. 分页模式：左右滑动/边缘点击/tap 控制栏全部正常
5. Locator 恢复：两种模式重开书位置正确
