# Flutter 项目规范

## ViewModel 生命周期管理

ViewModel 的创建方式决定了它的生命周期、共享范围和内存管理方式。

### 三种模式

| 模式                                          | 生命周期               | 共享               | 释放                |
| ------------------------------------------- | ------------------ | ---------------- | ----------------- |
| `@LazySingleton() class VM` + `getIt<VM>()` | 进程级                | 任意 Widget 共享同一实例 | 需手动调用 `dispose()` |
| `useMemoized(() => VM())`                   | Widget 级           | 私有，仅当前 Widget    | 自动（Widget 拆解时 GC） |
| `useMemoized(() => getIt<VM>())`            | 进程级（DI 容器持有），但缓存引用 | 同上，全局共享          | 同 getIt，页面销毁后不释放  |

### 决策规则

**一条原则决定生命周期**：一个 ViewModel 被几个 Widget 消费？

```
              被几个 Widget 消费？
              ┌──────────┐
              │    1     │
              └────┬─────┘
                   │
          ┌────────▼────────┐
          │ useMemoized     │
          │   () => VM()    │
          │                 │
          │ 生命周期→Widget  │
          │ 自动释放        │
          └─────────────────┘


              ┌──────────┐
              │   ≥ 2    │
              └────┬─────┘
                   │
          ┌────────▼────────┐
          │ @LazySingleton  │
          │   + getIt<VM>() │
          │                 │
          │ 生命周期→进程   │
          │ 需要 dispose()  │
          └─────────────────┘
```

### 细则

1. **一个 Widget 消费** → `useMemoized(() => VM())`
   - VM 构造简单，没有复杂的 DI 依赖链
   - 页面销毁后状态不需要保留
   - 避免跨页面信号互相覆盖（单例场景常见问题）
2. **两个以上 Widget 需要同步同一份状态** → `@LazySingleton` + `getIt<VM>()`
   - 多个页面/组件实时监听同一信号
   - 必须正确实现 `dispose()`，并在 Widget 销毁时调用
   - 建议在 `useEffect` 的 cleanup 中调用 `dispose()` 以避免泄漏
3. **`useMemoized(() => getIt<VM>())`** **是反模式**
   - 实例仍由 DI 持有，页面销毁不释放，`useMemoized` 只是缓存了引用
   - 误以为页面销毁后 VM 会释放，实际不会
   - 不如直接用 `getIt<VM>()`，语义更清晰

### 示例

| ViewModel               | 消费者                    | 使用模式                                         |
| ----------------------- | ---------------------- | -------------------------------------------- |
| `ReadingStatsViewModel` | `StatisticsPage`（仅此一处） | `useMemoized(() => ReadingStatsViewModel())` |
| `HomeViewModel`         | 首页 + 侧边栏 + 搜索页可能需要     | `@LazySingleton` + `getIt<HomeViewModel>()`  |
| `SearchViewModel`       | `SearchPage`（仅此一处）     | `useMemoized(() => SearchViewModel())`       |

### 迁移检查清单

已有 `@LazySingleton` 的 ViewModel 是否需要改为 `useMemoized`:

- [ ] 只有一个 Widget 使用它？
- [ ] 页面切走后数据可以丢弃？
- [ ] 当前没有（或不需要）调用 `dispose()`？

全部 ✅ → 改 `useMemoized`，删除注解、DI 注册、`dispose()` 方法。

## 首次数据加载：`useEffect` vs `useFutureSignal`

初次加载数据时，选择取决于**数据状态的归属层级**。

### 决策树

```
                             数据由谁管理？
                             ┌──────────┐
                             │  VM 层   │
                             └────┬─────┘
                                  │
                    ┌─────────────┼─────────────┐
                    │ 单路数据    │             │ 多路数据
                    └──────┬──────┘             └──────┬──────┘
                           │                           │
              ┌────────────▼────────┐       ┌──────────▼──────────┐
              │ useFutureSignal     │       │     useEffect       │
              │ 消费其.value驱动UI   │       │ VM 管理多路信号     │
              │ 自带loading/error    │       │ Widget 逐路订阅     │
              └─────────────────────┘       └─────────────────────┘


                             ┌──────────┐
                             │ Widget 层 │
                             └────┬─────┘
                                  │
                     ┌────────────▼────────────┐
                     │   useFutureSignal       │
                     │  消费 .value 驱动 UI     │
                     │  自带 race protection   │
                     └─────────────────────────┘
```

### 细则

