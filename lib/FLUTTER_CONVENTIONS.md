# Flutter 项目规范

## ViewModel 生命周期管理

ViewModel 的创建方式决定了它的生命周期、共享范围和内存管理方式。

### 三种模式

| 模式 | 生命周期 | 共享 | 释放 |
|------|---------|------|------|
| `@LazySingleton() class VM` + `getIt<VM>()` | 进程级 | 任意 Widget 共享同一实例 | 需手动调用 `dispose()` |
| `useMemoized(() => VM())` | Widget 级 | 私有，仅当前 Widget | 自动（Widget 拆解时 GC） |
| `useMemoized(() => getIt<VM>())` | 进程级（DI 容器持有），但缓存引用 | 同上，全局共享 | 同 getIt，页面销毁后不释放 |

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

3. **`useMemoized(() => getIt<VM>())` 是反模式**
   - 实例仍由 DI 持有，页面销毁不释放，`useMemoized` 只是缓存了引用
   - 误以为页面销毁后 VM 会释放，实际不会
   - 不如直接用 `getIt<VM>()`，语义更清晰

### 示例

| ViewModel | 消费者 | 使用模式 |
|-----------|--------|---------|
| `ReadingStatsViewModel` | `StatisticsPage`（仅此一处） | `useMemoized(() => ReadingStatsViewModel())` |
| `HomeViewModel` | 首页 + 侧边栏 + 搜索页可能需要 | `@LazySingleton` + `getIt<HomeViewModel>()` |
| `SearchViewModel` | `SearchPage`（仅此一处） | `useMemoized(() => SearchViewModel())` |

### 迁移检查清单

已有 `@LazySingleton` 的 ViewModel 是否需要改为 `useMemoized`:

- [ ] 只有一个 Widget 使用它？
- [ ] 页面切走后数据可以丢弃？
- [ ] 当前没有（或不需要）调用 `dispose()`？

全部 ✅ → 改 `useMemoized`，删除注解、DI 注册、`dispose()` 方法。
