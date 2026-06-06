# Signals 使用审查报告（修订版）

> 审查时间: 2026-06-06  
> 审查范围: `lib/**/view_model*.dart` 及关联的 Manager  
> 信号库: `signals_flutter` (signals.dart v7.x)

---

## 目录

1. [核心结论](#1-核心结论)
2. [真正的 P0 问题](#2-真正的-p0-问题)
3. [中等问题](#3-中等问题)
4. [优化建议](#4-优化建议)
5. [不要改: 原报告误报澄清](#5-不要改-原报告误报澄清)
6. [各文件评分清单](#6-各文件评分清单)

---

## 1. 核心结论

本报告最初认为 10/15 个 ViewModel 因缺少 `dispose()` 导致信号泄漏。
**此结论是错误的**。

**为什么不需要 dispose 纯 `signal`？**

signals 库没有"全局信号注册表"。`Signal<T>` 是普通 Dart 对象：
- 无 `effect`/`computed` 订阅时，没有任何全局根引用它
- 当 ViewModel 实例可回收时，信号对象随之可 GC
- 多数 ViewModel 被 `useMemoized(() => VM())` 创建，Widget 销毁 → ViewModel 消失 → 信号消失

**需要 dispose 的只有**：`effect()` 的返回值、`PersistedSignal`、以及 Dart 标准资源
（`Timer`、`StreamSubscription`）。

详见 [`lib/FLUTTER_CONVENTIONS.md`](lib/FLUTTER_CONVENTIONS.md) 的 Signals 内存管理章节。

---

## 2. 真正的 P0 问题

### 🔴 P0-1. `ReaderViewModel.resetForNewBook()` 销毁 auto-scroll effect 后永不重建

**文件**: `lib/features/reader/application/reader_view_model.dart` lines 103-111, 517-541

构造函数注册了一个 `effect()` 监听自动滚动 + 阅读状态：

```dart
ReaderViewModel(this._repo, this._config) {
  ...
  _disposers.add(
    effect(() {
      if (_config.autoScroll.value && sessionManager.isReading.value) {
        chapterManager.startAutoScroll();
      } else {
        chapterManager.stopAutoScroll();
      }
    }),
  );
}
```

`resetForNewBook()` 销毁 effect 并清空列表，但之后不再重新注册：

```dart
void resetForNewBook() {
  for (final disposer in _disposers) {
    disposer();
  }
  _disposers.clear();
  // ... 重置状态，但不会再创建 effect
}
```

**后果**: `ReaderViewModel` 是 `@lazySingleton`，构造函数只执行一次。
第一次换书后 effect 被永久销毁，`initialize()` 不重建，自动滚动功能失效。

**修复方向**: 将 effect 的创建移入 `initialize()`，或让 `resetForNewBook()` 重新注册。

---

### 🔴 P0-2. `ChapterManager` / `ReadingSessionManager` 的 Timer 在 reset 后未取消

**文件**: `lib/features/reader/application/chapter_manager.dart`
- `lib/features/reader/application/reading_session_manager.dart`

**问题**: `ChapterManager.reset()` 重置了 `autoScrollTick` 到 0，但未 cancel `_autoScrollTimer`。
旧的定时器继续跑，`autoScrollTick` 在 UI 侧可能被监听但值不再被新章节使用。

`ReadingSessionManager` 相同：`reset()` cancel 了两组 Timer，行为正确。但
`ChapterManager.reset()` 漏了 `_autoScrollTimer?.cancel()`。

```dart
void reset() {
  _autoScrollTimer?.cancel();  // ❌ 缺这行
  _searchIndexOperation?.cancel();
  bookId.value = '0';
  ...
}
```

**修复方向**: `reset()` 头部增加 `_autoScrollTimer?.cancel()`。

---

### 🔴 P0-3. `CacheManageViewModel` 构造函数调用异步方法

**文件**: `lib/features/reader/application/cache_manage_view_model.dart`

```dart
CacheManageViewModel({required this.repo, this.bookId}) {
  load();  // ❌ 构造函数内触发异步操作
}
```

**问题**:
1. 构造期间无法 `await`，若 `load()` 内部抛出同步异常（虽然已经 try-catch），构造失败
2. ViewModel 被 `useMemoized` 重建时，重复触发 `load()`
3. 违反 Dart 最佳实践：构造函数不应有副作用

**修复方向**: 移除构造函数中的 `load()`，改由 Page 侧显式调用。

---

## 3. 中等问题

### 🟡 M1. `ReadingSessionsViewModel` catch 块静默吞异常

**文件**: `lib/features/statistics/application/reading_sessions_view_model.dart`

```dart
} catch (_) {
  loaded.value = true;
}
```

丢弃异常且未设置 error 信号。UI 无法区分"加载完成，数据为空"和"加载失败"。

---

### 🟡 M2. `BackupViewModel._readLastBackupMeta` 的 `batch()` 无收益

**文件**: `lib/features/backup/application/backup_view_model.dart` lines 51-58

```dart
batch(() {
  if (ts != null) lastBackupAt.value = ...;
  if (size != null) lastBackupSize.value = ...;
});
```

这两个信号没有关联的 `computed` 或 `effect`，`batch()` 无实际效果。
防御性过度，可移除或保留均可。

---

### 🟡 M3. `SearchViewModel` 用 `asyncSignal` 但手写 AsyncState

```dart
final results = asyncSignal<List<SearchResult>>(AsyncState.data([]));
```

`searchBook()` 手动管理 `AsyncState.loading()`/`.data()`/`.error()`，
未使用 `loadAsync` 扩展。应降为 `signal<AsyncState<List<SearchResult>>>(AsyncState.data([]))`，
或改用 `loadAsync`。

---

### 🟡 M4. `ProfileViewModel` 的 skip-load 逻辑可能阻止刷新

```dart
if (globalStats.value is AsyncData || vocabStats.value is AsyncData) return;
```

路由过渡时 if 判断阻止了数据刷新。从 ProfilePage 切到其他页再切回来，
数据不会更新。当前靠注释说明是设计意图，但可能不是用户期望的行为。

---

## 4. 优化建议

### 💡 R1. `BookshelfViewModel.feedback` 瞬态信号不会被重置

```dart
final feedback = signal<String?>(null);
```

赋值后永远不会重置为 null。若 Page 侧 `useSignalEffect` 消费后不清零，
下次同一条消息不会触发 re-run。建议在消费侧重置：

```dart
useSignalEffect(() {
  final msg = vm.feedback.value;
  if (msg != null) {
    showInfoSnack(context, msg);
    vm.feedback.value = null;  // 消费后重置
  }
});
```

或使用 `untracked` 读取。

---

### 💡 R2. 统一使用 `loadAsync` 扩展

`SearchViewModel`、`ReadingSessionsViewModel`、`StorageSyncViewModel` 手动管理
AsyncState 状态转换。建议统一使用 `async_utils.dart` 中的 `loadAsync` 扩展。

---

### 💡 R3. `LearningNotesViewModel.bookTitles` 用 `mapSignal` 但全量替换

```dart
final bookTitles = mapSignal<String, String>({});
...
bookTitles.value = await loadBookTitles();  // 每次都替换整个 map
```

`mapSignal` 的细粒度 key-level 监听优势未被利用。若不需要监听单个 key，
用 `signal<Map<String, String>>({})` 即可。

---

## 5. 不要改: 原报告误报澄清

以下问题来自初版报告，**经分析不影响实际运行，无需修改**：

| 原报问题 | 为什么不需要改 |
|----------|--------------|
| 10/15 个 ViewModel 无 dispose 方法 | 纯 `signal` 字段无全局注册表，无订阅即可 GC |
| `computed` 未 dispose | 惰性求值，无订阅者时自动 GC 可达 |
| `ReaderViewModel` 的 signal field 未 dispose | 它是 `@lazySingleton`，存活到进程结束 |
| `ChapterManager`/`ReadingSessionManager` 信号未 dispose | 随 `ReaderViewModel` 单例存活 |
| `PersistedSignal` Timer 泄漏 | 持有者均为单例（`BookshelfViewModel`、`ThemeBrightnessViewModel`、`OtherSettingsViewModel`），Timer 存活到进程结束 |

---

## 6. 各文件评分清单

| # | 文件 | 真实问题 | 风险 |
|---|------|---------|------|
| 1 | `backup_view_model.dart` | M2（`batch` 无收益） | 🟢 |
| 2 | `learning_notes_view_model.dart` | R3（mapSignal 全量替换） | 🟢 |
| 3 | `home_view_model.dart` | 无 | 🟢 |
| 4 | `search_view_model.dart` | M3（asyncSignal 降级） | 🟢 |
| 5 | `vocabulary_view_model.dart` | 无 | 🟢 |
| 6 | `bookshelf_view_model.dart` | R1（feedback 未重置） | 🟢 |
| 7 | `book_detail_view_model.dart` | 无 | 🟢 |
| 8 | `reading_stats_view_model.dart` | 无 | 🟢 |
| 9 | `reading_sessions_view_model.dart` | M1（静默 catch） | 🟢 |
| 10 | `storage_sync_view_model.dart` | 无 | 🟢 |
| 11 | `reader_view_model.dart` | **P0-1（effect 永不重建）** + P0-2 | 🔴 |
| 12 | `cache_manage_view_model.dart` | **P0-3（构造调 async）** | 🔴 |
| 13 | `theme_brightness_view_model.dart` | 无 | 🟢 |
| 14 | `other_settings_view_model.dart` | 无 | 🟢 |
| 15 | `profile_view_model.dart` | M4（skip-load） | 🟢 |
| — | `chapter_manager.dart` | P0-2（Timer 未 cancel） | 🔴 |
| — | `reading_session_manager.dart` | 无 | 🟢 |

### 优先级建议

| 优先级 | 问题 | 操作 |
|--------|------|------|
| **P0** | `ReaderViewModel.resetForNewBook()` effect 永不重建 | 修复 auto-scroll |
| **P0** | `ChapterManager.reset()` 未 cancel `_autoScrollTimer` | 加一行 cancel |
| **P0** | `CacheManageViewModel` 构造调 `load()` | 移到外部 |
| P2 | `SearchViewModel` 降 `asyncSignal` 为 `signal` | 代码健康 |
| P3 | 其余 M 级/R 级 | 顺手修 |

---

*报告结束*
