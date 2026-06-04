# Search Feature 深度分析报告

> 分析基准：`lib/features/search/` — 9 个文件
> 检测日期：2026-06-03

---

## 1. 架构总览

```
search/
├── application/
│   ├── search_view_model.dart           ← 搜索 VM（~180 行）
│   └── services/
│       └── search_history_service.dart   ← 搜索历史内存存储（~18 行）
├── page/
│   ├── search_page.dart                 ← 全局搜索页（~330 行）
│   ├── book_search_page.dart            ← 书籍内搜索页（~180 行）
│   ├── search_results_view.dart         ← 聚合结果视图（~100 行）
│   ├── search_results.dart              ← 结果数据模型（~37 行）
│   ├── search_result_header.dart        ← 分组标题 + 高亮片段（~145 行）
│   ├── search_result_cards.dart         ← 三条卡片（~275 行）
│   └── search_history.dart              ← 搜索历史展示（~115 行）
```

**两个搜索入口**：
1. `SearchPage` — 全局搜索：一次查询 4 个数据源（书名 + 内容 FTS5 + 生词 + 笔记）
2. `BookSearchPage` — 书籍内搜索：特定书籍内搜索内容（独立实现，不使用 VM）

**数据流**：
```
SearchPage → SearchViewModel.doFullSearch()
                 ├── book_api.listBooks()           — 全量书籍
                 ├── book_api.searchBooks(query)    — 书名匹配
                 ├── search_api.searchAllBooks()     — FTS5 全文
                 ├── vocab_api.searchVocabulary()    — 生词
                 └── note_api.listNotesByBooks() + 本地过滤 — 笔记
```

---

## 2. P0 级问题

### 2.1 `BookSearchPage` — 完整的假实现

`book_search_page.dart` 有完整的搜索 UI（TextField、结果列表、加载状态），但**搜索结果仅使用 `useSignal<List<SearchResult>>([])` 管理，且从不调任何搜索 API**。

```dart
final searchResults = useSignal<List<SearchResult>>([]);
final isSearching = useSignal(false);
// ...
onChanged: (value) => searchQuery.value = value,  // 只设置 keyword，不触发搜索
```

搜索字段的 `onChanged` 只更新 `searchQuery`，不发起任何搜索请求。用户输入内容后永远得到空列表。这是**用户可见的假实现**。

### 2.2 笔记搜索在 Dart 侧全文遍历

```dart
// search_view_model.dart:127-139
final notesBatch = await note_api.listNotesByBooks(
  bookIds: allBooksResult.map((b) => b.bookId).toList(),
);
final lowerQuery = query.toLowerCase();
for (final (_, notes) in notesBatch) {
  for (final note in notes) {
    if (note.content.toLowerCase().contains(lowerQuery) || ...) {
      noteResults.add(note);
    }
  }
}
```

先调 `listNotesByBooks` 获取**所有笔记**，然后在 Dart 侧逐条用 `String.contains` 过滤。如果用户有数千条笔记，这会在 UI 线程上进行大量字符串操作。Rust 侧应提供 `searchNotes(query)` API。

### 2.3 所有搜索相关字符串硬编码中文

| 位置 | 字符串 |
|------|--------|
| `book_search_page.dart:32` | `'搜索所有书籍内容...'` / `'搜索书籍内容...'` |
| `search_page.dart:198` | `'搜索书籍、笔记、生词...'` |
| `search_page.dart:238` | `'取消'` |
| `search_page.dart:279` | `'搜索出错'` |
| `search_page.dart:285` | `'重试'` |
| `search_page.dart:304` | `'未找到相关结果'` |
| `search_page.dart:312` | `'试试其他关键词'` |
| `search_result_header.dart:29` | `'书籍'`、`'笔记'`、`'生词'` |
| `search_result_cards.dart:99` | `'未知作者'` |
| `search_result_cards.dart:184` | `'Ch.${note.chapterIndex + 1}'` |

---

## 3. 国际化（i18n）问题

**整个 search 模块未使用 `AppLocalizations`**。

全局搜索中使用 `l10n` 的次数为 0。所有用户可见字符串硬编码中文。

---

## 4. ViewModel 设计缺陷

### 4.1 `doFullSearch` 中 `listBooks()` 和 FTS 搜索互相阻塞

```dart
final allBooksResult = await allBooksFuture;   // 等待所有书籍
final bookMap = {for (final b in allBooksResult) b.bookId: b}; // 构建 map

final results = await Future.wait([            // 然后发起并行搜索
  titleHitsFuture,
  ftsSearch(),
  vocabHitsFuture,
]);
```

