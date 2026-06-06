# signals-hooks 库使用审查报告

> 审查范围：`lib/` 下所有 page 文件  
> 扫描方式：阅读全部 20+ 个使用了 `signals_hooks` 或 `signals_flutter` 的页面文件  
> 审查日期：2026-06-06

---

## 目录

1. [潜在问题（需修复）](#1-潜在问题需修复)
2. [优化建议（可改进）](#2-优化建议可改进)
3. [代码规范问题](#3-代码规范问题)
4. [总结统计](#4-总结统计)

---

## 1. 潜在问题（需修复）

### 1.1 `statistics_page.dart` — 空壳 `useEffect`

**位置：** `lib/features/statistics/page/statistics_page.dart:21-23`

```dart
useEffect(() {
  return null;
}, []);
```

**问题：** 这是一个无任何逻辑、无清理函数的空 `useEffect`，编译后是死代码。`useEffect` 接受一个闭包，当闭包既不做任何事也不返回清理函数时，它不仅无意义，还会给未来的维护者制造困惑。

**建议：** 直接删除这整个 `useEffect` 调用。

---

### 1.2 `bookmark_manage_page.dart` — `useEffect` 中未处理的异步 IIAFE

**位置：** `lib/features/reader/page/bookmark_manage_page.dart:31-40`

```dart
useEffect(() {
  vm.loadBookmarks();
  () async {
    final count = (await bookmark_api.listBookmarksByBook(
      bookId: bookId,
    )).length;
    bookmarkStats.value = count;
  }();  // ← 未处理的 Future<void>
  return null;
}, []);
```

**问题：** 闭包中立即调用了异步箭头函数 `() async { ... }()`，但没有 `await` 也没有 `.catchError()`。如果 `listBookmarksByBook` 抛出异常，该异常会被静默吞掉（Unhandled Promise Rejection 的 Dart 等价形式）。

**建议：** 
- 方案 A：在 `useEffect` 内部使用同步的方式获取数据，或将异步逻辑提取到 ViewModel 中。
- 方案 B：使用 `useFutureSignal` 替换手动管理。
- 方案 C：至少加上 `try/catch`：

```dart
useEffect(() {
  vm.loadBookmarks();
  _loadBookmarkCount();
  return null;
}, []);
```

```dart
Future<void> _loadBookmarkCount() async {
  try {
    final count = (await bookmark_api.listBookmarksByBook(bookId: bookId)).length;
    bookmarkStats.value = count;
  } catch (_) {
    // handle or ignore gracefully
  }
}
```

---

### 1.3 `reader_page.dart` — 设置面板属性直接读取 VM 信号而非通过 Binding

**位置：** `lib/features/reader/page/reader_page.dart:369-396`

```dart
ReaderSettingsPanel(
  fontSize: vm.config.fontSize.value,         // ← 直接读取，无订阅
  lineHeight: vm.config.lineHeight.value,     // ← 直接读取，无订阅
  letterSpacing: vm.config.letterSpacing.value,
  paragraphSpacing: vm.config.paragraphSpacing.value,
  pageMargin: vm.config.pageMargin,           // ← 注意：这是 Signal<double> 还是 double？
  writingDirection: vm.config.writingDirection.value,
  ...
)
```

**问题：** 这些 `.value` 访问发生在 `ReaderPage.build()` 中，但该 widget 的重新构建是由 `useReaderBindings()` 返回的绑定信号触发的，而非由 `vm.config.*` 的信号直接触发。当前它能"工作"只是因为 `useReaderBindings` 订阅了 `vm.fontSizeDouble`（一个源自 `config.fontSize.signal` 的 Computed），所以当字体大小变化时整个页面会重建，从而重新读取这些值。

但这是 **隐式依赖**，非常脆弱：
- 如果未来将 `useReaderBindings` 拆分为 content-only / UI-only 绑定且不再包含 `fontSizeDouble`，设置面板将"卡住"不再更新；
- 同一页面内的写法不一致：`ReaderContent` 的 props 来自 `b.*`（绑定），`ReaderSettingsPanel` 的 props 却直接从 `vm.config` 读取。

**建议：** 将这些属性也通过绑定传递，或者将 `ReaderSettingsPanel` 用 `SignalBuilder` 包裹以订阅其所需的信号。

---

### 1.4 `home_page.dart`、`backup_page.dart`、`learning_notes_page.dart` — `useFutureSignal` 返回值被丢弃

**位置：**
- `lib/features/home/page/home_page.dart:26`
- `lib/features/backup/page/backup_page.dart:25`
- `lib/features/learning_notes/page/learning_notes_page.dart:20`

```dart
useFutureSignal(() => vm.loadData());  // 返回值未赋值
```

**问题：** `useFutureSignal` 创建一个 `FutureSignal<T>` 对象并为其分配内部状态，但返回值被立即丢弃。在这个模式中，调用者只需要 `vm.loadData()` 的副作用——VM 内部有独立的信号来暴露数据状态。未被使用的 `FutureSignal` 仍然在 hooks 列表中占位，增加微小的内存开销。

**建议：** 改为 `useEffect`，仅在挂载时触发加载：

```dart
useEffect(() {
  vm.loadData();
  return null;
}, []);
```

如果确实需要加载状态的 UI 反馈，可以保留 `useFutureSignal` 并用其返回值驱动加载指示器。

---

## 2. 优化建议（可改进）

### 2.1 冗余的泛型类型参数（9 个文件受影响）

**涉及文件：**
- `lib/features/reader/page/widgets/reader_page_bindings.dart`（几乎每行）
- `lib/features/reader/page/cache_manage_page.dart`
- `lib/features/reader/page/reader_page.dart`
- `lib/features/backup/page/backup_page.dart`
- `lib/features/backup/page/widgets/backup_status_card.dart`
- `lib/features/vocabulary/page/vocabulary_page.dart`
- `lib/features/statistics/page/reading_sessions_page.dart`
- `lib/features/search/page/search_page.dart`
- `lib/features/learning_notes/page/learning_notes_page.dart`

**典型代码：**

```dart
useSignalValue<bool, Signal<bool>>(vm.showToolbar)
```

代码库中大量文件在 `useSignalValue` 上使用了两个显式泛型参数。但同一代码库中其他文件（`statistics_page.dart`、`home_page.dart`、`profile_page.dart`、`theme_brightness_page.dart`、`other_settings_page.dart`）证明了无泛型参数即可正常工作：

```dart
// 无参数的写法在整个代码库中已经存在，说明 Dart 的类型推断足够处理
final GlobalStats? gs = useSignalValue(vm.globalStats);    // statistics_page.dart
final AsyncState<List<Book>> recentBooks = useSignalValue(vm.recentBooks); // home_page.dart
```

**建议：** 移除多余的 `<T, S>` 泛型参数，只在编译器提示无法推断时添加。

**影响范围估算：** 约 50+ 处调用点。

---

### 2.2 `book_detail_page.dart` — 可合并两个 `useEffect`

**位置：** `lib/features/bookshelf/page/book_detail_page.dart:31-40`

```dart
useEffect(
  () => () => vm.dispose(),   // 仅清理
  [],
);

useEffect(() {
  vm.loadData();
  return null;
}, []);
```

**建议：** 合并为一个 `useEffect`，减少 hooks 链条长度：

```dart
useEffect(() {
  vm.loadData();
  return () => vm.dispose();
}, []);
```

---

### 2.3 `bookmark_manage_page.dart` — 排序/过滤逻辑可使用 `useComputed` 缓存

**位置：** `lib/features/reader/page/bookmark_manage_page.dart:149-173`

在 `SignalBuilder` 的 builder 中，书签列表被完整过滤和排序：

```dart
var bookmarkList = (async.value ?? []).whereType<Bookmark>().toList();
if (isSearchMode.value && searchController.text.isNotEmpty) {
  final keyword = searchController.text.toLowerCase();
  bookmarkList = bookmarkList.where(...).toList();
}
bookmarkList.sort(...);
```

每次 `vm.bookmarks` 或 `isSearchMode` / `sortBy` / `ascending` 任一信号变化时，这些计算都会重新执行。

**建议：** 使用 `useComputed` 将派生数据缓存起来。虽然 `SignalBuilder` 已经做了子树级隔离，但 `useComputed` 可以避免在无关信号变化时重复计算。

> 注意：由于 `useComputed` 需要在 Hook 顶层调用，而当前逻辑位于 `SignalBuilder.builder` 内部，需要将计算逻辑提升到 `build` 方法顶层。

---

### 2.4 `search_page.dart` — 混合使用绑定信号与未绑定信号访问

**位置：** `lib/features/search/page/search_page.dart:34-38,91-100`

```dart
// 已绑定（有订阅）
final isSearching = useSignalValue<bool, Signal<bool>>(vm.isSearching);
final hasSearched = useSignalValue<bool, Signal<bool>>(vm.hasSearched);

// 未绑定（无订阅，工作依赖于前面的绑定触发重建）
if (hasSearched && vm.searchResults.value != null)   // ← 直接读取
  SearchSummaryBar(results: vm.searchResults.value!),
```

**问题：** `vm.searchResults` 没有通过 `useSignalValue` 订阅。它能在当前版本工作是因为 `hasSearched` 的订阅触发重建，但：
1. 跨信号依赖关系不明确；
2. 如果未来 `hasSearched` 的更新路径与 `searchResults` 解耦，页面可能展示过期数据。

**建议：** 也通过 `useSignalValue` 订阅 `vm.searchResults`：

```dart
final searchResults = useSignalValue(vm.searchResults);
```

---

### 2.5 `book_page.dart` 和 `backup_page.dart` — 使用 `useSignal` 作为本地信号但未利用信号反应式能力

**涉及文件：**
- `lib/features/search/page/book_search_page.dart` — 4 个 `useSignal`
- `lib/features/bookshelf/page/bookshelf_page.dart` — 3 个 `useSignal`
- `lib/features/reader/page/bookmark_manage_page.dart` — 4 个 `useSignal`

**问题：** 这些本地信号仅通过 `.value` 读写，从未用于 `useComputed`、`useSignalEffect`（外部信号）或传递给 `SignalBuilder`。对于纯本地 UI 状态，`useState`（来自 flutter_hooks）可以达到同样效果且语义更轻量。

不过这是一个 **代码一致性问题**，而非正确性问题——两种方式都能正常工作。

**建议：** 团队约定一个一致的本地状态策略：
- 纯本地 UI 状态（搜索模式、批量模式开关）→ `useState`
- 需要参与信号反应式图（派生计算、信号效应、传递给 SignalBuilder）→ `useSignal`

---

## 3. 代码规范问题

### 3.1 `import` 次序不一致

部分文件从 `signals_hooks` 导入，部分从 `signals_flutter` 导入：

| 导入来源 | 使用文件 |
|---------|---------|
| `signals_hooks` | 多数 page 文件 |
| `signals_flutter` | `category_management_page.dart`（用 `SignalBuilder`） |
| 同时导入两者 | 无 |

`category_management_page.dart` 只使用 `SignalBuilder`（来自 `signals_flutter`），不导入 `signals_hooks`——这是合理的。SignalBuilder 不依赖 hooks 体系，可以独立使用。但需要注意：**在非 `HookWidget` 中使用 `SignalBuilder` 访问 `vm.categories.value` 是完全正确的**；如果在 `HookWidget` 中需要订阅外部信号并在 widget 层级重建，则需使用 `useSignalValue`。

### 3.2 `useComputed`、`useExistingSignal`、`useAsyncComputed` 零使用

代码库中完全没有使用以下 hooks：
- `useComputed` —— 可用于缓存派生计算
- `useExistingSignal` —— 可用于获取外部信号的引用而非裸值
- `useAsyncComputed` —— 可用于依赖驱动的异步计算
- `useStreamSignal` —— 可用于将 Dart Stream 接入信号体系

这些 hooks 在 `signals_hooks` 中可用但未被利用。不一定需要添加，但值得注意。

---

## 4. 总结统计

| 类别 | 计数 | 严重程度 |
|------|------|---------|
| 死代码（空 `useEffect`） | 1 处 | ⚠️ 需修复 |
| 未处理异步异常 | 1 处 | ⚠️ 需修复 |
| 隐式信号依赖（脆弱） | 1 处 | ⚠️ 需修复 |
| 被丢弃的 `useFutureSignal` | 3 处 | 🔧 建议改进 |
| 冗余泛型参数 | ~50 处 | 🔧 建议改进 |
| 可合并 `useEffect` | 1 处 | 🔧 建议改进 |
| 可缓存派生数据 | 1 处 | 💡 可优化 |
| 信号订阅不一致 | 1 处 | 💡 可优化 |
| 本地状态 hooks 不一致 | 4 个文件 | 🎨 代码规范 |
| 未使用高级 hooks | 5 个 hooks | 📌 备注 |

---

*报告完毕。*
