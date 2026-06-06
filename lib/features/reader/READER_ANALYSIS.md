# Reader Feature 深度分析报告

> 分析基准：`lib/features/reader/` — 约 30 个文件
> 检测日期：2026-06-03
>
> ✅ = 已完成修复（见 CHANGELOG.md）

---

## 1. 架构总览

```
lib/features/reader/
├── application/
│   ├── cache_manage_view_model.dart
│   ├── chapter_manager.dart
│   ├── reader_view_model.dart
│   └── reading_session_manager.dart
├── data/repositories/
│   └── rust_reader_repository.dart
├── domain/services/
│   └── highlight_painter.dart
├── page/
│   ├── cache_manage_page.dart
│   ├── bookmark_manage_page.dart
│   ├── reader_page.dart
│   └── widgets/
│       ├── animated_toolbar_panel.dart
│       ├── bilingual_renderer.dart
│       ├── bookmark_widget.dart
│       ├── chapter_list_widget.dart
│       ├── paginated_renderer.dart
│       ├── reader_annotation_dialog.dart
│       ├── reader_content.dart
│       ├── reader_highlight_sheet.dart
│       ├── reader_note_sidebar.dart
│       ├── reader_settings_panel.dart
│       ├── reader_translation_dialog.dart
│       └── scroll_mode_renderer.dart
└── READER_ANALYSIS.md
```

**设计亮点**：
- ✅ **Binding 分离**：`ReaderPageBindings` 分为 `useReaderBindings`（全量）、`useReaderContentBindings`（仅内容）、`useReaderUiBindings`（仅 UI 面板）。内容变更不影响工具栏重建。
- ✅ **双渲染路径**：`PaginatedRenderer`（分页）和 `ScrollModeRenderer`（滚动），通过 `ReadingMode` 控制，分页使用 `Flow` 布局，渲染路径统一。
- ✅ **统一错误处理**：`ResetException` + `RetryException`，支持重置章节或重试。
- ✅ **效果 Effect 管理**：`effect()` 跟踪 `autoScroll` 和 `isReading`，UI 状态通过 `useSignalEffect` 绑定。
- ✅ **持久化信号**：`ReaderConfig` 使用 `persistedBool`/`persistedDouble`/`persistedEnum`，自动同步到 SharedPreferences。

---

## 2. P0 级问题

### 2.1 搜索匹配采用 Dart 侧 `indexOf` 全文扫描 ✅ 已修复
  <!-- fix: ViewModel.onSearchChanged 改用 search_api.search() -->
原实现在 widget 中 `while(true) { indexOf }` 扫描全部内容 → 已修复：`onSearchChanged` 移入 ViewModel，通过 FTS5 `search_api.search()` 获取匹配结果，按 `chapterIndex` 过滤当前章节。Dart 侧不再全文扫描。FTS5 索引未就绪时静默降级。

用户每次按键都对整个章节内容做 `indexOf` 扫描。长章节（>50 万字）会卡 UI 线程。已有的 FTS5 索引未被用于搜索计数。

### 2.2 `setFontSize` / `setLineHeight` 重建整个章节

```dart
void setFontSize(double size) {
  config.fontSize.value = size;
  _reloadChapter();        // 每次重建
}
```

每次滑块拖动触发完整章节重载（排版、索引、高亮）。滑块拖动期间会产生大量连续重载。

### 2.3 `VocabularyMarkerService` — `cet6`/`ielts`/`toefl` 全部返回同一个 set

```dart
Set<String> get cet6 => _allWords;
Set<String> get ielts => _allWords;
Set<String> get toefl => _allWords;
```

### 2.3 `VocabularyMarkerService` — `cet6`/`ielts`/`toefl` 全部返回同一个 set ✅ 已修复
  <!-- fix: Rust 侧新增 get_cet6_words/get_ielts_words/get_toefl_words，FRB 重新生成，Dart 服务分别加载 -->
原三个 getter 全部返回 `_allWords` → 已修复：Rust 侧（`vocab_marker/wordlists.rs`）新增 `cet6_words()`/`ielts_words()`/`toefl_words()` 以及对应 FRB 包装函数。Dart 侧分别加载为独立 `Set`，getter 返回 `UnmodifiableSetView`。FRB 重新生成。

### 2.4 搜索匹配的 UI 文本硬编码中文

`reader_page.dart` 中 `_showTranslationDialog`、`_showAnnotationDialog`、`_showHighlightMenu`、`_showEditAnnotationDialog` 的标题、按钮、hintText 全部硬编码中文 → 已修复：提取为独立组件并接入 `AppLocalizations`。

### 2.5 `ReaderPage` — `@lazySingleton` 跨页面共享单例 ✅ 已修复
  <!-- fix: initialize() 移除 guard，顶部调用 resetForNewBook() 确保状态隔离 -->