先 `await allBooksFuture` 获取全量书籍列表（可能包含数百本书），再并行搜索。但 `allBooksFuture` 在前三步就启动了（`Future.all`），`bookMap` 构建在数据到达后，之后才搜索。其实可以改进为：并行查询所有源，仅按需获取 bookMap。

### 4.2 笔记搜索失败被静默忽略

```dart
try {
  // listNotesByBooks + 本地过滤
} catch (e) {
  Logging.error('搜索笔记失败', exception: e);  // 只打日志，不展示给用户
}
```

生词搜索通过 FTS5 API 正常返回；笔记搜索失败时用户看不到笔记结果也看不到错误提示。

### 4.3 `@injectable` 无生命周期管理

```dart
@injectable
class SearchViewModel { ... }
```

DI 无明确生命周期注解，默认 factory。页面每次重建都创建新 VM。历史记录不丢失（因为 `SearchHistoryService` 在页面中 `useMemoized`），但搜索结果在页面重建时丢失。

### 4.4 `searchBook()` 分页逻辑与 `loadMore()` 不一致

```dart
// searchBook 中：
final data = await searchAllBooks(query: keyword.value, limit: currentPage.value, offset: (currentPage.value - 1) * 20);

// loadMore 中：
currentPage.value++;
await searchBook(loadMore: true);
```

`limit: currentPage.value` — limit 参数传入了页码而非每页大小。应该是 `limit: 20` 而非 `limit: currentPage.value`。这是**分页逻辑 bug**：第一页 limit=1，第二页 limit=2，第三页 limit=3 以此类推，导致分页结果逐页变多。

### 4.5 搜索历史只存在于内存

```dart
class SearchHistoryService {
  final List<String> _history = [];
  ...
}
```

`SearchHistoryService` 使用纯内存列表，不持久化。每次应用重启搜索历史丢失。

---

## 5. UI/UX 问题

### 5.1 搜索结果中的 `SearchSummaryBar` 未使用

`search_page.dart:143-144` 中使用：
```dart
if (hasSearched && searchResults.value != null)
  SearchSummaryBar(results: searchResults.value!),
```
但 `SearchSummaryBar` 实际构建了一个显示耗时和命中数的条——未读完整实现，暂标记。

### 5.2 笔记/生词搜索结果点击不跳转

```dart
// VocabSearchCard
onTap: () {},     // ← 空函数，点击无响应
```

生词卡片不可点击。笔记卡片跳转到阅读器 ✅。书籍卡片跳转到阅读器 ✅。

### 5.3 `BookSearchCard` 使用 `GestureDetector` 无 ripple

三个卡片类全部使用 `GestureDetector`，无 Material ripple 反馈。

### 5.4 `searchHistory` 空态 emoji

```dart
children: [
  const Text('🔍', style: TextStyle(fontSize: 36)),
  const SizedBox(height: 12),
  Text(
    '搜索书籍、笔记、生词...',
    ...
  ),
],
```

Emoji 图标在不同平台渲染不一致。

### 5.5 `BookSearchPage` 未处理键盘

搜索 `TextField` 使用 `autofocus: true`，但 `textInputAction: TextInputAction.search` 缺失。用户输入后只能点「取消」退出。

### 5.6 全量搜索无 loading 骨架

搜索进行中只显示 `CircularProgressIndicator`。页面从搜索历史切换到加载状态时出现跳动。建议 skeleton。

---

## 6. 代码层统一建议

### 6.1 两个搜索入口代码完全独立

`SearchPage`（全局）+ `BookSearchPage`（书籍内）是互相独立的实现。`BookSearchPage` 不使用 `SearchViewModel`，不使用搜索 API。应重构为统一的组件库。

### 6.2 三个卡片结构高度重复

`BookSearchCard`、`NoteSearchCard`、`VocabSearchCard` 共享相同的外层容器样式（`Container` + `decoration` + `margin` + `shadow`）。应提取为共享 `SearchCard` 基类。

### 6.3 高亮片段重复

`buildHighlightedSnippet` 在 `search_result_header.dart` 中定义，被三个卡片引用。实现正确 ✅，但该函数重复实现了匹配逻辑——与 `search_view_model.dart` 中的笔记搜索同样做 `toLowerCase().contains()`。

### 6.4 `ResultGroupHeader` 中的分组标题字符串

```dart
title: '书籍',   // search_results_view.dart:29
title: '笔记',   // search_results_view.dart:44
title: '生词',   // search_results_view.dart:59
```

