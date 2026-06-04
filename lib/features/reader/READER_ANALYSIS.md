# Reader Feature 深度分析报告

> 分析基准：`lib/features/reader/` — 约 30 个文件
> 检测日期：2026-06-03

---

## 1. 架构总览

```
reader/
├── application/
│   ├── reader_view_model.dart       ← VM Facade（~540 行）
│   ├── chapter_manager.dart         ← 章节/分页/搜索索引（~410 行）
│   ├── reading_session_manager.dart ← 阅读计时/自动保存（~110 行）
│   └── cache_manage_view_model.dart ← 缓存管理 VM（~50 行）
├── data/
│   ├── repositories/
│   │   └── rust_reader_repository.dart  ← FFI 仓库层（~400 行）
│   ├── typeset_calibrator.dart          ← 字符宽度校准
│   └── vocabulary_marker_service.dart   ← 考纲词标记
├── domain/services/
│   └── highlight_painter.dart           ← 搜索高亮绘制
├── page/
│   ├── reader_page.dart              ← 阅读器主页面（~750 行）
│   ├── reader_page_actions.dart      ← 划词/双语操作
│   ├── reader_dictionary_panel.dart  ← 词典查询面板
│   ├── cache_manage_page.dart        ← 缓存管理页
│   ├── bookmark_manage_page.dart     ← 书签管理页
│   └── widgets/ (19 files)           ← UI 组件
```

**设计亮点**：
- ✅ **Binding 分离**：`ReaderPageBindings` 分为 `useReaderBindings`（全量）、`useReaderContentBindings`（仅内容）、`useReaderUiBindings`（仅 UI 面板）。内容变更不影响工具栏重建。
- ✅ **Manager 拆分**：ChapterManager（章节/分页）、ReadingSessionManager（计时/保存）、ReaderViewModel（轻量 Facade）
- ✅ **自动保存 + 防抖**：5 秒间隔防抖，30 秒定时保存
- ✅ **KV 缓存分页**：Rust `paginateAllContent` 带缓存，Fallback 到 Dart 近似排版
- ✅ **`@lazySingleton`**：ReaderViewModel 和 ReaderRepository 都是 lazySingleton ✅
- ✅ **搜索索引 FTS5**：章节内容索引到 SQLite FTS5，后台不阻塞 UI
- ✅ **字体校准**：Flutter TextPainter 测量 → Rust 排版使用，带重试机制

---

## 2. P0 级问题

### 2.1 搜索匹配采用 Dart 侧 `indexOf` 全文扫描

```dart
// reader_page.dart:529-537
final lower = c.toLowerCase();
final q = query.toLowerCase();
var count = 0, pos = 0;
while (true) {
  final idx = lower.indexOf(q, pos);
  if (idx == -1) break;
  count++;
  pos = idx + q.length;
}
```

用户每次按键都对整个章节内容做 `indexOf` 扫描。长章节（>50 万字）会卡 UI 线程。已有的 FTS5 索引未被用于搜索计数。

### 2.2 `setFontSize` / `setLineHeight` 重建整个章节

```dart
Future<void> setFontSize(double size) async {
  _config.fontSize.value = size;
  await chapterManager.loadChapter(   // 重新排版 + 重新索引 + 重新加载高亮
    chapterIndex.value,
    initialCharOffset: currentCharOffset.value,
    restartSession: false,
    onChapterLoaded: loadHighlights,
  );
}
```

每次滑块拖动触发完整章节重载（排版、索引、高亮）。滑块拖动期间会产生大量连续重载。

### 2.3 `VocabularyMarkerService` — `cet6`/`ielts`/`toefl` 全部返回同一个 set

```dart
Set<String> get allWords => _allWords;
Set<String> get cet6 => _allWords;    // ← 全部指向同一个 _allWords
Set<String> get ielts => _allWords;   // ← 同上
Set<String> get toefl => _allWords;   // ← 同上
```

三个词库 getter 全部返回 `_allWords`（Rust 侧的 `getAllVocabularyWords` 不区分词库）。UI 上 `CET-6` / `IELTS` / `TOEFL` 标签无法区分不同考纲词表。

### 2.4 搜索匹配的 UI 文本硬编码中文

`reader_page.dart:554-582` 中 `_showTranslationDialog`、`_showAnnotationDialog`、`_showHighlightMenu`、`_showEditAnnotationDialog` 的标题、按钮、hintText 全部硬编码中文。

