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
| L2-1 | `book_detail_page` 直接写 `vm.book.value`     |  🟡 | ✅ 已修复        | `book_detail_view_model.dart:26`（新增 `applyEditedBook`） |
| L2-3 | `backup_page` 信号作 RPC 通道                   |  🟡 | ✅ 已修复        | `backup_view_model.dart:82, 131`（`performBackup`/`performRestore` 返回枚举） |
| L3-1 | `useSignalValue<T, Signal<T>>` 冗余类型参数      |  🔵 | ❌ 报告建议有误    | `signals_hooks@7.1.0` 签名为 `<T, S extends ReadonlySignal<T>>`，第二参数不可省略 |
| L3-2 | `bookmark_manage` 局部信号 + SignalBuilder 双订阅 |  🔵 | ⏭️ 不实施        | 当前模式被报告标注为「极低风险 / 性能微优化」，无收益      |

***

***

### 1. ✅ 已修复 — 直接绕过 ViewModel 修改状态

**修复位置**: `lib/features/bookshelf/application/book_detail_view_model.dart:24-31`

```dart
/// 将编辑后的 Book 写回当前 state（用于编辑元数据后的乐观更新）。
/// 集中在此处以便未来加入持久化、通知等副作用。调用方不应直接写入 [state]。
void applyEditedBook(Book updated) {
  final current = state.value;
  if (current is AsyncData<book_api.BookDetail>) {
    state.value = AsyncState.data(current.value.copyWith(book: updated));
  }
}
```

**调用点** (`book_detail_page.dart:172-174`):

```dart
final updated = await showEditMetadataDialog(context, book);
if (updated == null || !context.mounted) return;
vm.applyEditedBook(updated);  // 之前直接写 vm.state.value
```

后续若 ViewModel 内部引入持久化/通知等副作用，仅需修改 `applyEditedBook` 即可。

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

### 3. ✅ 已修复 — 信号作 RPC 通道

**修复位置**: `lib/features/data/application/backup_view_model.dart:82, 131`

`performBackup()` 改返回 `Future<BackupResult>`，`performRestore()` 改返回 `Future<RestoreResult>`。`status` / `errorMessage` 信号保留用于进度展示与 `dismissResult()` 收尾，但结果传递不再依赖信号读取。

```dart
enum BackupResult { cancelled, success, error }
enum RestoreResult { success, error }

Future<BackupResult> performBackup() async { ... }
Future<RestoreResult> performRestore(String, BackupManifest) async { ... }
```

**调用点** (`data_management_page.dart:_performBackup`):

```dart
final result = await vm.performBackup();
switch (result) {
  case BackupResult.success:   showSnackBar(success);
  case BackupResult.error:     showSnackBar(failed(vm.errorMessage.value ?? ''));
  case BackupResult.cancelled: break;
}
await vm.dismissResult();
```

消除了「await 之后立即检查 status」的脆弱模式。

***

## 🔵 问题级别 3：冗余/风格问题

### 1. ❌ 报告建议有误 — 冗余显式类型参数

原报告声称「本项目 `signals_hooks` 版本（>=0.4）支持 `useSignalValue<T>(Signal<T>)` 重载，第二个类型参数 `Signal<T>` 是冗余的」。该说法与实际库签名不符。

**库签名**（`signals_hooks@7.1.0/lib/src/core.dart:108`）:

```dart
T useSignalValue<T, S extends ReadonlySignal<T>>(
  S value, {
  List<Object?> keys = const <Object?>[],
}) {
  return useExistingSignal(value, keys: keys)();
}
```

两个类型参数都需显式提供，**或两者均省略**（依赖 target typing 与 `S` 推断）。报告中给出的「清理方式」会引发 `wrong_number_of_type_arguments_element` 编译错误（已实测）。

5 个文件 11 处调用维持原状：

| 文件                                                                    | 行       | 形式                                                          |
| --------------------------------------------------------------------- | ------- | ----------------------------------------------------------- |
| `lib/features/reader/core/presentation/reader_chrome.dart`            | 36-37, 107, 113, 114 | `useSignalValue<bool, Signal<bool>>(...)` 等       |
| `lib/features/reader/core/presentation/reader_content_area.dart`      | 99      | `useSignalValue<Set<String>, Signal<Set<String>>>(...)`     |
| `lib/features/reader/core/presentation/reader_interaction_layer.dart` | 45, 104 | `useSignalValue<Offset?, Signal<Offset?>>(...)`             |
| `lib/features/reader/core/presentation/reader_shell.dart`             | 37      | `useSignalValue<TapLayout, Signal<TapLayout>>(...)`         |
| `lib/features/profile/page/typography/typography_settings_page.dart`  | 214, 310 | `useSignalValue<TextAlign, Signal<TextAlign>>(...)` 等       |

**结论**: 不予修改。报告该建议错误。

### 2. ⏭️ 不实施 — 局部信号 + SignalBuilder 混合订阅

原报告对当前位置与模式的描述仍然准确，但报告自身已标注「极低风险 / 性能优化建议」且「当前用法是合理的『状态少→全局重建』取舍」。

`isSearchMode` 变化触发整个 widget 重建对书签管理页（ListView 规模有限）影响微乎其微，且报告建议的「提取 `AppBar` 为子组件」会引入额外组件拆分与状态提升成本，**收益不抵开销**。

**结论**: 维持现状。

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


## 整改结果

按原报告 6 项修复建议核对：

| # | 原建议                                                     |  状态 | 备注                                       |
| - | ------------------------------------------------------- | :-: | ---------------------------------------- |
| 3 | `book_detail_page` 抽取 `vm.book.value = ...` 到 ViewModel |  ✅ | `applyEditedBook` 已实现并迁移调用点（`book_detail_view_model.dart:26`） |
| 5 | 全局清理 `<..., Signal<...>>` 冗余类型参数                        |  ❌ | 报告该建议错误——`signals_hooks@7.1.0` 签名为 `<T, S extends ReadonlySignal<T>>`，两个类型参数不可单独省略 |
| 6 | `app.dart` autoTheme 效应加注释                              |  ✅  | 此前已添加（L27-29）                            |
| L2-3 | `data_management_page` 信号 RPC 通道 | ✅ | `performBackup`/`performRestore` 改返回 `BackupResult`/`RestoreResult` 枚举；调用点改用 `switch` |
| L3-2 | `bookmark_manage` 局部信号重构 | ⏭️ | 不实施，报告自评「极低风险 / 性能微优化」，收益不抵开销 |

剩余无未解决问题。

***

## 相关文件索引

- `lib/features/reader/core/presentation/reader_shell.dart` — 阅读器壳
- `lib/features/bookshelf/application/book_detail_view_model.dart` — L2-1 修复位置
- `lib/features/bookshelf/page/book_detail_page.dart` — L2-1 调用点
- `lib/features/search/page/search_page.dart` — 重复订阅已消除
- `lib/features/data/application/backup_view_model.dart` — L2-3 修复位置
- `lib/features/data/page/data_management_page.dart` — L2-3 调用点
- `lib/features/reader/annotations/presentation/bookmark_manage_page.dart` — L3-2 维持现状
- `lib/app.dart` — 已加注释
- `lib/core/reader/custom_font_service.dart` — `currentFontFamily` getter（信号读取发生处）

