# ReaderPage 组件化计划

## 现状

`ReaderPage.build()` 约 470 行，分三块：

| 区域 | 行数 | 内容 |
|------|------|------|
| Setup | ~100 | 服务注入、Signal 声明、effects、闭包、theme 构造 |
| Inline builders | ~240 | 4 个 builder + selection toolbar（`buildContentArea`, `buildTopToolbar`, `buildBottomArea`, `buildSelectionToolbar`） |
| Return tree | ~100 | `Theme > PopScope > Scaffold > Stack` 渲染树 |

已完成的优化：`ReaderSettingsOverlay` 参数从 31 个 → 12 个。

## Phase 1: `useReaderPageState()` Hook（最关键）

### 目标
把 Setup 段中所有 Hook 调用、Signal 声明、Effect 订阅、局部闭包提取到独立自定义 Hook 中。

### 新文件
```
lib/features/reader/page/hooks/reader_page_state.dart
```

### 提取代码

从 `ReaderPage.build()` 搬出：

| 原始代码段 | 行号 | 目标 |
|-----------|------|------|
| `useMemoized` 5 个服务注入 | 55-60 | Hook 内 |
| `useSignal<TapLayout>` | 60 | Hook 内 |
| `useMemoized(GlobalKey)` | 61 | Hook 内 |
| `useSignal<Set<String>>` vocabWords | 63 | Hook 内 |
| `useSignal<Offset?>` selectionGlobalPos | 64 | Hook 内 |
| `useRef<Timer?>` autoHideTimer | 65 | Hook 内 |
| `useState<ReaderPanelType?>` activePanel | 66 | Hook 内 |
| `useSignal<bool>` showToolbar | 67 | Hook 内 |
| `showSelection` 计算 | 68-70 | Hook 内 |
| Toast effect | 72-85 | Hook 内 |
| Font tracking effect | 87-90 | Hook 内 |
| Init `useEffect` | 92-107 | Hook 内 |
| Timer cleanup `useEffect` | 108-111 | Hook 内 |
| `l10n` 获取 | 114 | Hook 内 |
| `themeMode` 推导 | 117-121 | Hook 内 |
| `brightnessPresets` + `cycleBrightness` | 123-132 | Hook 内 |
| `fontFamily` | 134 | Hook 内 |
| `resetHideTimer` + `withTimer` | 136-151 | Hook 内 |
| `readerExt` + `readerData` | 153-157 | Hook 内 |

### Hook 签名

```dart
ReaderPageState useReaderPageState(String bookId, int initialChapterId);

class ReaderPageState {
  ReaderViewModel vm;
  FontRepository fontRepo;
  ReaderRepository readRepo;
  TtsService ttsService;
  ReaderConfig config;
  GlobalKey<ScaffoldState> scaffoldKey;

  Signal<Set<String>> vocabWords;
  Signal<Offset?> selectionGlobalPos;
  Ref<Timer?> autoHideTimer;
  ValueNotifier<ReaderPanelType?> activePanel;
  Signal<bool> showToolbar;
  bool showSelection;

  AppLocalizations l10n;
  ThemeMode themeMode;
  ThemeData readerData;
  String fontFamily;
  TapLayout tapLayout;

  void cycleBrightness();
  void resetHideTimer();
  void withTimer(VoidCallback action);
}
```

### 效果

```dart
// Before: ~470 lines
@override Widget build(BuildContext context) {
  // 100 lines setup
  // ...
  // inline builders + return tree
}

// After: ~260 lines
@override Widget build(BuildContext context) {
  final s = useReaderPageState(bookId, initialChapterId);
  final b = useReaderBindings(s.vm);
  // inline builders + return tree (use s.xxx instead of local vars)
}
```

### 风险

- Hooks 顺序必须保持：`useReaderPageState()` 内部所有 `useMemoized`/`useSignal`/`useEffect`/`useSignalEffect` 的顺序不可变
- `scaffoldKey` 在 return tree 中使用（`Scaffold(key: s.scaffoldKey)`），提取后需要确保引用一致
- `context` 作为闭包捕获变量：`resetHideTimer` 和 `withTimer` 已做 `context.mounted` 检查，提取后不受影响

### 文件修改

| 文件 | 操作 |
|------|------|
| `lib/features/reader/page/hooks/reader_page_state.dart` | **新增** |
| `lib/features/reader/page/reader_page.dart` | 替换 55-157 行为 Hook 调用 |

---

## Phase 2: ReaderContentData 值对象

### 目标
`ReaderContent` 有 ~45 个构造参数，其中 ~20 个是 bindings 的直通值。收集进一个值对象缩小调用点。

### 新类型（可选放在 reader_content.dart 顶部，或独立文件）

```
lib/features/reader/page/widgets/reader_content_data.dart
```