### 2.5 `ReaderPage` — `@lazySingleton` 跨页面共享单例

`ReaderViewModel` 是 `@lazySingleton`。如果用户连续打开两本书，第二本会命中：
```dart
if (this.bookId.value == bookId && chapters.value.value?.isNotEmpty == true) return;
```
忽略新书的 `initialChapterId`/`initialPageIndex`。打开同一本时返回已加载状态。但切换书籍时 `resetForNewBook()` 在 `useEffect` dispose 中调用，如果页面 A 未完全销毁而页面 B 已初始化，会产生竞态。

---

## 3. 国际化（i18n）问题

大部分 Dialog 标题/按钮/提示硬编码中文：

| 位置 | 硬编码字符串 |
|------|-------------|
| `reader_page.dart:301` | `'${b.pageIndex + 1} / ${b.effectiveTotalPages}'`（页码分隔符非 i18n） |
| `reader_page.dart:554` | `'设置对照译文'` |
| `reader_page.dart:561` | `'粘贴或输入当前章节的译文内容：'` |
| `reader_page.dart:567` | `'在此粘贴译文文本…'` |
| `reader_page.dart:577,581` | `'取消'`、`'确认'` |
| `reader_page.dart:593` | `'添加笔记'` |
| `reader_page.dart:625` | `'输入你的笔记内容…'` |
| `reader_page.dart:637,645` | `'取消'`、`'保存'` |
| `reader_page.dart:662,673` | `'编辑笔记'`、`'删除高亮'` |
| `reader_page.dart:694` | `'编辑笔记'` |
| `reader_page.dart:724,735,747` | `'输入你的笔记内容…'`、`'取消'`、`'保存'` |
| `reader_page_actions.dart` | 使用 l10n ✅（少数例外） |
| `reader_dictionary_panel.dart` | 大量硬编码（词条检索、错误提示、配置引导等） |
| `chapters_manager.dart:105` | `'加载中...'` |
| `reader_view_model.dart:159` | `'加载失败：$e'` |
| `reader_view_model.dart:380,397,407,416` | `'保存高亮失败'`、`'保存笔记失败'`、`'删除失败'`、`'更新笔记失败'` |
| `reader_view_model.dart:512` | `'双语高亮创建失败'` |

---

## 4. ViewModel 设计缺陷

### 4.1 `@lazySingleton` 跨页面混淆（见 §2.5）

### 4.2 `resetForNewBook()` 未清理搜索状态完全

```dart
showSearch.value = false;
searchQuery.value = '';
searchMatches.value = 0;
searchCurrentIndex.value = 0;
searchMatchParagraph.value = -1;
```

已清理 ✅，但 `searchController.text` 在页面中未被清理（ReaderPage 未监听 `showSearch` 变更来清空 controller）。

### 4.3 错误字符串重复定义

```dart
toastMessage.value = '保存高亮失败';   // 行 380
toastMessage.value = '保存笔记失败';   // 行 397
toastMessage.value = '删除失败';      // 行 407
toastMessage.value = '更新笔记失败';  // 行 416
```

四个错误消息重复模式。且均为硬编码中文。

### 4.4 `loadHighlights` 每次章节切换都调 API

```dart
Future<void> loadHighlights() async {
  highlights.value = await note_api.listNotesInChapter(...);
  HighlightPainter.invalidateCache();
}
```

每次 `loadChapter` 都重新调 `listNotesInChapter` 获取全量高亮。如果章节没有高亮变更，这是不必要的网络/IO 调用。

### 4.5 `CacheManageViewModel` 构造函数启动异步

```dart
CacheManageViewModel({required this.repo, this.bookId}) {
  load();   // fire-and-forget
}
```

与其他模块相同的构造函数异步模式。

### 4.6 `clearAllCache() {}` 空函数

```dart
/// 缓存已由 Rust sled 管理，Dart 端无需清理
void clearAllCache() {}
```

文档注释解释了理由，但 `clearAllCache` 被调用时用户期望看到效果。应至少加 toast 或 disable 按钮。

---

## 5. UI/UX 问题

### 5.1 自动隐藏工具栏恢复不完全

```dart
toolbarOpacity.value = 0.6;   // 只降低透明度，不隐藏
```

