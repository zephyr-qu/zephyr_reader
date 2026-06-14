# Signals VM / Service 层审查报告

***

## C4. `reader_view_model.dart` L726-L758 — effect 销毁后继续信号写入

**文件**: `lib/features/reader/application/reader_view_model.dart` — `resetForNewBook()`

```dart
void resetForNewBook() {
  // ...
  for (final disposer in _disposers) {
    disposer();       // ← 销毁 autoScroll effect
  }
  _disposers.clear();
  unawaited(sessionManager.stopReading());  // ← 异步，内部读/写 signals
  chapterManager.reset();                    // ← 同步写入 signals
  toastMessage.value = '';                  // ← 写入 signal
  showCatalog.value = false;                // ← 以下大量信号写入
  showBookmarks.value = false;
  // ...
}
```

**风险**: `_disposers` 只管理了 autoScroll 的 `effect`（来自 `initialize()` L157-165）。其他 signals 是 UIView 通过 `useSignalValue` / `SignalBuilder` 独立订阅的，不受此 effect 影响。但以下两种场景存在潜在 race：

1. `sessionManager.stopReading()` 是 `unawaited`，它在 future 中仍会读取 `readingDuration.value`、`isReading.value` 等信号。这些信号随后被 `chapterManager.reset()` 和大量同步赋值改写（L737-757），`stopReading()` 可能在异步中读到脏数据。
2. 连续调用 `resetForNewBook()` → `initialize()` 是安全的（旧 effect 清除、新 effect 注册），但如果 `initialize()` 在没有 `resetForNewBook()` 的情况下被连续调用（无此场景），effect 会累积。

***

## 🟡 MODERATE

### M4. `theme_manager.dart` L107-L142 — effect 中 `_prefs!` 强解包

```dart
_disposers.add(
  effect(() {
    _prefs!.setInt(SettingsKeys.themeType, themeType.value.index);
  }),
);
```

在 `_doInit()` 中 `_prefs` 被赋值后注册 effect，按流程不会 NPE。但若 `init()` 从未调用（时序异常）或 `dispose()` 重设了 `_initialized` 标志（热重载路径），`_prefs` 仍可能为 null。建议在 effect 内加判空或确保 `_doInit()` 先于任何 effect 触发。

***

## 🔵 MINOR

### m1. `bookshelf_view_model.dart` L166-167 — read inside computed signal value

```dart
final pa = (readingProgress.value.value ?? {})[a.bookId] ?? 0;
```

在 `reloadBooks()` 中直接读取 `readingProgress.value.value`（AsyncState 的 data）。这是在 VM 方法中（非 effect/SignalBuilder 环境），`readingProgress` 作为 Signal 的 `.value` 读取\*\*不会建立依赖追踪，只是快照。语义正确，但风格上会让读者误以为这是响应式读取。

### m2. `reading_sessions_view_model.dart` L25 — mapSignal 全量替换未利用粒化能力

```dart
bookCache.value = {for (final b in books) b!.bookId: b};
```

`mapSignal` 支持逐 key 粒化更新（`.set()` / `.remove()`），但此处用了全量赋值。如果未来需要按 element 级别触发订阅，应改用 `bookCache.set(key, value)` 逐个添加。

### m4. `theme_manager.dart` L166-172 — dispose 后 `_initialized = false` 可能绕过 guards

```dart
void dispose() {
  for (final d in _disposers) {
    d();
  }
  _disposers.clear();
  _initialized = false;  // ← 热重载后可重新 init
}
```

`_initialized = false` 为热重载服务，但如果 `dispose()` 后不调用 `init()` 就访问信号，`_prefs` 为 null 导致 NPE。建议 `dispose()` 也将 `_prefs` 置为 null，并在 effect 中加 null-check。

### m5. `reader_config.dart` 全部 `persistedSignal` 字段类型推导一致但 manually annotated

```dart
late final theme = persistedEnum<ReaderTheme>(...);
late final fontSize = persistedDouble(...);
```

`persistedDouble()` 返回 `PersistedSignal<double>`，`persistedEnum` 返回 `PersistedSignal<T>`。Dart 可从右值推断类型，`late final` 不是必须写明类型注解。不过这是项目风格选择，不算错误。

***