三个分组标题硬编码中文，且是 `SearchResultsView` 的 props。应在更上层或通过 l10n 注入。

---

## 7. 假实现 / stub 分析

| 类型 | 位置 | 说明 |
|------|------|------|
| **`BookSearchPage` 完整假实现** | `book_search_page.dart` | 有完整 UI 但 `onChanged` 不触发任何搜索，结果永远空列表 |
| **生词搜索卡片点击空函数** | `search_result_cards.dart:216` | `VocabSearchCard.onTap = () {}` |
| **笔记搜索在 Dart 侧暴力遍历** | `search_view_model.dart:127-139` | Rust 侧无 `searchNotes` API |
| **搜索历史不持久化** | `search_history_service.dart` | 纯内存存储，重启丢失 |
| **FTS5 搜索不可用于书籍内** | `BookSearchPage` | 不使用 FTS5，甚至不使用搜索 API |

---

## 8. 潜在问题

### 8.1 `doFullSearch` 同时执行 `listBooks()` + 4 个搜索

一次搜索触发 5 个独立 API 调用（全量书籍 + 书名搜索 + FTS5 全文 + 生词搜索 + 笔记全量）。随着数据量增长，延迟累积。

### 8.2 `searchBook` 分页 `limit` 参数错误

```dart
final data = await searchAllBooks(query: keyword.value, limit: currentPage.value, offset: ...);
```

`limit: currentPage.value` 应改为 `limit: 20`。这是**分页 bug**。

### 8.3 搜索历史方法名混乱

`SearchHistoryService` 中：
- `getHistory()` ✅
- `addHistory()` ✅
- `clearHistory()` ✅
- `removeHistory()` ✅

统一 ✅ 但无 `dispose` 方法。

### 8.4 `searchResults` 使用 `useComputed`

```dart
final searchResults = useComputed(() {
  if (!vm.hasSearched.value) return null;
  // ... 大量数据转换
});
```

每次任何依赖变化时都重建整个结果对象。内容命中可能很多，map/filter 操作在 UI 线程上。

---

## 9. 测试覆盖分析

| 组件 | 单元测试 | Widget 测试 |
|------|---------|-------------|
| `SearchViewModel` | ❌ | N/A |
| `SearchHistoryService` | ❌ | N/A |
| `SearchPage` | N/A | ❌ |
| `BookSearchPage` | N/A | ❌ |
| `SearchResultsView` | N/A | ❌ |
| 所有卡片组件 | N/A | ❌ |

**零测试覆盖**。

---

## 10. 优化清单

| 优先级 | 类别 | 项目 |
|--------|------|------|
| **P0** | Bug | `searchBook` 分页 limit 应为 20，不是 `currentPage.value` |
| **P0** | Bug | `BookSearchPage` 搜索 `onChanged` 不触发任何请求 |
| **P0** | 假实现 | `BookSearchPage` 接入搜索 API 或 FTS5 |
| **P0** | 假实现 | `VocabSearchCard.onTap` 空函数改为跳转生词详情 |
| **P0** | 性能 | 笔记搜索调 `listNotesByBooks` 全量 + Dart `contains` 遍历 |
| **P0** | i18n | 全部 9 个文件中的 15+ 处硬编码中文迁移至 l10n |
| **P1** | ViewModel | `doFullSearch` 将 `allBooksFuture` 与其他搜索并行而非串行 |
| **P1** | ViewModel | 笔记搜索失败时给用户提示而非静默忽略 |
| **P1** | ViewModel | `SearchViewModel` 生命周期注解（factory → 其他） |
| **P1** | 持久化 | `SearchHistoryService` 持久化到 SharedPreferences |
| **P1** | 性能 | Rust 侧添加 `searchNotes(query)` API |
| **P1** | 性能 | `useComputed` 中大量 map/filter 的性能考量 |
| **P1** | 测试 | 添加 `SearchViewModel` 单元测试 |
| **P1** | 测试 | 添加 `SearchHistoryService` 单元测试 |
| **P2** | 代码 | 三个搜索卡片提取为共享基类 |
| **P2** | 代码 | `BookSearchPage` 和 `SearchPage` 共享搜索组件 |
| **P2** | 代码 | `buildHighlightedSnippet` 提取为工具函数 |
| **P2** | UI | Emoji `🔍` 替换为 `PhosphorIcons` |
| **P2** | UI | `GestureDetector` 全部改为 `InkWell`（3 处） |
| **P2** | UI | `BookSearchPage` 添加 `textInputAction: TextInputAction.search` |
| **P2** | UI | 搜索加载态 skeleton |
