# Vocabulary Feature 深度分析报告

> 分析基准：`lib/features/vocabulary/` — 2 个文件
> 检测日期：2026-06-03
> 最后更新：2026-06-04（主题色、筛选闪烁、chip 统一、错误消息、switch-case、dispose、滑动确认、PopupMenu displayName、bookId、测试 已修复；filterStatus 已跳过）

***

## 1. 架构总览

```
vocabulary/
├── application/
│   └── vocabulary_view_model.dart   ← 生词 VM（~79 行，@injectable factory）
└── page/
    └── vocabulary_page.dart         ← 生词本页（~350 行）
```

**数据流**：

```
VocabularyPage → VocabularyViewModel
                    → vocab_api.listVocabularyByStatus(status, wordList)
                    → vocab_api.getVocabularyStats()
                    → vocab_api.updateVocabularyStatus()
                    → vocab_api.deleteVocabulary()
```

**页面结构**：

```
AppBar("生词本" + 刷新按钮)
├── _buildStatsRow
│   ├── 状态筛选 chips: 全部 | 未学 | 学习中 | 已忽略 | 已掌握
│   └── 词库筛选 chips: 全部词库 | CET-4 | CET-6 | IELTS | TOEFL
└── _buildWordList (ListView.separated + Dismissible swipe-to-delete)
```

***

## 2. P0 级问题

### 2.1 `_buildSubtitle` 使用 `Colors.grey` ✅ 已修复

```dart
style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
```

改用 `theme.colorScheme.onSurfaceVariant`，暗色模式下自动适配。

### 2.2 `Dismissible` 删除背景硬编码 `Colors.red` ✅ 已修复

```dart
color: theme.colorScheme.error,
child: const Icon(PhosphorIconsRegular.trash, color: Colors.white),
```

改用 `theme.colorScheme.error`，暗色模式下主题自行决定暗红/亮红色调。

### 2.3 国际化 — 全部字符串硬编码

| 位置                             | 字符串                                    |
| ------------------------------ | -------------------------------------- |
| `vocabulary_page.dart:51`      | `'返回'`                                 |
| `vocabulary_page.dart:53`      | `'生词本'`                                |
| `vocabulary_page.dart:58`      | `'刷新'`                                 |
| `vocabulary_page.dart:99-136`  | `'全部'`、`'未学'`、`'学习中'`、`'已忽略'`、`'已掌握'`  |
| `vocabulary_page.dart:148`     | `'全部词库'`                               |
| `vocabulary_page.dart:73`      | `['CET-4', 'CET-6', 'IELTS', 'TOEFL']` |
| `vocabulary_page.dart:235`     | `'重试'`                                 |
| `vocabulary_page.dart:245`     | `'暂无生词'`                               |
| `vocabulary_page.dart:294-300` | `'未学'`、`'学习中'`、`'已掌握'`、`'已忽略'`         |
| `vocabulary_page.dart:335`     | `'来自《$title》'`                         |

`_statusLabel` 使用 `status.displayName` 来自 `vocab_status_extension` ✅，但 PopupMenu 中再次硬编码。

***

## 3. 国际化（i18n）问题

**整个 vocabulary 模块未使用** **`AppLocalizations`**。`VocabStatus.displayName` 扩展提供了本地化字段（英文如 "new"、"learning"），但 UI 中全部硬编码中文覆盖了该字段。词库列表 `['CET-4', 'CET-6', 'IELTS', 'TOEFL']` 硬编码——这些应在 Rust 侧动态提供。

***

## 4. ViewModel 设计缺陷

### 4.1 `@injectable factory` → `useMemoized` ✅ 已修复

VM 不再用 DI 创建，改为 `useMemoized(() => VocabularyViewModel())`，VM 生命周期与 widget element 一致。`useEffect` cleanup 中调用 `vm.dispose()` 销毁所有 signal。loading 闪烁已在 5.5 修复。

### 4.2 `filterStatus` 默认值会影响页面首次加载 🚫 已跳过

```dart
final filterStatus = signal<VocabStatus?>(VocabStatus.new_);
```

默认过滤「未学」生词。如果用户想看的词是「学习中」或「已掌握」，每次打开页面都要手动切换筛选。应默认 `null`（全部）或记住上次选择。已评估后决定跳过，暂时维持现状。
<br />

### 4.3 `loadWords` 使用 `unawaited` 加载 bookTitles

```dart
unawaited(_loadBookTitles());
```

