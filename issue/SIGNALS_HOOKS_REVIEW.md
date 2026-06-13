# Signals Hooks 审查报告

> 审查范围: 所有 `HookWidget` 页面/组件文件共 27 个，覆盖 `lib/features/` 下的全部页面和部分子组件。

---

## 🔴 问题级别 1：容易混淆的 `useSignalEffect` 信号读取模式

### 文件: `lib/features/reader/page/reader_page.dart`

**A) L88-91 — 未使用的信号值读取**

```dart
useSignalEffect(() {
  fontRepo.currentFont.value;  // ← 仅为了依赖追踪而读值，结果丢弃
  vm.updateFont(fontRepo.currentFontFamily);
});
```

`fontRepo.currentFont.value` 被读取但值未使用。这是 signals 框架支持的 lazy tracking 模式，但代码意图不明确。若开启 `unused_result` lint 规则会报警。

**B) L94-99 — 冗余读取**

```dart
useSignalEffect(() {
  vm.showSearch.value;            // ← 无用：读而不用的重复
  if (!vm.showSearch.value) {     // ← 条件分支已经建立了依赖
    searchController.clear();
  }
});
```

第 95 行多余 — 第 96 行的条件读取已足够建立依赖。

---

## 🟡 问题级别 2：潜在正确性风险

### 1. 直接绕过 ViewModel 修改信号

**文件**: `lib/features/bookshelf/page/book_detail_page.dart:L200`

```dart
vm.book.value = AsyncState.data(
  book.copyWith(title: result['title'] ?? book.title, ...),
);
```

页面上层直接赋值到 `vm.book.value` 而不是调用 ViewModel 方法（如 `vm.editMetadata(...)`）。这绕过了 ViewModel 可能需要的持久化、校验或通知逻辑。若后续新增「编辑后自动持久化到磁盘」逻辑，必须修改此调用点。

### 2. `search_page.dart` 的重复订阅

**文件**: `lib/features/search/page/search_page.dart:L35-L45`

```dart
// 用 useSignalValue 订阅
final hasSearched = useSignalValue<bool, Signal<bool>>(vm.hasSearched);
final searchError = useSignalValue<String?, Signal<String?>>(vm.searchError);

// 用 useComputed 再次订阅相同信号
final searchResults = useComputed(() {
  if (!vm.hasSearched.value) return null;  // 重复
  if (vm.searchError.value != null) return null;  // 重复
  return vm.searchResults.value.value;
});
```

- `vm.hasSearched` 变化时 → `useSignalValue` 和 `useComputed` 双路触发 → 无效重建。
- 只需保留 `useComputed` + 检查 `searchResults.value != null`，`hasSearched` 的 `useSignalValue` 冗余。

### 3. `backup_page.dart` 用信号做 RPC 返回通道

**文件**: `lib/features/backup/page/backup_page.dart:L104, L144`

```dart
final result = await vm.performBackup();
if (!context.mounted) return;

// 不检查 performBackup 的返回值，而是从信号读取结果
if (vm.status.value == BackupStatus.exportingDone) { ... }
```

`performBackup()` 是 `async` 方法，但结果通过 `status` 信号传播而非返回值。这种模式脆弱：任何中间代码修改了 `status.value` 都会导致页面读到脏数据。

---

## 🔵 问题级别 3：冗余/风格问题

### 1. 大量多余的显式类型参数

几乎所有 `useSignalValue` 调用都写了第二个无用类型参数：

```dart
useSignalValue<Color?, Signal<Color?>>(themeManager.customPrimaryColor)
// 等价于（Dart 完全可推断）：
useSignalValue(themeManager.customPrimaryColor)
```

**波及文件**:

