# Signals 架构审查报告

> 审查范围：全库 17 个 ViewModel、11 个消费页面、signals 相关 hooks 用法
> 审查标准：signals-dart、signals-hooks、signals-flutter 最佳实践
> 状态：**全部已修 / 已评估无需改**

---

## 架构评价

方向正确。**ViewModel 持有信号 → HookWidget 页面用 `useSignalValue` 解包 → StatelessWidget 渲染纯值**。这层分离清晰，没有信号逃逸到展示层组件。

### ✔️ 做对了的

1. **单向数据流**：VM（信号源）→ HookWidget（订阅）→ StatelessWidget（渲染纯值）
2. **`useSignalValue` 主导订阅**：没有把信号对象传到展示层
3. **`asyncSignal` 管理异步状态**：HomeViewModel、SearchViewModel、ProfileViewModel 使用 asyncSignal 自带 loading/error/data 三态
4. **局部 UI 状态用 `useSignal`**：bookshelf_page 的 batchMode、bookmark_manage_page 的 sortBy 等用 `useSignal` 管理页面内状态，不污染 VM
5. **`computed()` 正确用于派生**：fontSizeDouble、progressText、dailyMinutes 等派生值用 computed 实现惰性缓存

---

## 已修复的问题

| # | 严重度 | 问题 | 修复内容 |
|---|---|---|---|
| 1 | **P0** | 丢弃 `useFutureSignal` 返回值 | home_page / backup_page / learning_notes_page 改为 `useEffect` 初始化 |
| 2 | **P1** | ReaderViewModel effect 永不重建 | auto-scroll effect 从构造器移至 `initialize()`，随新书重建 |
| 3 | **P1** | ThemeManager effects 无 dispose | 4 个 effect disposer 被捕获到 `_disposers`，增加 `dispose()` 方法 |
| 4 | **P2** | `batch()` 使用不足 | SearchViewModel / LearningNotesViewModel / BookDetailViewModel 的关联写入包裹 `batch()` |

### 1. `useFutureSignal` → `useEffect`（P0）

`useFutureSignal` 会创建一个不被消费的 `FutureSignal`，比 `useEffect` 重且无收益。三处初始化调用均改为：

```dart
useEffect(() {
  vm.initialize();
  return null;
}, []);
```

### 2. ReaderViewModel auto-scroll effect（P1）

effect 在构造器中创建（单例只跑一次），而 `resetForNewBook()` 销毁 disposer 后不再重建 → 切换书籍自动滚动永久失效。

**修复：** 将 effect 从构造器移至 `initialize()`，每次加载新书重建，创建前先清理旧 effect：

```dart
_diposers.add(effect(() {
  if (_config.autoScroll.value && sessionManager.isReading.value) {
    chapterManager.startAutoScroll();
  } else {
    chapterManager.stopAutoScroll();
  }
}));
```

### 3. ThemeManager dispose（P1）

4 个持久化 effect 的 disposer 从未被捕获。增加 `_disposers` 列表和 `dispose()` 方法：

```dart
void dispose() {
  for (final d in _disposers) d();
  _disposers.clear();
  _initialized = false;
}
```

### 4. `batch()` 补全（P2）

对关联写入包裹 `batch()`，确保原子通知：

| ViewModel | 写入点 |
|---|---|
| `SearchViewModel` | `doFullSearch` 的三阶段 + `clear()` 6 信号 |
| `LearningNotesViewModel` | `refresh` / `_loadNotes` / `setNoteFilterBook` |
| `BookDetailViewModel` | `loadData` 的开始 + 完成两阶段 |

---

## 已评估无需改

| 问题 | 结论 |
|---|---|
| asyncSignal 未 dispose（6 个 VM） | asyncSignal 无外部订阅，GC 可回收；单例 VM 的信号存活到进程退出是预期行为 |
| `useSignalValue` type args 冗余 | Dart 3 不支持部分类型推断，`<T, Signal<T>>` 全量形式是必要写法 |
| `useComputed` 未在页面侧使用 | `computed()` 在 VM 侧是正确的放置位置，无需搬到页面 |
| 非单例 VM 无 dispose() | 页面级 VM 通过 `useMemoized` 创建，GC 自动回收 |

---

## 关键注意事项

### `useSignalValue` 类型参数

`useSignalValue<T, S extends ReadonlySignal<T>>` 带两个类型参数。Dart 3 必须传 0 或 2 个。全量形式为必要写法：

```dart
final stats  = useSignalValue<VocabStats?,       Signal<VocabStats?>>(vm.stats);
final words  = useSignalValue<AsyncState<List<Vocab>>, AsyncSignal<List<Vocab>>>(vm.words);
final loaded = useSignalValue<bool,              Signal<bool>>(vm.loaded);
```

### 信号清理策略

- `effect()` – 必须保存 disposer 并在适当时机调用
- `asyncSignal` / `StreamSignal` / `TimerSignal` – 内部有订阅，需在非单例 VM 的 `dispose()` 中清理
- 普通 `signal()` / `computed()` – GC 自行回收

### 派生计算

派生值（如 `fontSizeDouble`、`isBackupStale`）用 `computed()` 而非普通 getter，确保：
1. 惰性缓存，避免重复计算
2. 在 `effect()` 或 `useSignalEffect` 中被读取时正确追踪依赖