`ReaderViewModel` 是 `@lazySingleton`。第一本 dispose 与第二本 initialize 交叉执行产生竞态 → 已修复：`initialize()` 开头顶层调用 `resetForNewBook()`，移除 `bookId` 守卫。每次初始化前状态已清空。
---

## 3. 国际化（i18n）问题

大部分 Dialog 标题/按钮/提示硬编码中文：

| 位置 | 硬编码字符串 |
|---|---|
| `reader_annotation_dialog.dart` | `'添加笔记'`、`'编辑笔记'`、`'取消'`、`'保存'`、`'输入你的笔记内容…'` |
| `reader_translation_dialog.dart` | `'设置对照译文'`、`'粘贴或输入当前章节的译文内容：'`、`'取消'`、`'确认'` |
| `reader_highlight_sheet.dart` | `'编辑笔记'`、`'删除高亮'` |
| `chapters_manager.dart:105` | `'加载中...'` |
| `reader_view_model.dart:159` | `'加载失败：$e'` |
| `reader_view_model.dart:380,397,407,416` | `'保存高亮失败'`、`'保存笔记失败'`、`'删除失败'`、`'更新笔记失败'` |
| `reader_view_model.dart:512` | `'双语高亮创建失败'` |

**已修复**：`ReaderAnnotationDialog`、`ReaderTranslationDialog`、`ReaderHighlightSheet` 三组件已接入 `AppLocalizations`（新增 `pasteTranslationPlaceholder` key）。ViewModel 层错误消息需后续架构调整（无 BuildContext 上下文）。

---

## 4. ViewModel 设计缺陷

### 4.1 `@lazySingleton` 跨页面混淆（见 §2.5）

### 4.2 `resetForNewBook()` 未清理搜索状态完全 ✅ 已修复
  <!-- fix: reader_page.dart 添加 useSignalEffect -->
已清理 `showSearch/searchQuery/searchMatches/searchCurrentIndex/searchMatchParagraph`，但 `searchController.text` 在页面中未被清理 → 已修复：添加 `useSignalEffect` 监听 `showSearch`，搜索关闭或切换书籍时自动清空 controller。

### 4.3 错误字符串重复定义

```dart
toastMessage.value = '保存高亮失败';   // 行 380
toastMessage.value = '保存笔记失败';   // 行 397
toastMessage.value = '删除失败';      // 行 407
toastMessage.value = '更新笔记失败';  // 行 416
```

四个错误消息重复模式。且均为硬编码中文。

### 4.4 `loadHighlights` 每次章节切换都调 API ✅ 已修复
  <!-- fix: reader_view_model.dart 添加 _highlightsCache + forceRefresh -->
每次 `loadChapter` 都重新调 `listNotesInChapter` → 已修复：添加 `Map<int, List<Note>> _highlightsCache` 按章节索引缓存。切换到已访问章节时直接返回缓存。保存/删除/更新操作传 `forceRefresh: true`。

### 4.5 `CacheManageViewModel` 构造函数启动异步 ✅ 已修复
  <!-- fix: 构造函数移除 load()，移至页面 useEffect -->
构造函数直接调 `load()`（fire-and-forget）→ 已修复：移除构造函数中的 `load()`，移至 `useEffect(() { vm.load(); })`。

### 4.6 `clearAllCache() {}` 空函数 ✅ 已修复
  <!-- fix: 移除空方法与误导性按钮 -->
空函数（Rust sled 管理缓存），但 UI 有「清空全部缓存」按钮 → 已修复：移除空方法及页面中两处按钮和确认对话框。

---

## 5. UI/UX 问题

### 5.1 自动隐藏工具栏恢复不完全 ✅ 已修复
  <!-- fix: 改为 full hide，移除 opacity 参数 -->
原行为：4 秒后透明度降到 0.6，仍占据交互区域 → 已修复：4 秒后设置 `showToolbar = false`，工具栏通过 `AnimatedSlide` 完全滑出屏幕。移除未使用的 `opacity` 参数和 `toolbarOpacity` 状态。

### 5.2 亮度遮罩使用 `Colors.black` ✕ `IgnorePointer`

```dart
IgnorePointer(
  child: Container(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: b.brightness * 0.5), Colors.black.withValues(alpha: b.brightness)],
```

夜间模式亮度调节使用半透明黑色覆盖层。这是电池友好的做法 ✅ 但中心点固定为 `Alignment.center`，如果用户在阅读底部内容，中心点不再在视口中心。

### 5.3 字典面板 `DraggableScrollableSheet` + `ListView.builder` 强绑定

`reader_dictionary_panel.dart` 使用 `ListView.builder(itemCount: 5, ...)` 固定 5 个类型 item，底层硬编码而非根据搜索结果动态展示。