4 秒后工具栏「隐藏」只是透明度降到 0.6，交互区域仍然占据屏幕空间。在暗色模式下半透明工具栏遮挡阅读内容。

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
if (goBack) vm.previousPage();
else if (goForward) vm.nextPage();
else vm.toggleToolbar();  // 中间 1/3
```

TapLayout 支持 leftHanded/rightHanded ✅。但中间区域功能单一（只是 toggle toolbar），没有「向上滚动」或「显示菜单」等可能的快捷操作。

### 5.5 「目录」和「笔记」使用 Drawer

`Scaffold(key: scaffoldKey)` + `Drawer` + `EndDrawer`。Drawer 在 Material 3 中逐渐被替代，左滑手势可能与系统手势冲突（特别是在 iOS 上）。

### 5.6 无加载 skeleton

首次加载章节时显示 loading state，但 ReaderContent 无骨架屏组件。

### 5.7 `MediaQuery(textScaler: TextScaler.noScaling)` 禁用系统字体缩放

阅读器内禁用了系统字体缩放 ✅ 可防止双重缩放，但用户通过系统设置放大文字时阅读器无响应，其他页面正常放大。应在设置中提供独立的「跟随系统字体缩放」选项。

---

## 6. 代码层统一建议

### 6.1 六个对话框结构重复

`_showTranslationDialog`、`_showAnnotationDialog`、`_showEditAnnotationDialog`、`_showHighlightMenu`、`_showBookActions`...
全部在 `reader_page.dart` 中作为私有方法定义。应提取为独立文件或至少共享 Dialog 模板。

### 6.2 搜索匹配计数在 Dart 侧

```
Dart:  `String.indexOf` 全文扫描（reader_page.dart:529-537）
FTS5:  `search_api.indexChapter` 已索引（chapter_manager.dart:287-293）
```

已有 FTS5 索引但不用于搜索计数。Rust 侧应有 `countMatches(query)` API。

### 6.3 `ReaderPage` 中的 `resetHideTimer` 方法被复制到多处

```dart
vm.toggleToolbar(); resetHideTimer();
vm.toggleSettings(); resetHideTimer();
```

模式重复，可合并为一个统一的事件处理入口。

### 6.4 `Theme` widget 在 build 中创建

```dart
final readerData = baseTheme.copyWith(
  extensions: [readerExt, ...baseTheme.extensions.values],
);
return Theme(data: readerData, ...);
```

每次 build 创建新 `ThemeData`，即使 readerExt 未变化。

### 6.5 `bold` vs `w700` 等字体权重混用

`reader_view_model.dart`: 使用 FRB 模型中的 fontSize/color 等。
`rust_reader_repository.dart:_spanToStyle`: `FontWeight.bold`、`FontStyle.italic`、`Colors.blue` 等硬编码。

---

## 7. 假实现 / stub 分析

| 类型 | 位置 | 说明 |
|------|------|------|
| **词库不分词表** | `vocabulary_marker_service.dart:17-19` | `cet6`/`ielts`/`toefl` 全返回同一个 `_allWords` set，无词表区分 |
| **清除缓存空函数** | `cache_manage_view_model.dart:39` | `clearAllCache() {}` — 文档注释说明由 Rust sled 管理，但 UI 中该按钮仍可点击 |
| **Dictionary 面板固定逻辑** | `reader_dictionary_panel.dart:67` | `ListView.builder(itemCount: 5, ...)` 固定 5 个 item，底层硬编码 |
| **亮度遮罩中心固定** | `reader_page.dart:221` | `center: Alignment.center` 而非跟随阅读焦点 |

---

## 8. 潜在问题

### 8.1 `ChapterManager.dispose()` 未调用

```dart
void reset() { ... }    // 在 VM 中被调用
void dispose() {        // 从未被调用
  _autoScrollTimer?.cancel();
  _searchIndexOperation?.cancel();
}
```

`dispose()` 清理定时器和搜索索引。ReaderViewModel 是 `@lazySingleton`，长期持有 ChapterManager。如果用户一直打开应用，搜索索引操作会层层堆积。

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
for (int i = start; i <= end; i++) {
  if (i == centerIndex) continue;
  _repo.preloadChapter(bookId.value, i);
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
useEffect(() {
  return vm.resetForNewBook;
}, []);
```

`resetForNewBook()` 会 `stopReading()` + cancel timers。但是**只在 useEffect dispose 时调用**。如果用户通过系统返回键（非页面内关闭按钮）退出，`PopScope(onPopInvokedWithResult)` 只是 `context.pop()`，不会触发 `vm.resetForNewBook()`。此时 Timer 泄漏继续运行。