1. **Widget 层直接加载** → `useFutureSignal`
   - 数据不是通过 VM 信号暴露的
   - 消费返回的 `FutureSignal<T>` 的 `.value`（`AsyncState<T>`）驱动 UI
   - 自带竞态保护（widget 卸载时抛弃旧请求）
   - loading / error / data 三态自动跟踪
   ```dart
   // ✅ 正确：消费 FutureSignal 的 .value
   final loadOp = useFutureSignal(() => repository.fetchBooks());
   // 在 UI 中
   loadOp.value.map(
     loading: () => const CircularProgressIndicator(),
     error: (e, _) => ErrorView(e),
     data: (books) => BookList(books),
   );
   ```
2. **VM 层管理数据，Widget 订阅多个独立信号** → `useEffect`
   - ViewModel 的 `loadData()` 或 `initialize()` 填充多个独立信号
   - Widget 通过 `useSignalValue(vm.xxx)` 逐路订阅
   - `useFutureSignal` 返回 `AsyncState<void>`，无法区分多路数据的各自状态
   ```dart
   // ✅ 正确：useEffect 触发，VM 信号逐路消费
   useEffect(() {
     vm.loadData();
     return null;
   }, []);

   final AsyncState<A> dataA = useSignalValue(vm.dataA);
   final AsyncState<B> dataB = useSignalValue(vm.dataB);
   ```
3. **禁止模式：丢弃** **`useFutureSignal`** **返回值**
   ```dart
   // ❌ 创建了 FutureSignal 但不消费
   useFutureSignal(() => vm.loadData());
   ```
   当 VM 管理多路数据时，`useFutureSignal` 的唯一作用就是创建了一个不被读取的信号对象，比 `useEffect` 更重且无任何收益。

### 典型对照

| 场景                                                                              | 当前代码                      | 推荐                |
| ------------------------------------------------------------------------------- | ------------------------- | ----------------- |
| `home_page.dart` — `vm.loadData()` 产生 `recentBooks` + `dailyRecords` 两路信号       | `useFutureSignal`（已丢弃返回值） | 改为 `useEffect`    |
| `backup_page.dart` — `vm.initialize()` 产生 `currentStats` + `lastBackupAt` 等多路   | `useFutureSignal`（已丢弃返回值） | 改为 `useEffect`    |
| `learning_notes_page.dart` — `vm.initialize()` 产生 `noteList` + `bookTitles` 等多路 | `useFutureSignal`（已丢弃返回值） | 改为 `useEffect`    |
| 直接使用 repository、provider 在 widget 层获取单路数据                                       | —                         | `useFutureSignal` |

## Widget 基类选择：`HookWidget` vs `SignalHookWidget`

`signals_hooks` 提供了两种支持 hooks 的 widget 基类，区别在于**信号追踪机制**。

| <br />   | `HookWidget`（flutter\_hooks）               | `SignalHookWidget`（signals\_hooks） |
| -------- | ------------------------------------------ | ---------------------------------- |
| hooks 支持 | ✅ `useEffect`, `useState`, `useMemoized` 等 | ✅ 全部 hooks                         |
| 隐式信号追踪   | ❌ `.value` 访问不自动订阅                         | ✅ 任何 `.value` 访问自动追踪，值变即重建         |
| 订阅方式     | 显式：`useSignalValue(vm.xxx)`                | 隐式：直接读 `vm.xxx.value`              |
| 可观测性     | 订阅列表一目了然                                   | 隐式订阅，需扫描整个 build 确定触发源             |
| 粒度控制     | 精细：可选择性订阅                                  | 粗放：所有 build 内访问的信号都触发重建            |

### 决策规则

```
                              本次 build 会读取几个信号？
                              ┌──────────────┐
                              │     ≤ 3      │
                              └──────┬───────┘
                                     │
                     ┌───────────────▼───────────────┐
                     │  SignalHookWidget              │
                     │  直接读 .value，省去 useSignalValue │
                     │  代码最简洁                      │
                     └───────────────────────────────┘

                              ┌──────────────┐
                              │     ≥ 4      │
                              └──────┬───────┘
                                     │
                     ┌───────────────▼───────────────┐
                     │  HookWidget + useSignalValue   │
                     │  显式列出每个订阅               │
                     │  build 函数即"数据依赖清单"      │
                     └───────────────────────────────┘
```

### 细则

1. **Page 层（多信号，≥ 4 个）** → `HookWidget` + `useSignalValue`

   Page 是信号消费最密集的地方（ViewModel 的 loading / data / error / 各种状态）。
   用 `useSignalValue` 显式声明每个订阅，build 方法本身就是一张数据依赖清单，
   任何人阅读代码都能一眼看出这个页面依赖哪些数据：
   ```dart
   // ✅ 页面级别的显式订阅：build = 数据依赖清单
   class BookDetailPage extends HookWidget {
     @override
     Widget build(BuildContext context) {
       final vm = useMemoized(...);
       final loading = useSignalValue(vm.loading);
       final book = useSignalValue(vm.book);
       final progress = useSignalValue(vm.progress);
       ...
     }
   }
   ```
