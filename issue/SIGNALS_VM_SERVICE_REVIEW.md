# Signals VM / Service 层审查报告

> 审查日期: 2026-06-13
> 复核日期: 2026-06-16
> 范围: `lib/` 下 signals / VM / Service 层的潜在 race / dispose / 类型陷阱

***

## 复核总结

| ID | 严重度 | 问题 | 当前状态 (2026-06-16) |
|----|--------|------|----------------------|
| C4 | 🔴 CRITICAL | `resetForNewBook` effect 销毁后继续信号写入 | ✅ 已重构 — 旧代码完全移除 |
| M4 | 🟡 MODERATE | `theme_manager` effect 中 `_prefs!` 强解包 | ✅ 已重构 — API 全面更换为 `persisted<>` 工厂 |
| m1 | 🔵 MINOR | `BookshelfViewModel` L166 读取 `readingProgress` | ✅ 已重构 — 该信号已不存在 |
| m2 | 🔵 MINOR | `reading_sessions_view_model` L25 `bookCache` 全量赋值 | ⚠️ 未修 — 仍维持 `bookCache.value = {...}` 全量赋值 |
| m4 | 🔵 MINOR | `theme_manager` dispose 后 `_initialized = false` 绕过 guards | ✅ 已重构 — 标志完全移除 |
| m5 | 🔵 MINOR | `reader_config` `persistedSignal` 类型注解冗余 | ⚠️ 部分 — 多数字段已省略类型，但部分保留 |

**结论**: 1 CRITICAL + 1 MODERATE + 2 MINOR 已通过重构彻底消除；2 MINOR 仍存在但风险极低。原始文件中 `showCatalog` / `showBookmarks` 等死信号和 `readingProgress` signal 已随 VM 重构一起清除。

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

**复核 (2026-06-16):** ✅ 已通过 VM 重构彻底消除

**当前实现** (`lib/features/reader/core/application/reader_view_model.dart:266-282`):

```dart
Future<void> resetForNewBook() async {
  _reloadDebounce?.cancel();
  for (final disposer in _disposers) {
    disposer();
  }
  _disposers.clear();

  await sessionManager.stopReading();   // ✅ 现在是 await，不是 unawaited
  chapterManager.reset();

  bookmarks.reset();
  annotations.reset();
  await translation.reset();

  toastMessage.value = '';
  state.reset();
}
```

**关键改进**:
1. `resetForNewBook` 现在是 `Future<void>` — 内部 `await sessionManager.stopReading()` 而非 `unawaited`，消除了原 race
2. 子 VM 各自负责 `reset()`（`bookmarks.reset()` / `annotations.reset()` / `translation.reset()` / `state.reset()`）— 单一职责
3. `showCatalog` / `showBookmarks` 等死信号已不存在（`grep` 0 命中）— 信号面收窄
4. `_disposers` 仅含 autoScroll effect（`initialize()` 中注册），不再管理大量 UI 状态

**遗留轻微风险**: 仍有 `_disposers` 列表 + effect 模式（autoScroll），若未来新增 effect 需注意同样约束。`sessionManager.stopReading()` 现在是 `await`，但其内部若仍异步读 signals（readingDuration 等），仍需关注跨子 VM 信号写顺序。当前为顺序：先 `stopReading()`（内部停止计时器），再 `chapterManager.reset()` — 顺序正确。

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

**复核 (2026-06-16):** ✅ 已通过 API 重构彻底消除

**当前实现** (`lib/core/theme/theme_manager.dart:25-50`):

```dart
@Singleton()
class ThemeManager {
  final PreferencesService prefs;   // ✅ 强类型 final 字段，无 _prefs!

  late final themeType = persisted<AppThemeType>(
    prefs,
    SettingsKeys.themeType,
    AppThemeType.system,
    reader: (p, k) { ... },
    writer: (p, k, v) => p.setString(k, v.name),
    debounce: Duration.zero,
  );
  // ... locale, customPrimaryColor, currentPresetId 同样模式
  ThemeManager(this.prefs);
  // ... dispose() 释放所有 signal
}
```

**关键改进**:
1. `prefs` 是构造注入的 `final` 字段（`@Singleton()`）— 不可能为 null
2. `persisted<T>()` 工厂在 signal 创建时即绑定 `prefs`，无需 `_doInit()` 模式
3. 持久化在 signal `.value` 写入时自动触发，无需单独的 `effect` 注册
4. 整个 `_initialized` / `_disposers` / `_doInit()` 模式消失 — 不可达状态被消除
5. `dispose()` 直接释放 signal，无副作用风险

**附加观察**: 旧 `m4` (dispose 后 `_initialized = false` 绕过 guards) 也自动消除 — 没有 `_initialized` 标志就无从绕过。

***

## 🔵 MINOR

### m1. `bookshelf_view_model.dart` L166-167 — read inside computed signal value

```dart
final pa = (readingProgress.value.value ?? {})[a.bookId] ?? 0;
```