### 8.6 `ReadingSessionManager` 的 `saveProgress` 在 VM 中同时被多处调用

- `sessionManager.startAutoSave()` 每 30 秒自动保存
- `loadPage()` 每次翻页后 `await sessionManager.saveProgress()`

翻页时也会触发保存，与定时保存冲突。虽然有 5 秒防抖，但翻页后的保存是 `await` 的，会阻塞翻页操作。

### 8.7 字体校准函数 `calibrateSafely` 的重试只等待 100ms

```dart
int maxRetries = 3,
Duration retryDelay = const Duration(milliseconds: 100),
```

字体加载通常需要 50-200ms。3 次重试总等待 300ms，对于大字体文件（如 `NotoSerifSC-Regular.ttf` 24MB）可能不够。应增加重试次数或延迟。

### 8.8 `_spanToStyle` 中使用 `Colors.blue` 硬编码

```dart
link: (text, url, fontSize, color) => const TextStyle(
  color: Colors.blue, decoretion: TextDecoration.underline,
),
```

在某些阅读主题（深色/羊皮纸）中，`Colors.blue` 可能对比度不足。应使用主题色。

### 8.9 生词标记颜色

`vocabulary_marker_service.scanText` 返回匹配位置，但实际的标记颜色风格未定义。

---

## 9. 测试覆盖分析

| 组件 | 单元测试 | Widget 测试 |
|------|---------|-------------|
| `ReaderViewModel` | ❌ | N/A |
| `ChapterManager` | ❌ | N/A |
| `ReadingSessionManager` | ❌ | N/A |
| `CacheManageViewModel` | ❌ | N/A |
| `ReaderRepository` | ❌ | N/A |
| `VocabularyMarkerService` | ❌ | N/A |
| `ReaderPage` | N/A | ❌ |
| `ReaderContent` | N/A | ❌ |
| 其余 Widget | N/A | ❌ |

**现有测试**：`test/widget/reader_page_bindings_test.dart` 可能存在但未在此次分析范围内。

---

## 10. 优化清单

| 优先级 | 类别 | 项目 |
|--------|------|------|
| **P0** | Bug | `VocabularyMarkerService.cet6/ielts/toefl` 全部返回同一个 set |
| **P0** | 性能 | 搜索匹配 Dart `indexOf` 全文扫描，应改用 FTS5 计数 |
| **P0** | 性能 | `setFontSize/setLineHeight` 滑块拖动触发完整章节重载 |
| **P0** | i18n | 6 个 Dialog 标题/按钮全部硬编码中文 |
| **P1** | 架构 | `@lazySingleton` ReaderViewModel 跨页面状态混淆（切换书籍） |
| **P1** | 架构 | 字体预加载重试次数增加（24MB 字体仅 300ms 总等待） |
| **P1** | 架构 | `_prefetchChapters` 并发控制 |
| **P1** | 架构 | `resetForNewBook` 在 PopScope 中未执行 |
| **P1** | 架构 | `saveProgress` 在翻页路径中 `await` 阻塞翻页 |
| **P1** | 架构 | `ChapterManager.dispose()` 未被调用 |
| **P1** | UX | 工具栏自动隐藏后仍占据交互区域 |
| **P1** | UX | 亮度遮罩中心跟随阅读位置 |
| **P1** | i18n | `reader_view_model.dart` 5 处错误消息硬编码 |
| **P1** | i18n | `chapter_manager.dart` `'加载中...'`、`'章节加载失败：$e'` |
| **P1** | i18n | `reader_dictionary_panel.dart` 大量硬编码 |
| **P1** | 测试 | 添加 ViewModel/ChapterManager 单元测试 |
| **P2** | 代码 | 6 个对话框提取为共享组件 |
| **P2** | 代码 | `ReaderPage.build` 中 Theme 创建缓存 |
| **P2** | 代码 | `resetHideTimer` 重复模式统一 |
| **P2** | 代码 | `_spanToStyle` 中 `Colors.blue` 使用主题色 |
| **P2** | 代码 | `CacheManageViewModel` 构造函数移出异步 |
| **P2** | UX | 阅读器禁用系统字体缩放时提供设置选项 |
| **P2** | UX | 中间 1/3 区域增加更多快捷操作 |
| **P2** | UX | 字典面板动态 itemCount |