| 文件 | 影响行数 |
|------|---------|
| `lib/features/reader/page/widgets/reader_page_bindings.dart` | ~50 处（两个绑定函数） |
| `lib/app.dart` | 3 处 |
| `lib/features/reader/page/cache_manage_page.dart` | 3 处 |
| `lib/features/search/page/search_page.dart` | 2 处 |
| `lib/features/profile/page/typography/typography_settings_page.dart` | ~10 处 |
| `lib/features/profile/page/typography/typography_preview.dart` | 6 处 |
| `lib/features/profile/page/tts/behavior_section.dart` | 4 处 |
| `lib/features/profile/page/tts/bilingual_section.dart` | 3 处 |
| `lib/features/profile/page/tts/playback_section.dart` | 3 处 |
| `lib/features/profile/page/other/other_settings_page.dart` | 1 处 |
| `lib/features/profile/page/theme/theme_brightness_page.dart` | 4 处 |

### 2. `bookmark_manage_page.dart` 局部信号 + SignalBuilder 的混合订阅

在 `SignalBuilder` 内部读取 `isSearchMode.value`（来自 `useSignal`），会导致该信号变化时「useSignal 全局重建 + SignalBuilder 局部重建」两条路径都触发。

不是错误，但建议统一：若只在 SignalBuilder 内使用局部信号，考虑用 `useState` 代替 `useSignal` 以避免全局重建。

### 3. `cache_manage_page.dart` 中 AsyncSignal 与 Signal 类型不一致

```dart
useSignalValue<..., AsyncSignal<...>>(vm.books)          // AsyncSignal
useSignalValue<..., Signal<AsyncState<...>>>(vm.searchIndexStats)  // Signal<AsyncState>
```

`vm.books` 是 `AsyncSignal` 而 `vm.searchIndexStats` 是 `Signal<AsyncState<IndexStats>>`。类型不统一，可能是 ViewModel 设计不一致。

### 4. `app.dart` 效应写入与订阅同一信号

**文件**: `lib/app.dart:L33-L50`

```dart
useSignalEffect(() {
  if (autoTheme.autoThemeEnabled.value) {
    themeManager.themeType.value = ...;  // ← 写
  }
});
final themeType = useSignalValue(themeManager.themeType);  // ← 读
```

写入操作通过 `useSignalEffect` 重运行可能触发自身订阅。当前因分支控制无实际风险，但应加注释说明安全理由。

---

## ✅ 确认正确的模式

以下模式经检查全部正确：

| 模式 | 用法位置 | 状态 |
|------|---------|:----:|
| `useSignal` 管理局部组件状态 | `bookshelf_page`, `bookmark_manage_page`, `book_detail_page`, `wifi_transfer_page`, `reader_page` | ✅ |
| `useSignalValue` 订阅外部 VM 信号 | 全库惯例 | ✅ |
| `SignalBuilder` 包裹局部渲染子树 | `sync_page`, `bookshelf_page`, `bookmark_manage_page`, `category_manage_page` | ✅ |
| `useSignalEffect` 消费一次性消息 | `bookshelf_page` (feedback), `reader_page` (toastMessage) | ✅ |
| `useMemoized` + `getIt` 获取单例 | 全库惯例 | ✅ |
| `useRef` 保存 `Timer` 引用 | `bookshelf_page`, `reader_page`, `search_page` | ✅ |

---

## 修复建议优先级

1. **立即修**: `reader_page.dart L88-91` → 改为 `final font = fontRepo.currentFont.value; vm.updateFont(fontRepo.currentFontFamily);`
2. **修**: `reader_page.dart L95` → 删除冗余行
3. **修**: `book_detail_page.dart` → 抽取 `vm.book.value = AsyncState.data(...)` 到 ViewModel 方法中
4. **修**: `search_page.dart` → 消除 `hasSearched`/`searchError` 的重复订阅，由 `useComputed` 单一来源
5. **可选**: 全局清理多余的显式类型参数 `<..., Signal<...>>`（纯风格减负，不影响行为）
6. **文档**: `app.dart` 的 autoTheme 效应加注释解释为什么写 `themeType` 是安全的