bookTitles 加载失败不影响主列表显示（名字显示为空）。但如果用户快速操作（如删除生词），`deleteWord()` 调 `loadWords()` 后再次 `unawaited`，堆积的异步操作可能造成顺序问题。不过由于 `loadWords` 在 delete 后有 `await`，实际上不会重叠。

### 4.4 状态字符串转换使用 switch-case 脆弱 ✅ 已修复

不再通过字符串中转：`updateStatus(String id, String s)` → `updateStatus(String id, VocabStatus status)`，`PopupMenuButton<String>` → `PopupMenuButton<VocabStatus>`，值直接使用枚举变体，switch 删除。

### 4.5 无 dispose 方法 ✅ 已修复
VM 新增 `dispose()` 方法，在 `useEffect` 的 cleanup 中调用，销毁所有 signal。

***

## 5. UI/UX 问题

### 5.1 Dismissible 滑动删除确认弹窗 ✅ 已修复
 
```dart
confirmDismiss: (_) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定要删除「${item.word}」吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
},
```
 
左滑 `Dismissible` 时弹出确认对话框，点「删除」才执行 `onDismissed`，点「取消」恢复原状。

### 5.2 筛选 chips 使用 SingleChildScrollView 嵌套 Row

两行 chips 分别包裹在 `SingleChildScrollView` + `Row` 中。如果某行 chip 数量超过屏幕宽度，水平滚动✅。但两行各自独立滚动，视觉上不够协调。建议统一使用 `Wrap` 或单行可滚动布局。

### 5.3 空态使用 `EmptyStateWidget` ✅

复用 `core/presentation/widgets/empty_state_widget.dart`，项目通用组件 ✅。

### 5.4 错误状态显示 `err.toString()` ✅ 已修复

改用 `AppErrorMapper.humanReadable(err)`，统一映射为用户友好消息（PanicException → "引擎内部错误"、AnyhowException → "数据处理异常" 等）。

### 5.5 筛选状态切换时闪烁 ✅ 已修复

不再在 filter 切换时设 `AsyncState.loading()`，`loadWords(showLoading: false)` 跳过加载状态，旧数据保留到新数据就绪，消除闪烁。

### 5.6 状态标签颜色使用 `status.color` ✅ 已修复

```dart
Color _statusColor(VocabStatus status, ThemeData theme) => switch (status) {
  VocabStatus.unstarted || VocabStatus.ignored => theme.colorScheme.onSurfaceVariant,
  _ => status.color,
};
```

`unstarted` 和 `ignored` 的灰色调在暗色模式下改用 `onSurfaceVariant`（自动适配深浅色），`learning`/`mastered` 保持语义色（橙/绿，双模式下均良好）。

***

## 6. 代码层统一建议
### 6.1 筛选 chips 与 learning\_notes 重复 ✅ 已修复

`_filterChip` 私有方法已删除，全部调用点改为直接使用 `SelectionChip` 组件，与 `learning_notes` 统一。

### 6.2 状态 label 和 PopupMenu 字符串重复

```dart
_statusLabel(item.status)        // 来自 VocabStatusExtension.displayName
'未学' / '学习中' / '已掌握' / '已忽略'  // PopupMenu 硬编码
```

PopupMenu 项目的文本应使用 `item.status.displayName` 而非重新硬编码。

### 6.3 `listVocabularyByStatus` 的 4 次冗余查询模式

`learning_notes_view_model.dart` 和 `reading_stats_view_model.dart` 同样调 4 次 `listVocabularyByStatus` 取计数。vocabulary VM 中仅调用了一次（因为使用 `getVocabularyStats()` 聚合接口 ✅）。这是正确的做法，但其他 2 个模块未采用。

### 6.4 词库列表在 Rust 侧未定义，Dart 侧硬编码

```dart
static const wordLists = ['CET-4', 'CET-6', 'IELTS', 'TOEFL'];
```

应在 Rust 侧提供 `getAvailableWordLists()` API，Dart 侧仅渲染。

***

## 7. 假实现 / stub 分析

| 类型                        | 位置                              | 说明                                                |
| ------------------------- | ------------------------------- | ------------------------------------------------- |
| **默认筛选为"未学"**             | `vocabulary_view_model.dart:13` | 默认过滤 `VocabStatus.new_`，用户每次打开只看到未学生词（设计取舍，非 bug） |
| **词库列表硬编码**               | `vocabulary_page.dart:73`       | CET-4/6/IELTS/TOEFL 字符串硬编码，非从 Rust 动态获取           |
| **`_statusLabel`** **扩展** | `vocab_status_extension.dart`   | `displayName` 定义但 UI 中 PopupMenu 没有使用它            |
| **滑动删除无确认**               | `vocabulary_page.dart:271`      | `onDismissed` 直接 delete，无确认/undo                  |

