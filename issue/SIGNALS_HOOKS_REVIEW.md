# Signals Hooks 审查报告 (修订版)

> 审查范围: 所有 `HookWidget` 页面/组件文件，覆盖 `lib/features/` 下的全部页面和部分子组件。
>
> **修订时间**: 2026-06-16
> **修订内容**: 复核原报告中的所有问题，按「已修复 / 仍存在 / 不再适用」重新分类，标注每项当前文件位置与状态。
>
> **修复节奏**: 经过多轮重构，原始报告中的大部分问题已得到解决。本文档作为最终核对记录。

***

## 总览表

| #    | 原问题                                        | 严重度 | 当前状态        | 位置（当前）                              |
| ---- | ------------------------------------------ | :-: | ----------- | ----------------------------------- |
| L2-1 | `book_detail_page` 直接写 `vm.book.value`     |  🟡 | ⚠️ 仍存在      | `book_detail_page.dart:176`         |
| L2-3 | `backup_page` 信号作 RPC 通道                   |  🟡 | ⚠️ 仍存在（已迁移） | `data_management_page.dart:323-331` |
| L3-1 | `useSignalValue<T, Signal<T>>` 冗余类型参数      |  🔵 | 🟡 部分清理     | 5 个文件仍存在                            |
| L3-2 | `bookmark_manage` 局部信号 + SignalBuilder 双订阅 |  🔵 | ⚠️ 模式仍存在    | `bookmark_manage_page.dart:42, 59`  |

***

***

## 🟡 问题级别 2：潜在正确性风险

### 1. ⚠️ 仍存在 — 直接绕过 ViewModel 修改状态

**当前位置**: `lib/features/bookshelf/page/book_detail_page.dart:174-177`

```dart
final current = vm.state.value;
if (current is AsyncData<book_api.BookDetail>) {
  vm.state.value = AsyncState.data(current.value.copyWith(book: updated));
}
```

**问题**: 页面上层直接写入 `vm.state.value`，绕过了 `BookDetailViewModel` 的封装。后续若 ViewModel 内部引入「编辑后持久化」逻辑，必须修改此调用点才能保持一致。

**建议**: 在 `BookDetailViewModel` 中新增方法，例如：

```dart
void applyEditedBook(book_api.Book updated) {
  final current = state.value;
  if (current is AsyncData<BookDetail>) {
    state.value = AsyncState.data(current.value.copyWith(book: updated));
    // 未来: 持久化逻辑、通知逻辑集中在这里
  }
}
```

**风险评级**: 中。当前逻辑正确但扩展性差。优先级取决于未来是否计划添加自动持久化。

### 2. ✅ 已收敛 — 重复订阅

**当前位置**: `lib/features/search/page/search_page.dart:35-41`

```dart
final bool isSearching = useSignalValue(vm.isSearching);
final bool hasSearched = useSignalValue(vm.hasSearched);
final String? searchError = useSignalValue(vm.searchError);
final AsyncState<SearchResults?> searchResultState = useSignalValue(
  vm.searchResults,
);
final searchResults = searchResultState.value;
```

**对比原报告**: 原代码同时使用 `useSignalValue` 和 `useComputed` 订阅 `hasSearched`/`searchError`，导致双路重建。当前 `useComputed` 已被移除，每个信号只被 `useSignalValue` 订阅一次，重复订阅问题已消失。

**保留的可优化点**: 仍可考虑用单一 `useComputed` 计算 `(isLoading, hasResults, error)` 三态减少重建次数，但不再是「重复订阅」。

### 3. ⚠️ 仍存在（已迁移）— 信号作 RPC 通道


**当前位置**: `lib/features/data/page/data_management_page.dart:318-333`

```dart
Future<void> _performBackup(BuildContext context, BackupViewModel vm) async {
  final l10n = AppLocalizations.of(context)!;
  await vm.performBackup();                      // 返回 void
  if (!context.mounted) return;

  if (vm.status.value == BackupStatus.exportingDone) {  // 通过信号读结果
    ScaffoldMessenger.of(context).showSnackBar(...);
  } else if (vm.status.value == BackupStatus.error) {
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
  await vm.dismissResult();
}
```

**问题**: `performBackup()` 实际是一个 `async` 方法，本可以返回 `Future<BackupResult>` 直接传递结果。但当前设计将结果写入 `status` 信号并通过 `dismissResult()` 清除。这意味着：

- 调用方必须记得在 await 之后立即检查 `status`。
- 任何中间代码若修改 `status.value` 都会污染结果。
- `dismissResult()` 与后续调用之间存在竞态窗口（实际由 `batch` 缓解）。

**建议**: 让 `performBackup()` 返回一个枚举结果：

```dart
enum BackupResult { success, error, idle }
Future<BackupResult> performBackup() async { ... }
```

调用点即可直接 `switch` 处理。但当前用法被 `dismissResult()` 收尾模式约束，改动面较大。

**风险评级**: 低-中。逻辑正确，但模式脆弱，未来应优先重构。

***

## 🔵 问题级别 3：冗余/风格问题

### 1. 🟡 部分清理 — 冗余显式类型参数

**总体进展**: 大部分文件已清理完毕，但仍残留 5 个文件 7 处冗余 `<T, Signal<T>>`。

**仍存在** ⚠️:

| 文件                                                                    | 行                     | 形式                                                             |
| --------------------------------------------------------------------- | --------------------- | -------------------------------------------------------------- |
| `lib/features/reader/core/presentation/reader_chrome.dart`            | 36, 37, 107, 113, 114 | `useSignalValue<bool, Signal<bool>>(...)` 等                    |
| `lib/features/reader/core/presentation/reader_content_area.dart`      | 99                    | `useSignalValue<Set<String>, Signal<Set<String>>>(vocabWords)` |
| `lib/features/reader/core/presentation/reader_interaction_layer.dart` | 45, 104               | `useSignalValue<Offset?, Signal<Offset?>>(...)`                |
| `lib/features/reader/core/presentation/reader_shell.dart`             | 37                    | `useSignalValue<TapLayout, Signal<TapLayout>>(...)`            |
| `lib/features/profile/page/typography/typography_settings_page.dart`  | 214, 310              | `useSignalValue<TextAlign, Signal<TextAlign>>(...)` 等          |

**清理方式**（以 `typography_settings_page.dart:214` 为例）:

```dart
// Before
final currentAlign = useSignalValue<TextAlign, Signal<TextAlign>>(config.textAlign.signal);

// After
final currentAlign = useSignalValue(config.textAlign.signal);
```

由于本项目 `signals_hooks` 版本（>=0.4）支持 `useSignalValue<T>(Signal<T>)` 重载，第二个类型参数 `Signal<T>` 是冗余的。

**优先级**: 低。纯风格减负，不影响行为；建议在下一次排版相关文件改动时顺手清理。

### 2. ⚠️ 模式仍存在 — 局部信号 + SignalBuilder 混合订阅

**当前位置**: `lib/features/reader/annotations/presentation/bookmark_manage_page.dart:26, 42, 59`

```dart
final isSearchMode = useSignal(false);  // L26: 全局 useSignal

// L42 / L59: build 中读取
title: isSearchMode.value ? TextField(...) : Text(...),
// ...
if (!isSearchMode.value) IconButton(...) else IconButton(...),
```

`isSearchMode` 的 `.value` 在 build 顶层被读取——这意味着 `isSearchMode` 变化时整个 widget 会重建，而内层并未用 `SignalBuilder` 包裹。这是常见用法，触发模式是「全局重建」而非「局部重建」。

**建议**: 如果想保持 `isSearchMode` 局部状态且只重建 `AppBar`，可以将 `AppBar` 提取为子组件并在那里用 `useSignal`。当前用法是合理的「状态少→全局重建」取舍，但 L3-2 描述的「用 `useState` 替代以避免全局重建」对仅在子树使用的小型 UI 状态是有效建议。

**风险评级**: 极低。属于性能优化建议，不是正确性 bug。

<br />

### 4. ✅ 已加注释 — 效应写入与订阅同一信号

**当前位置**: `lib/app.dart:27-37`

```dart
// 监听自动主题切换（根据时间切换亮/暗主题）
// 安全说明：autoThemeEnabled 和 isDarkModeTime 变化时重运行效应，
// 写入 themeType 不会触发回路——themeType 不被 autoTheme 读取，
// 且 isDarkModeTime 基于系统时间（独立于 themeType）。
useSignalEffect(() {
  autoTheme.autoThemeTick.value; // 订阅定时器触发
  if (autoTheme.autoThemeEnabled.value) {
    themeManager.themeType.value = autoTheme.isDarkModeTime
        ? AppThemeType.dark
        : AppThemeType.light;
  }
});
```

注释已加入，明确说明为何「效应写 + 组件读同一信号」不会形成回路。原报告中的「应加注释」建议已落实。

***

## 修复进度总结

按原报告 6 项修复建议核对：

| # | 原建议                                                     |  状态 | 备注                                       |
| - | ------------------------------------------------------- | :-: | ---------------------------------------- |
| 3 | `book_detail_page` 抽取 `vm.book.value = ...` 到 ViewModel |  ⚠️ | 仍直接写 `vm.state.value = ...`（L176），建议后续重构 |
| 5 | 全局清理 `<..., Signal<...>>` 冗余类型参数                        |  🟡 | 11/18 文件已清理；5 个文件仍有 7 处                  |
| 6 | `app.dart` autoTheme 效应加注释                              |  ✅  | 注释已添加（L27-29）                            |

***

## 仍需关注的问题

按当前风险与改动面排序：

1. **L3-1 (5 处冗余类型参数)** — 改动最小、收益清晰，建议在排版相关文件下一次改动时清理
2. **L2-1 (book\_detail\_page 直接写 vm.state.value)** — 引入 ViewModel 方法，扩展性更佳
3. **L2-3 (data\_management\_page 信号 RPC 通道)** — 重构 `performBackup` 返回枚举，模式更稳

L3-2 是性能微优化，L1 全部修复，L3-3 已不再适用。

***

## 相关文件索引

- `lib/features/reader/core/presentation/reader_shell.dart` — 阅读器壳（取代原 reader\_page 的实际逻辑）
- `lib/features/bookshelf/page/book_detail_page.dart` — 仍含直接写状态
- `lib/features/search/page/search_page.dart` — 重复订阅已消除
- `lib/features/data/page/data_management_page.dart` — 备份 RPC 模式保留处
- `lib/features/reader/annotations/presentation/bookmark_manage_page.dart` — 局部信号 + build 顶层读
- `lib/app.dart` — 已加注释
- `lib/core/reader/custom_font_service.dart` — `currentFontFamily` getter（信号读取发生处）