```dart
class ReaderContentData {
  final String bookId;
  final int chapterId;
  final int pageIndex;
  final int totalPages;
  final double fontSize;
  final double lineHeight;
  final ThemeMode themeMode;
  final ReadingMode readingMode;
  final String content;
  final bool isLoading;
  final String? error;
  final bool hasNextChapter;
  final BilingualAlignment? bilingualAlignment;
  final bool isBilingualLoading;
  final int? autoScrollTick;
  final List<Note> highlights;
  final String fontFamily;
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final WritingDirection writingDirection;
  final bool showVocabularyMark;
  final Set<String> vocabularyWords;
  final bool baselineAlign;
  final TextAlign textAlign;
  final bool showSentenceSplit;
  final int bgIndex;
  final int? jumpToCharOffset;
}
```

### ReaderContent 变更

```dart
class ReaderContent extends HookWidget {
  final ReaderContentData data;  // 替换 28 个字段
  // 保留 ~10 个回调/特殊字段：
  final VoidCallback? onRequestTranslation;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryTranslation;
  final ValueChanged<int>? onPageChanged;
  final void Function(String, int, int)? onSelectionChanged;
  final void Function(Note)? onHighlightTap;
  final ValueChanged<Offset?>? onSelectionGlobalPosition;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onReachEnd;
  final VoidCallback? onJumpHandled;
}
```

### 调用点变化

```dart
// Before: ~35 params in buildContentArea()
ReaderContent(
  repo: readRepo,
  bookId: b.currentBookId,
  chapterId: b.chapterIndex,
  ...
)

// After: ~15 lines
ReaderContent(
  data: ReaderContentData(
    bookId: b.currentBookId,
    chapterId: b.chapterIndex,
    ...
  ),
  onPageChanged: vm.loadPage,
  ...
)
```

### 效果

- `buildContentArea()` 从 80 行 → ~40 行
- `ReaderContent` 本身不再膨胀

---

## Phase 3: 消除防抖回调（可选）

### 目标
当前 `ReaderSettingsOverlay` 仍保留 5 个防抖回调（`onFontSizeChanged`/`onLineHeightChanged`/`onLetterSpacingChanged`/`onParagraphSpacingChanged`/`onPageMarginChanged`），因为 VM 的 `setXxx` 方法会调用 `_debounceReloadChapter()`。

### 方案 A（推荐）：单回调 → `onLayoutChanged`

```dart
ReaderSettingsOverlay(
  config: config,
  readingMode: b.currentReadingMode,
  onReadingModeChanged: vm.setReadingMode,
  onLayoutChanged: vm.debounceReloadChapter,  // 暴露 VM._debounceReloadChapter 为 public
  onTtsToggle: () => _toggleTts(vm, ttsService),
  onClose: () => activePanel.value = null,
)
```

Overlay 内所有影响布局的 config 写操作后调用 `onLayoutChanged()`：

```dart
// In overlay's _sliderTile for fontSize:
onChanged: (v) {
  config.fontSize.value = v;
  onLayoutChanged();
}
```

**收益**：消除 5 个回调 → 再减 5 个参数，构造参数降至 7 个
**代价**：VM 暴露 `debounceReloadChapter` 给 UI 层

### 方案 B：Signal effect 自动监听

在 VM 中添加：

```dart
void _setupAutoReload() {
  bool _first = true;
  effect(() {
    _config.fontSize.value;
    _config.lineHeight.value;
    _config.letterSpacing.value;
    _config.paragraphSpacing.value;
    _config.padding.value;
    if (_first) { _first = false; return; }
    _debounceReloadChapter();
  });
}
```

**收益**：完全消除防抖回调，VM 自洽
**代价**：
- `effect()` 在 VM 构造时立即执行一次（首次需跳过）
- 隐式触发：reload 不再有显式调用栈
- 若后续有其他 Config widget 写值，也会触发 reload（好 or 不好？）

### 决策建议

先完成 Phase 1 和 Phase 2。Phase 3 在确认整体架构后选方案 A。

---

## 执行顺序

```
Phase 1 (useReaderPageState) ───→ Phase 2 (ReaderContentData) ───→ Phase 3 (debounce elimination)
       ↓                               ↓                               ↓
  build(): ~200 lines cut        buildContentArea(): ~40 lines cut    overlay: 7 params
  hook: testable                  ReaderContent: cleaner API          VM: 5 setXxx methods removed
```

## 不做的（当前）

- `tapLayout` 与 `TapZone` 合并 — TapZone 本身已独立
- 提取 `buildTopToolbar` 为独立 widget — 它已经是 Positioned + AnimatedToolbarPanel + ReaderToolbar，再包一层反而增加层级
- 提取 `Scaffold` 为 `ReaderPageScaffold` — drawer/endDrawer/popScope 逻辑高度耦合，提取后仍需传过多回调