在 `reloadBooks()` 中直接读取 `readingProgress.value.value`（AsyncState 的 data）。这是在 VM 方法中（非 effect/SignalBuilder 环境），`readingProgress` 作为 Signal 的 `.value` 读取**不会建立依赖追踪，只是快照。语义正确，但风格上会让读者误以为这是响应式读取。

**复核 (2026-06-16):** ✅ 信号已不存在

**验证**:
- `grep -r "readingProgress" lib/` 在 `bookshelf/application/` 下 0 命中
- 唯一匹配是 `l10n/` 下的本地化字符串（`'readingProgress' => '阅读进度'`）
- 旧 `BookshelfViewModel` 已被 `2026-06-14` 重构（`release/Signals v7.1.0` 迁移），新 VM 不再持有 per-book reading progress signal

**新 BookshelfViewModel** (232 行) 的状态面:
- `books: asyncSignal<List<BookshelfBook>>` — 列表 + 排序状态
- `selectedStatus: signal<BookStatus?>` — 状态筛选
- `searchKeyword: signal<String>` — 搜索词
- 三个 `persisted*` 字段（showReadingProgress / defaultSortType / isListView）— 视图偏好
- 通过 generation 计数器（`_reloadGeneration`）防止 race

**遗留风险**: 无

---

### m2. `reading_sessions_view_model.dart` L25 — mapSignal 全量替换未利用粒化能力

```dart
bookCache.value = {for (final b in books) b!.bookId: b};
```

`mapSignal` 支持逐 key 粒化更新（`.set()` / `.remove()`），但此处用了全量赋值。如果未来需要按 element 级别触发订阅，应改用 `bookCache.set(key, value)` 逐个添加。

**复核 (2026-06-16):** ⚠️ 未修 — 仍维持全量赋值

**当前实现** (`lib/features/statistics/application/reading_sessions_view_model.dart:25`):

```dart
final bookCache = mapSignal<String, Book>({});
// ...
bookCache.value = {for (final b in books) b!.bookId: b};
```

**实际影响**:
- 当前 `bookCache` 的订阅方（如果有）只在 `bookCache.value` 整体变化时重建
- 单条 book 更新也会触发所有订阅者重建
- `load()` 流程：拉 sessions → 拉关联 books（并行）→ 一次性写入 bookCache → 写入 sessions
- 每次 `load()` 调用都是 cold start（全量数据），不存在"部分更新"语义
- 全量赋值是**语义正确**的选择，粒化对当前调用模式无收益

**保留意见**: 当前实现是合理的。若未来引入 "实时增量更新"（如流式接收 sessions），可考虑改为 `bookCache.set(id, book)` 粒化。无需强制修改。

---

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

**复核 (2026-06-16):** ✅ 已重构 — 标志完全移除

**当前实现** (`lib/core/theme/theme_manager.dart:140-145`):

```dart
void dispose() {
  themeType.dispose();
  locale.dispose();
  customPrimaryColor.dispose();
  currentPresetId.dispose();
}
```

`prefs` 仍为 `final` 字段，不可置 null。dispose 后若外部代码访问 `themeManager.themeType` 会出现 `StateError('Signal is disposed')` — 比 NPE 更明确的错误信号。

**遗留风险**: 无。`@Singleton()` 生命周期由 `getIt` 管理，正常 dispose 路径仅在应用退出时触发。

---

### m5. `reader_config.dart` 全部 `persistedSignal` 字段类型推导一致但 manually annotated

```dart
late final theme = persistedEnum<ReaderTheme>(...);
late final fontSize = persistedDouble(...);
```

`persistedDouble()` 返回 `PersistedSignal<double>`，`persistedEnum` 返回 `PersistedSignal<T>`。Dart 可从右值推断类型，`late final` 不是必须写明类型注解。不过这是项目风格选择，不算错误。

**复核 (2026-06-16):** ⚠️ 部分 — 类型注解存在不一致

**当前实现** (`lib/core/reader/reader_config.dart:78-217`):

```dart
late final theme = persistedEnum(prefs, SettingsKeys.readerTheme, ReaderTheme.light, ...);  // 省略 <ReaderTheme>
late final fontSize = persistedDouble(prefs, SettingsKeys.readerFontSize, 16.0, ...);         // 无需 <T>
late final lineHeight = persistedDouble(...);
late final language = persistedEnum<LanguageType>(prefs, ...);                                // 保留 <LanguageType>
late final textAlign = persistedEnum(prefs, ..., TextAlign.justify, ...);
late final tapLayout = persistedEnum(prefs, ..., TapLayout.rightHanded, ...);
```

**观察**:
- `persistedDouble` / `persistedInt` / `persistedBool` — factory 名已含类型，无需也无法写 `<T>`
- `persistedEnum` — factory 接收类型参数，**所有** 16 个枚举字段理论上都可省略 `<T>`（Dart 可从默认参数 `ReaderTheme.light` / `LanguageType.auto` / `TextAlign.justify` 等推断）
- 当前风格不一致：`language` 显式写 `<LanguageType>`，其他枚举字段省略

**实际影响**: 零运行时/编译影响，纯风格问题。

**建议**: 统一为省略风格（或统一为显式风格）— 既然 m5 提出过，建议团队决定。无需在本 issue 修复。

***