***

## 8. 潜在问题
 
### 8.0 `unstartedCount` 直接返回「未学」数量 ✅ 已修复
 
原代码用 `total - learning - knownCount - mastered` 手动算「未学」，但 `knownCount` 不存在（bug）。Rust API 直接返回 `unstarted_count`（Dart 侧 `unstartedCount`），`VocabStatsRow` 已改为直接用 `stats!.unstartedCount`。
 
### 8.1 `loadWords` 中 bookId 参数 ✅ 已删除
 
已移除 `loadWords()` 的 `bookId` 参数（无调用方使用），保持签名干净。Rust API `listVocabularyByStatus` 的 `bookId` 参数仍保留，未来需要时可重新接入。
### 8.2 筛选状态更新时已删除词条可能残留
 
删除单词后重新加载列表，但如果删除操作用于延迟的网络，`loadWords()` 完成前用户看到了旧列表。不过 `await` 保证了顺序✅。
 
### 8.3 Dismissible `key` 使用 `ValueKey(item.id)`
 
```dart
key: ValueKey(item.id),
```
 
✅ 正确的 stable key——避免 index-based 问题。
***

## 9. 测试覆盖分析

| 组件                    | 单元测试                                                         | 覆盖内容                                                             |
| --------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------- |
| `VocabularyViewModel` | ✅ `test/features/vocabulary/vocabulary_view_model_test.dart` | 初始状态、setFilter、setWordListFilter、updateStatus、deleteWord、refresh |
| `VocabularyPage`      | ❌                                                            | Widget 测试缺失                                                      |

**测试亮点**：

- ✅ 初始状态测试不依赖 FFI
- ✅ FFI 测试有 `_isRustAvailable()` 动态检测
- ✅ `deleteWord` 验证 `isLoading` 状态
**测试缺口**：

- 错误路径（FFI 异常 → error 态）
- `setFilter` 改变后 `wordsState` 是否正确更新
- Widget 渲染测试

***

## 10. 优化清单

| 优先级      | 类别        | 项目                                                    | 状态           |
| -------- | --------- | ----------------------------------------------------- | ------------ |
| **P0**   | UI        | `Colors.grey` 改为 `theme.colorScheme.onSurfaceVariant` | ✅ 已修复        |
| **P0**   | i18n      | 全部 10+ 处硬编码中文迁移至 l10n                                 | <br />       |
| ***P1*** | *UI*      | *Dismissible 删除背景* *`Colors.red`* *改为* *`cs.error`*   | *✅ 已修复*      |
| **P1**   | UI        | 滑动删除添加确认 dialog                                     | ✅ 已修复        |
| **P1**   | UI        | 错误状态使用用户友好消息替代 `e.toString()`                         | ✅ 已修复        |
| **P1**   | UI        | 筛选切换减少 loading 闪烁                                     | ✅ 已修复        |
| **P1**   | i18n      | `PopupMenu` 文本改为 `item.status.displayName`            | ✅ 已修复        |
| **P1**   | i18n      | 添加 `getAvailableWordLists()` Rust API                 | <br />       |
| **P1**   | ViewModel | `filterStatus` 默认 `null`（全部）或持久化上次选择                  | 🚫 已跳过       |
| **P1**   | 代码        | 筛选 chips 与 `learning_notes` 统一组件                      | ✅ 已修复        |
| **P1**   | ViewModel | 状态字符串 switch-case 改为直接传枚举                              | ✅ 已修复        |
| **P1**   | ViewModel | 添加 dispose 生命周期管理                                       | ✅ 已修复        |
| **P1**   | 测试        | 添加错误路径测试（FFI 异常→error 态）                            | ✅ 已修复        |
| **P1**   | 测试        | Widget 渲染测试（三个提取组件）                                  | ✅ 已修复        |
| **P2**   | 代码        | `knownCount` 不存在 → 改用 `unstartedCount`                  | ✅ 已修复        |
| **P2**   | 代码        | `loadWords` 中 bookId 参数移除                             | ✅ 已修复        |
| **P2**   | UX        | 词库列表从 Rust 动态加载                                       | <br />       |
| **P2**   | UX        | `_buildSubtitle` 暗色模式颜色                               | ✅ 已修复（同 2.1） |