### 5.4 书页中间点击 1/3 区域切换 toolbar

```dart
final third = w / 3;
if (dx < third) { goBack = true; }
else if (dx > third * 2) { goForward = true; }
else { toggleToolbar(); }
```

TapLayout 支持 leftHanded/rightHanded ✅。但中间区域功能单一（只是 toggle toolbar），没有「向上滚动」或「显示菜单」等可能的快捷操作。

### 5.5 「目录」和「笔记」使用 Drawer

`Scaffold(key: scaffoldKey)` + `Drawer` + `EndDrawer`。Drawer 在 Material 3 中逐渐被替代，左滑手势可能与系统手势冲突（特别是在 iOS 上）。

### 5.6 无加载 skeleton

首次加载章节时显示 loading state，但 ReaderContent 无骨架屏组件。

### 5.7 `MediaQuery(textScaler: TextScaler.noScaling)` 禁用系统字体缩放 ✅ 已修复
  <!-- fix: 添加 followSystemFontScale 持久化开关和设置面板 Switch -->
原行为：硬编码 `noScaling`，用户通过系统设置放大文字时阅读器无响应 → 已修复：`ReaderConfig.followSystemFontScale` 控制是否跟随系统缩放。默认关闭。设置面板新增 `Switch.adaptive` 切换。底层使用 `Builder` 包装以正确读取 `MediaQuery.textScalerOf(context)`。

---

## 6. 代码层统一建议

### 6.1 六个对话框结构重复 ✅ 已修复
  <!-- fix: 提取为 3 个独立组件文件 -->
`_showTranslationDialog`、`_showAnnotationDialog`、`_showEditAnnotationDialog`、`_showHighlightMenu` 四个内联方法 → 已修复：提取为 `ReaderAnnotationDialog`（合并创建/编辑）、`ReaderTranslationDialog`、`ReaderHighlightSheet` 三个独立文件。移除约 200 行内联代码。

### 6.2 搜索匹配计数在 Dart 侧

```
reader_page.dart:  indexOf 全文扫描
chapters_manager:  _indexForSearch (生成搜索索引)
reader_view_model: updateSearch (更新匹配状态)
```

已有 FTS5 索引但不用于搜索计数。Rust 侧应有 `countMatches(query)` API。

### 6.3 `ReaderPage` 中的 `resetHideTimer` 方法被复制到多处 ✅ 已修复
  <!-- fix: 统一为 withTimer 辅助函数 -->
6 处 `action(); resetHideTimer();` 重复模式 → 已修复：提取 `withTimer(VoidCallback)` 辅助函数，所有调用均通过此入口。

### 6.4 `Theme` widget 在 build 中创建 ✅ 已修复
  <!-- fix: useMemoized 缓存 ThemeData -->
每次 build 创建新 `ThemeData`，即使 readerExt 未变化 → 已修复：`useMemoized` 缓存 `ThemeData`，仅在 `readerTheme` 变更时重新计算。

### 6.5 `bold` vs `w700` 等字体权重混用

`reader_view_model.dart`: 使用 FRB 模型中的 fontSize/color 等。
`rust_reader_repository.dart:_spanToStyle`: `FontWeight.bold`、`FontStyle.italic`、`Colors.blue` 等硬编码。

---

## 7. 假实现 / stub 分析

| 类型 | 位置 | 说明 |
|---|---|---|
| stub | `cache_manage_view_model.dart` | `clearAllCache() {}` 空函数 —— ✅ 已移除 |
| stub | `reader_page.dart` | `_buildSearchIndexSection` 返回 `SizedBox.shrink()` |
| stub | `rust_reader_repository.dart` | `getBookCoverBase64` 返回空字符串 |
| stub | `rust_reader_repository.dart` | `getBookFileHashMD5` 返回空字符串 |

---

## 8. 潜在问题

### 8.1 `ChapterManager.dispose()` 未调用 ✅ 已修复
  <!-- fix: 移除死代码 dispose()，reset() 完善清理 -->
`dispose()` 与 `reset()` 功能重复但从未被调用 → 已修复：移除 `dispose()` 方法。`reset()` 改用 `stopAutoScroll()` + 置空 `_searchIndexOperation`，统一清理模式。

### 8.2 `_searchIndexOperation?.cancel()` 在 loadChapter 中调用

```dart
await _searchIndexOperation?.cancel();
_searchIndexOperation = CancelableOperation.fromFuture(
  _indexForSearch(chapterIndex, content),
  onCancel: () {},
);
```

每次 loadChapter 取消上一个索引操作。但如果用户在索引完成前快速切换章节，旧章节的索引会被取消，新章节开始索引。这是正确的 ✅，但 `onCancel: () {}` 空回调意味着无法知道取消发生。

### 8.3 预加载章节（`_prefetchChapters`）无并发控制

