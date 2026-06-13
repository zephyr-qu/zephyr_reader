# Signals VM / Service 层审查报告

> 审查范围: 所有 `application/` 下的 ViewModel 文件 + `core/` 中使用了 signals 的服务/管理器文件，共约 20 个文件。
> `import 'package:signals_flutter/signals_flutter.dart'` 准入条件。

---

## 摘要

| 级别 | 计数 | 说明 |
|:---:|:---:|:------|
| 🔴 Critical | 4 | 死代码信号、effect/信号生命周期风险 |
| 🟡 Moderate | 5 | 类型不一致、batch 缺失、编号误用 |
| 🔵 Minor | 5 | 代码风格、缺失 dispose、硬编码 key |

---

## 🔴 CRITICAL

### C1. `reading_stats_view_model.dart` L21-L27 — 已标注 UNUSED 的 computed 信号

**文件**: `lib/features/statistics/application/reading_stats_view_model.dart`

```dart
// UNUSED: computed 信号已定义但没有任何页面/组件读取 .value
late final dailyMinutes = computed(
  () =>
      dailyRecords.value.value
          ?.map((r) => r.readingTimeSeconds.toInt() / 60.0)
          .toList() ??
      [],
);
```

`dailyMinutes` 定义了但从未在任何地方消费 `.value`。虽不影响功能，但 `computed` 会随依赖信号 `dailyRecords` 每次变更而静默重算，是纯粹的 CPU 浪费。建议删除。

### C2. `storage_sync_view_model.dart` L28-L33 — 5 个 UNUSED 存储统计信号

**文件**: `lib/features/sync/application/storage_sync_view_model.dart`

```dart
// UNUSED: 以下 5 个存储用量信号由 _calcStorage() 计算，但页面从未读取展示
final cacheSize = signal<int>(0);
final dbSize = signal<int>(0);
final booksSize = signal<int>(0);
final totalUsed = signal<int>(0);
final totalAvailable = signal<int>(0);
```

`_calcStorage()` 在 `initialize()` 中递归遍历文件系统计算这些值并写入信号，但 UI 层从未读取。建议删除这些信号和 `_calcStorage()` 调用。

### C3. `backup_view_model.dart` L38-L40 — UNUSED `lastBackupSize` 信号

**文件**: `lib/features/backup/application/backup_view_model.dart`

```dart
final lastBackupSize = signal<int>(
  0,
); // UNUSED: 被写入 SharedPreferences 但页面从未读取
```

此信号在 `_readLastBackupMeta()` 中写入，但页面从未用作 UI 展示。`lastBackupSize` 的值仅通过 SharedPreferences 持久化，属死代码。

### C4. `reader_view_model.dart` L726-L758 — effect 销毁后继续信号写入

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

---

## 🟡 MODERATE

### M1. `cache_manage_view_model.dart` L16 — `Signal<AsyncState<T>>` 而非 `AsyncSignal<T>`

**文件**: `lib/features/reader/application/cache_manage_view_model.dart`

```dart
final searchIndexStats = signal<AsyncState<IndexStats>>(AsyncState.loading());
```

同行文件 L12-L14 使用 `asyncSignal<…>`，唯独 `searchIndexStats` 用手写 `signal<AsyncState<…>>` 包裹。两者在公共 API 上效果相同（都可以通过 `.value` 读 AsyncState），但 `asyncSignal` 提供了 `loadAsync()` 等便捷方法，此处不一致。

### M2. `reader_view_model.dart` L86-L96 — computed 引用后声明的信号

```dart
late final ReadonlySignal<Map<String, Bookmark>> _bookmarkIndex = computed(() {
  final list = bookmarks.value.value ?? [];  // ← bookmarks 在 L96 才声明
  // ...
});
final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));  // L96
```

因为 `_bookmarkIndex` 是 `late final`，首次读 `.value` 时惰性初始化，此时 `bookmarks` 已初始化完毕，运行时不报错。但代码排序让人困惑（computed 使用了未声明标识符），维护者容易误判。

### M3. `search_view_model.dart` L47-L53 — 信号赋值未用 `batch()`

**文件**: `lib/features/search/application/search_view_model.dart` — `searchBook()`

```dart
isSearching.value = true;
// ...
results.value = AsyncState.loading();
```

`isSearching` 和 `results` 是两个独立的 Signal 赋值。UI 侧订阅了这两个信号的 `useSignalValue` 会分别触发 rebuild。建议用 `batch()` 包裹：

```dart
batch(() {
  isSearching.value = true;
  results.value = AsyncState.loading();
});
```

### M4. `theme_manager.dart` L107-L142 — effect 中 `_prefs!` 强解包

```dart
_disposers.add(
  effect(() {
    _prefs!.setInt(SettingsKeys.themeType, themeType.value.index);
  }),
);
```

在 `_doInit()` 中 `_prefs` 被赋值后注册 effect，按流程不会 NPE。但若 `init()` 从未调用（时序异常）或 `dispose()` 重设了 `_initialized` 标志（热重载路径），`_prefs` 仍可能为 null。建议在 effect 内加判空或确保 `_doInit()` 先于任何 effect 触发。

