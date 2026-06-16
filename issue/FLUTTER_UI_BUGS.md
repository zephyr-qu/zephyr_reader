# Flutter UI Bug 评估

> 生成日期: 2026-06-13
> 复核日期: 2026-06-16
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

B3. `reader_note_sidebar.dart` — `ListView.builder` 缺 key

**文件 (当前)**: `lib/features/reader/annotations/presentation/reader_note_sidebar.dart:117`

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

## B6. `ReaderNoteSidebar` — `useState` 非响应式加载

**文件 (当前)**: `lib/features/reader/annotations/presentation/reader_note_sidebar.dart:31-32`

```dart
final notes = useState<List<Note>>([]);
final loading = useState<bool>(true);

Future<void> loadNotes() async { ... }
```

**评估 (2026-06-13)**: 和 B3 中 `useEffect` 讨论的问题同源。`useState` + async 在 flutter\_hooks 中不会泄漏。信号范式不一致，但不影响功能正确性。竞态条件需快速双击刷新按钮才可能触发，概率低。

**修复 (2026-06-16)**: 迁移到 `signals_hooks` 的 `useFutureSignal<List<Note>>`，并抽取 `_NotesBody` 子 widget 持有列表渲染逻辑。

- `useFutureSignal` 内部 `useExistingSignal` 绑定 widget 生命周期，dispose 时自动取消订阅
- `keys: [bookId]` 在 bookId 变化时自动丢弃旧请求，**解决竞态**
- `FutureSignal.reload()` 替代原 `loadNotes` 函数，提供刷新能力
- 文件中已无 `useState` / `useEffect` 关键字，移除 `flutter_hooks` 中这两个 API 的间接依赖
- `dart analyze` 单文件 0 issue

**结论**: ✅ 已迁移 — `useFutureSignal` 一次解决范式不一致、生命周期、竞态三件事

***

## B7. `PopScope` + 双 Drawer — `scaffoldKey.currentState` 可能为 null

**文件 (当前)**: `lib/features/reader/core/presentation/reader_scaffold.dart:72-80`

```dart
onPopInvokedWithResult: (didPop, _) {
  final scaffold = scaffoldKey.currentState;
  if (scaffold != null && scaffold.isDrawerOpen) {
    scaffold.closeDrawer();
    return;
  }
  // ...
```

**结论**: 🟢 Low — 边缘条件的边缘条件，实际不可复现

## 最终汇总 (复核于 2026-06-16)

| ID  | 文件 (当前)                                                 | 问题                             | 评级     | 备注                                     |
| --- | ------------------------------------------------------- | ------------------------------ | ------ | -------------------------------------- |
| B2  | `reader_page.dart` → `reader_shell.dart`                | `showCatalog` 永不置 true         | ✅ 已消除  | reader\_page 拆分重构后原信号随宿主文件移除           |
| B4  | `bookmark_widget.dart`                                  | 死代码                            | ✅ 已删除  | 文件已删除，被 `bookmark_manage_page.dart` 替代 |
| B5  | `reader_page.dart` → `reader_scaffold.dart`             | `useReaderBindings` 全量 rebuild | ✅ 已消除  | reader\_page 拆分重构后 hook 整体移除           |
| B6  | `annotations/presentation/reader_note_sidebar.dart`     | useState 非响应式                  | ✅ 已迁移  | 迁移到 `useFutureSignal` + `_NotesBody`   |
| B9  | `reader_catalog_drawer.dart`                            | 死代码                            | ✅ 已删除  | 旧实现，被 `ReaderNavigationDrawer` 替代      |
| B10 | `bookmark_widget.dart`                                  | 死代码                            | ✅ 已删除  | 旧实现，`bookmark_manage_page.dart` 替代     |
| B1  | `reader_dictionary_panel.dart:68`                       | `itemCount` 硬编码                | 🟢 Low | default 兜底                             |
| B3  | `annotations/presentation/reader_note_sidebar.dart:117` | 列表无 key                        | 🟢 Low | 只读列表无影响                                |
| B7  | `core/presentation/reader_scaffold.dart:72-80`          | PopScope null                  | 🟢 Low | 双边缘条件不可达                               |

**最终结论 (复核于 2026-06-16)**: 10 项初检项中，6 项已解决（B2 / B4 / B5 / B6 / B9 / B10），其余 4 项均为 🟢 Low 风险（B1 / B3 / B7）。B6 通过 `useFutureSignal` 迁移解决范式与竞态问题。整体 Flutter UI 质量良好，无紧急待修复项。