```dart
Future<void> _prefetchChapters(int start, int end) async {
  for (int i = start; i <= end; i++) {
    preloadChapter(i);    // 未 await，全部并行
  }
}
```

`preloadChapter` 是 async 但未 await。预加载操作可能堆积。应使用限制并发数的队列。

### 8.4 `ReadingSessionManager` 的 `_lastSaveTime` 初始值为 2000 年

```dart
DateTime _lastSaveTime = DateTime(2000);
```

防抖逻辑依赖 `_lastSaveTime` 初始化。初始值 2000 年使第一次保存总是通过（差 > 5 秒）。正确但非直观，建议使用 `DateTime.fromMillisecondsSinceEpoch(0)` 或明确的 null 检查。

### 8.5 页面离开后 Timer 仍在运行

```dart
PopScope(
  onPopInvokedWithResult: (didPop, _) {
    if (didPop) return;
    context.pop();
  },
```

`resetForNewBook()` 会 `stopReading()` + cancel timers。但是**只在 useEffect dispose 时调用**。如果用户通过系统返回键（非页面内关闭按钮）退出，`PopScope` 只是 `context.pop()`，不会触发 `vm.resetForNewBook()`。此时 Timer 泄漏继续运行。

### 8.6 `ReadingSessionManager` 的 `saveProgress` 在 VM 中同时被多处调用

- `sessionManager.startAutoSave()` 每 30 秒自动保存
- `ReaderViewModel.loadPage()` 翻页时保存
- `ReaderViewModel.jumpToPosition()` 跳转时保存
- `ReaderViewModel.previousChapter()` / `nextChapter()` 章节切换时保存

翻页时也会触发保存，与定时保存冲突。虽然有 5 秒防抖，但翻页后的保存是 `await` 的，会阻塞翻页操作。

### 8.7 字体校准函数 `calibrateSafely` 的重试只等待 100ms

```dart
for (final seconds in [100, 100, 100]) {
  await Future.delayed(Duration(milliseconds: seconds));
  // retry
}
```

字体加载通常需要 50-200ms。3 次重试总等待 300ms，对于大字体文件（如 `NotoSerifSC-Regular.ttf` 24MB）可能不够。应增加重试次数或延迟。

### 8.8 `_spanToStyle` 中使用 `Colors.blue` 硬编码

```dart
final isLink = style.color == 0xFF_0000FF;   // Colors.blue
```

在某些阅读主题（深色/羊皮纸）中，`Colors.blue` 可能对比度不足。应使用主题色。

### 8.9 生词标记颜色

`vocabulary_marker_service.scanText` 返回匹配位置，但实际的标记颜色风格未定义。

---

## 9. 测试覆盖分析

| 组件 | 单元测试 | Widget 测试 |
|---|---|---|
| `ReaderViewModel` | — | — |
| `ChapterManager` | — | — |
| `ReadingSessionManager` | — | — |
| `ReaderRepository` | — | — |
| `ReaderPage` | — | `test/widget/reader_page_bindings_test.dart` |

**现有测试**：`test/widget/reader_page_bindings_test.dart` 可能存在但未在此次分析范围内。

---

## 10. 优化清单

| 优先级 | 类别 | 项目 |
|---|---|---|
| **P0** | 性能 | FTS5 搜索索引代替 `indexOf` 全文扫描 |
| **P0** | 性能 | `setFontSize`/`setLineHeight` 防抖 + 延迟重建 |
| **P0** | 功能 | `VocabularyMarkerService` 按词库分割 |
| **P1** | i18n | `reader_view_model.dart` 5 处错误消息硬编码 |
| **P1** | i18n | `chapter_manager.dart` `'加载中...'`、`'章节加载失败：$e'` |
| **P1** | i18n | `reader_dictionary_panel.dart` 大量硬编码 |
| **P1** | 测试 | 添加 ViewModel/ChapterManager 单元测试 |
| **P2** | 代码 | 6 个对话框提取为共享组件 ✅ |
| **P2** | 潜在 | `ReaderPage.Dispose()` Timer 和 Operation 泄漏 |
| **P2** | 潜在 | `_prefetchChapters` 并发控制 |
| **P2** | 潜在 | `PopScope` 不会触发 `resetForNewBook()` |
| **P2** | UI | 亮度遮罩跟随视口中心 |
| **P2** | 性能 | `loadHighlights` 按章节缓存 ✅ |
| **P3** | 代码 | `resetHideTimer` 事件入口统一 ✅ |
| **P3** | 代码 | `Theme widget` 缓存 ✅ |
| **P3** | 代码 | `ChapterManager.dispose()` 死代码 ✅ |
| **P3** | UI | • 跟随系统字体缩放选项 ✅ |
| **P3** | UI | 工具栏完全隐藏 ✅ |