### M5. `backup_view_model.dart` L112-L113 — 硬编码 SharedPreferences key

```dart
await _prefs.setInt('last_backup_at', manifest.exportedAt);
await _prefs.setInt('last_backup_size', manifest.dbSize);
```

同文件 L55-56 的 `_readLastBackupMeta()` 却使用了 `SettingsKeys.lastBackupAt` 和 `SettingsKeys.lastBackupSize`。写入和读取用不同的 key 引用方式，建议统一为 `SettingsKeys`。

---

## 🔵 MINOR

### m1. `bookshelf_view_model.dart` L166-167 — read inside computed signal value

```dart
final pa = (readingProgress.value.value ?? {})[a.bookId] ?? 0;
```

在 `reloadBooks()` 中直接读取 `readingProgress.value.value`（AsyncState 的 data）。这是在 VM 方法中（非 effect/SignalBuilder 环境），`readingProgress** 作为 Signal 的 `.value` 读取**不会建立依赖追踪，只是快照。语义正确，但风格上会让读者误以为这是响应式读取。

### m2. `reading_sessions_view_model.dart` L25 — mapSignal 全量替换未利用粒化能力

```dart
bookCache.value = {for (final b in books) b!.bookId: b};
```

`mapSignal` 支持逐 key 粒化更新（`.set()` / `.remove()`），但此处用了全量赋值。如果未来需要按 element 级别触发订阅，应改用 `bookCache.set(key, value)` 逐个添加。

### m3. 多处 ViewModel 缺少 `dispose()` 方法

| 文件 | 情况 |
|------|------|
| `home_view_model.dart` | 无 dispose (非 late final signals，GC 兜底) |
| `category_view_model.dart` | dispose() 注释写 "异步 signal 无需手动 dispose" 但 body 为空 |
| `reading_stats_view_model.dart` | 无 dispose |
| `reading_sessions_view_model.dart` | 无 dispose |
| `search_view_model.dart` | 无 dispose |
| `book_search_view_model.dart` | 有 dispose ✅ |
| `storage_sync_view_model.dart` | 无 dispose |

虽然是 `@lazySingleton` 或短生命周期对象，但统一约定 `dispose()` 可以提高可维护性。

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

---

## ✅ 正确使用的模式

| 模式 | 使用位置 | 评价 |
|------|---------|:----:|
| `batch()` 包裹多信号写入 | `book_detail_view_model.dart`, `backup_view_model.dart`, `cache_manage_view_model.dart`, `search_view_model.dart` `doFullSearch()` | ✅ 大量正确使用 |
| `asyncSignal.loadAsync()` 异步加载 | `reader_view_model.dart` L350 (bookmarks), `home_view_model.dart`, `profile_view_model.dart` | ✅ 简洁安全 |
| `computed` 派生信号 | `chapter_manager.dart` (progressText, currentChapterTitle), `reader_view_model.dart` (fontSizeDouble, _bookmarkIndex) | ✅ 正确惰性初始化 |
| `effect` 自动持久化 | `theme_manager.dart` L107-142 | ✅ 功能正确 |
| `PersistedSignal` 封装 | `reader_config.dart` 全量配置, `other_settings_view_model.dart`, `tts_settings_view_model.dart`, `auto_theme_service.dart` | ✅ 消除手动 _save 样板 |
| `untracked` / `.peek()` 避免循环订阅 | `persisted_signal.dart` L32 (`_signal.peek()`) | ✅ 完全正确 |
| `mapSignal` 按 key 更新 | `reading_sessions_view_model.dart` L12 | 使用正确，虽未充分利用粒度 |
| `dispose()` 释放信号 | `backup_view_model.dart`, `book_detail_view_model.dart`, `cache_manage_view_model.dart`, `chapter_manager.dart`, `reader_config.dart`, `tts_settings_view_model.dart`, `vocabulary_view_model.dart` | ✅ 遵循约定 |

---

## 修复建议优先级

1. **立即删除**: C1 `dailyMinutes` computed, C2 五个存储信号+`_calcStorage()`, C3 `lastBackupSize`
2. **修**: C4 `resetForNewBook()` — `unawaited(stopReading())` 改为 `await`，或将写入信号的逻辑在 effect 清理前完成
3. **修**: M1 `cache_manage_view_model.dart` — 统一为 `asyncSignal<IndexStats>`
4. **修**: M3 `search_view_model.dart searchBook()` — `batch()` 包裹 `isSearching` + `results`
5. **修**: M5 `backup_view_model.dart` — `'last_backup_at'` 改为 `SettingsKeys.lastBackupAt`
6. **修**: m3 — 缺 `dispose()` 的 ViewModel 补上（至少调用所有信号的 `.dispose()`）
7. **可选**: M4 theme_manager effect 加 `_prefs` null-check
8. **可选**: M2 调整 `_bookmarkIndex` 和 `bookmarks` 的声明顺序
