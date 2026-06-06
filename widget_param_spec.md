# Widget 构造参数规范

## 核心原则

Widget 能从 `context` 读到的，就不应该通过构造参数传。

## 规则

### ❌ 禁止传参（InheritedWidget 可读）

Widget 内部直接调用：

```dart
final theme = Theme.of(context);
final l10n = AppLocalizations.of(context)!;
final cs = Theme.of(context).colorScheme;
final media = MediaQuery.of(context);
```

这些值在任何 `StatelessWidget.build(BuildContext context)` 或 `State.build()` 中都可以自读，传参徒增样板、破坏封装。

### ✅ 允许传参（具体情况）

| 数据类型 | 做法 | 理由 |
|---------|------|------|
| **纯展示数据**（书名、数量、列表） | 传具体值 | 组件只关心数据，不关心来源 |
| **ViewModel**（多操作） | 传整个 VM 实例 | 组件需要调用多个方法，拆成 N 个回调不如传一个 VM |
| **单个回调**（onChanged、onTap） | 传 `VoidCallback` / `ValueChanged<T>` | 接口最小化，方便测试 |
| **ViewModel**（需要 Widget 测试） | 传回调 | 测试时传入简单闭包，避免 mock 整个 VM |
| **路由 / DI 对象** | 传实例 | 不是 InheritedWidget，组件无法自读 |

### 判断流程图

```
Widget 能自己读到这个值吗？
  ├─ 是（InheritedWidget）→ ❌ 禁止传参
  └─ 否
       ├─ 只需要一个操作 → 传单个回调
       ├─ 需要多个相关操作，且只在 feature 内部用 → 传 VM
       └─ 需要多个相关操作，且需要独立测试 → 传多个回调
```

## 现状

- `lib/shared/` 已彻底删除，其内容被合并到 `core/` 对应目录
- `theme`/`l10n`/`colorScheme` 已全部从公开 Widget 构造参数中移除
- `vocab_list_item_tile.dart`、`vocab_stats_row.dart`、`vocab_status_chip.dart`、`vocab_word_list_view.dart` 等 11 个 Widget 已清理