2. **Leaf 层（少量信号，≤ 3 个）** → `SignalHookWidget`

   小组件（如状态卡片、统计图标）通常只消费 1\~2 个信号。
   用 `SignalHookWidget` 可以直接读 `.value`，省去 `useSignalValue` 的模板代码：
   ```dart
   // ✅ 小组件：隐式追踪，省去模板代码
   class SyncStatusBadge extends SignalHookWidget {
     @override
     Widget build(BuildContext context) {
       // 隐式追踪：读取即订阅
       final status = vm.syncStatus.value;
       final lastTime = vm.lastSyncTime.value;
       return Text('状态: $status, 上次: $lastTime');
     }
   }
   ```
3. **`SignalHookBuilder`** **用于局部子树**

   当一个 `HookWidget` 中某个子树需要独立按信号粒度重建，可以用 `SignalHookBuilder`：
   ```dart
   // 只有 status 变化时，这个子树重建，不触发整个页面
   SignalHookBuilder(
     builder: (context) {
       return Text('Status: ${vm.status.value}');
     },
   )
   ```

### 当前项目评估

| 维度   | 结论                                         |
| ---- | ------------------------------------------ |
| 当前基线 | 34+ 页面全部使用 `HookWidget` + `useSignalValue` |
| 一致性  | 已建立稳定模式                                    |
| 推荐策略 | **Page 层保持现状**，新写小组件可选用 `SignalHookWidget` |
| 不推荐  | 全局迁移。无实际收益，反而引入不一致和回归风险                    |

**核心原则：Page 层显式优先（维护可读性），Leaf 层隐式优先（减少模板）。**

## Signals 内存管理（dispose 规则）

### 信号不需要 dispose 的情况（大多数场景）

| 场景                             | 不需要 dispose 的理由    |
| ------------------------------ | ------------------ |
| ViewModel 是单例（存活到进程结束）         | 对象不会回收，dispose 无意义 |
| 纯 `signal<T>()`，无 `effect` 订阅  | 无订阅者即可被 GC 回收      |
| `useSignalEffect` 消费的信号        | unmount 时自动取消订阅关系  |
| Widget 帧内临时创建（`SignalBuilder`） | 生命周期由框架管理          |

**结论**: signals 库没有"全局信号注册表"。`Signal<T>` 是普通 Dart 对象。
无外部订阅时，GC 可以正常回收。

### 必须 dispose 的场景

| 构造                                              | 必须 dispose | 原因                                      |
| ----------------------------------------------- | ---------- | --------------------------------------- |
| `effect(fn)` 直接挂在 ViewModel 属性上                 | ✅ **必须**   | effect 注册在 signals 全局调度器，不 dispose 永远执行 |
| `PersistedSignal`                               | ✅ **必须**   | debounce `Timer` 不停止，closure 链阻止 GC     |
| `Timer`、`StreamSubscription` 等资源                | ✅ **必须**   | Dart 标准资源管理                             |
| `asyncSignal` / `futureSignal` / `streamSignal` | ⚠️ **建议**  | 可能持有未取消的内部订阅                            |
| `computed()`                                    | ⚠️ **建议**  | 惰性 + 无订阅时可 GC，dispose 更安全               |

### 如何判断是否需要 dispose

一条规则：**"这个东西如果不管它，会不会一直在后台干活？"**

```dart
final count = signal(0);           // ❌ 不需要 — 没人在监听就是个值
final dispose = effect(() { ... });// ✅ 必须 — 全局调度器持有引用
final prefs = persistedBool(...);  // ✅ 必须 — Timer 一直在跑
final timer = Timer(...);          // ✅ 必须 — Timer 不停止
final computed = computed(() => ...);// ⚠️ 建议 — 安全大于泄漏
```

### ViewModel dispose 模板

```dart
class MyViewModel {
  final count = signal(0);
  late final PersistedSignal<bool> flag;
  void Function()? _effectDispose;

  void init() {
    _effectDispose = effect(() { ... });
  }

  void dispose() {
    _effectDispose?.call();
    flag.dispose();
    // 纯 signal 不需要手动 dispose
  }
}
```

保持当前架构：

```
页面层（HookWidget） ← 负责信号订阅
  └─ 组件层（StatelessWidget） ← 只渲染纯值
```

这层分离本身健康，**不要为没有 signal 依赖的组件引入** **`SignalWidget`**— 既不需要，也不符合单一职责。

### CHECKLIST

提交代码前确认：

- [ ] `effect()` 的返回值是否被保存并在 dispose 时调用？
- [ ] `PersistedSignal` 是否在 dispose 中释放？
- [ ] `Timer`、`StreamSubscription` 是否被 cancel/dispose？
- [ ] 如果 ViewModel 是单例，上述问题不存在（但需确认确实是单例）

