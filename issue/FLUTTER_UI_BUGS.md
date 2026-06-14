# Flutter UI Bug 评估

> 生成日期: 2026-06-13
> 范围: `lib/` (Reader UI 为主)

***

## 评估方法

逐项验证代码路径、检查实际运行时影响、排除死代码和边缘条件不可达的情况。

***

## B1. `reader_dictionary_panel.dart` — `itemCount: 5` 硬编码

**文件**: `lib/features/reader/page/reader_dictionary_panel.dart:68`

```dart
ListView.builder(
  itemCount: 5,  // 与下方 switch case 0-4 耦合
  itemBuilder: (context, index) {
    switch (index) {
      case 0 ... 4: // 各 section
      default: return const SizedBox.shrink();  // 兜底
    }
  },
),
```

**评估**: `default` 分支返回 `SizedBox.shrink()`，多 case / 少 case 不会 crash，最多多一个空白项或少一个 section。面板内容固定不变，不存在运行时动态调整的场景。

**结论**: 🟢 Low — 维护期代码异味，无运行时风险

***

## B2. `reader_page.dart` — `showCatalog` 信号永不置 `true`

**文件**: `lib/features/reader/page/reader_page.dart:68,482,524`

```dart
final showCatalog = useSignal(false);   // 声明
// ...
onShowCatalog: () =>
    withTimer(() => scaffoldKey.currentState?.openDrawer()),  // 未置 true
// ...
showCatalog.value = false;              // 仅置 false
// ...
!showCatalog.value &&                   // 始终为 true
```

**评估**: Drawer 打开时 Scaffold 自带的 ModalBarrier 已拦截下层触摸，`showCatalog` 即使正确 toggle 也是冗余。该信号从未被置 `true`，是死代码。

**结论**: 🟢 Low — 死代码，无 visible impact

***

## B3. `reader_note_sidebar.dart` — `ListView.builder` 缺 key

**文件**: `lib/features/reader/page/widgets/reader_note_sidebar.dart:117`

```dart
ListView.builder(
  itemCount: notes.value.length,
  itemBuilder: (context, index) {
    final note = notes.value[index];
    return InkWell(  // 无 key
```

**评估**: 笔记列表仅展示+点击跳转，无编辑/展开/checkbox 等交互状态，缺 key 不会引起可见的状态异常。Drawer 每次打开都重建，全量 rebuild 的性能影响可忽略。

**关于** **`useEffect`** **无清理**: `flutter_hooks` 的 `useState` setter 使用弱引用，widget 卸载后写入是空操作。**不存在内存泄漏**。竞态条件理论上可能（快速切换 `bookId` 时前一个请求覆盖后一个数据），但 `ReaderNoteSidebar` 作为 `endDrawer`，用户需关闭→重新打开才能切换 `bookId`，操作间隔足够请求完成，实际触发概率极低。

**结论**: 🟢 Low — 只读列表无状态，useEffect 无实际泄漏

***

## B4. `bookmark_widget.dart` — `ListView.builder` 缺 key

**文件**: `lib/features/reader/page/widgets/bookmark_widget.dart:97`

```dart
ListView.builder(
  itemBuilder: (context, index) {
    return _buildBookmarkItem(bookmark, textColor, l10n);  // 无 key
```

**评估**: 全项目搜索确认 `BookmarkWidget` **从未被实例化**，是死代码。

**结论**: 🟢 Low — 死代码，影响为零

***

## B5. `ReaderPage` 全量 rebuild — `useReaderBindings`

**文件**: `lib/features/reader/page/reader_page.dart:116`

```dart
final b = useReaderBindings(vm);
```

`useReaderBindings` 订阅 \~30 个信号（字体、行距、主题、页码、进度、autoScrollTick 等）。**任一**信号变化时 `b` 重建，触发整棵 widget 树（Scaffold + drawer + endDrawer + toolbar + overlay 面板）全量 build。

`ReaderContent` 内部使用 `useReaderContentBindings` 隔离了部分重建，但 `ReaderNavigationDrawer`、`ReaderNoteSidebar`、`ReaderBottomToolbar` 无条件跟随重建。

**关键路径**: auto-scroll tick（TTS 滚动时每 \~100ms 触发一次） → `b` 重建 → 全量 rebuild。在低端设备上可感知 jank。

**结论**: ⚠️ Medium — 低端设备 auto-scroll/TTS 场景下可感知的性能问题

***

## B6. `ReaderNoteSidebar` — `useState` 非响应式加载

**文件**: `lib/features/reader/page/widgets/reader_note_sidebar.dart:31-46`

```dart
final notes = useState<List<Note>>([]);
final loading = useState<bool>(true);

Future<void> loadNotes() async { ... }
```

**评估**: 和 B3 中 `useEffect` 讨论的问题同源。`useState` + async 在 flutter\_hooks 中不会泄漏。信号范式不一致，但不影响功能正确性。竞态条件需快速双击刷新按钮才可能触发，概率低。

**结论**: 🟢 Low — 范式不一致，实际风险低

***

## B7. `PopScope` + 双 Drawer — `scaffoldKey.currentState` 可能为 null

**文件**: `lib/features/reader/page/reader_page.dart:453-471`

```dart
onPopInvokedWithResult: (didPop, _) {
  final scaffold = scaffoldKey.currentState;
  if (scaffold != null && scaffold.isDrawerOpen) {
    scaffold.closeDrawer();
    return;
  }
  // ...
```

**评估**: `scaffoldKey.currentState` 在 widget dispose 后才为 null。Drawer 关闭动画 \~200ms，要在动画期间按返回键且 state 恰好在 null 窗口期才可能触发。即使触发，drawer 已在关闭中，fallthrough 到 `context.pop()` 不会产生可见的异常行为。双边缘条件叠加，实际不可复现。

**结论**: 🟢 Low — 边缘条件的边缘条件，实际不可复现

***

## 最终汇总

| ID  | 文件                             | 问题                     | 评级     | 备注                                 |
| --- | ------------------------------ | ---------------------- | ------ | ---------------------------------- |
| B9  | `reader_catalog_drawer.dart`   | 死代码                    | ✅ 已删除  | 旧实现，被 `ReaderNavigationDrawer` 替代  |
| B10 | `bookmark_widget.dart`         | 死代码                    | ✅ 已删除  | 旧实现，`bookmark_manage_page.dart` 替代 |
| B1  | `reader_dictionary_panel.dart` | `itemCount` 硬编码        | 🟢 Low | default 兜底                         |
| B2  | `reader_page.dart`             | `showCatalog` 永不置 true | 🟢 Low | 死代码                                |
| B3  | `reader_note_sidebar.dart`     | 列表无 key                | 🟢 Low | 只读列表无影响                            |
| B5  | `reader_page.dart`             | 全量 rebuild             | 🟢 Low | 实际 impact 已降级                      |
| B6  | `reader_note_sidebar.dart`     | useState 非响应式          | 🟢 Low | 范式不一致                              |
| B7  | `reader_page.dart`             | PopScope null          | 🟢 Low | 双边缘条件不可达                           |

**最终结论**: 10 项初检项中，2 项死代码已删除，1 项误报，其余 7 项均为 🟢 Low。整体 Flutter UI 质量良好，无紧急待修复项。
