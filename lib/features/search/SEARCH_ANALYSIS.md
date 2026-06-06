# Search Feature 深度分析报告

> 分析基准：`lib/features/search/` — 10 个文件（含 SEARCH\_ANALYSIS.md）
> 检测日期：2026-06-03
>
> 最后更新：2026-06-05 — 详见各节 ✅ 标记

***

## 1. 架构总览

```
search/
├── application/
│   ├── search_view_model.dart           ← 搜索 VM（~195 行）
│   └── services/
│       └── search_history_service.dart   ← 搜索历史内存存储（~18 行）
├── page/
│   ├── search_page.dart                 ← 全局搜索页（~280 行）
│   ├── book_search_page.dart            ← 书籍内搜索页（~240 行）
│   ├── search_results_view.dart         ← 聚合结果视图（~90 行）
│   ├── search_results.dart              ← 结果数据模型（~37 行）
│   ├── search_result_header.dart        ← 分组标题 + 统计条（~90 行）
│   ├── search_result_cards.dart         ← 三张卡片 + SearchCard 基类（~270 行）
│   ├── search_highlight.dart            ← 高亮片段工具函数（~55 行）
│   └── search_history.dart              ← 搜索历史展示（~115 行）
```

**两个搜索入口**：

1. `SearchPage` — 全局搜索：一次查询 5 个数据源（书名 + 内容 FTS5 + 生词 + 笔记 + 全部书籍）
2. `BookSearchPage` — 书籍内搜索：特定书籍内搜索内容（直接调 Rust API）

**数据流**：

```
SearchPage → SearchViewModel.doFullSearch()
                ├── book_api.listBooks()           — 全量书籍
                ├── book_api.searchBooks(query)    — 书名匹配
                ├── search_api.searchAllBooks()     — FTS5 全文
                ├── vocab_api.searchVocabulary()    — 生词
                └── note_api.searchNotes(query)     — 笔记搜索（Rust searchNotes API）

BookSearchPage → _performSearch()
                ├── search(bookId, query)          — 单书全文搜索（bookId 非空时）
                └── searchAllBooks(query)          — 全局全文搜索（bookId 空时）
```

***

## 2. P0 级问题

### 4.5 搜索历史只存在于内存

`SearchHistoryService` 纯内存 `List<String>`，重启丢失。待持久化。

***

## 5. UI/UX 问题

<br />

### 5.2 `VocabSearchCard.onTap` 空函数未修复

生词搜索结果不可点击。

### 5.6 全量搜索无 loading 骨架

仅 `CircularProgressIndicator`，建议 skeleton。

***

## 6. 代码层统一建议

### 6.1 两个搜索入口独立

`SearchPage` + `BookSearchPage` 独立实现。`BookSearchPage` 已直调 Rust API，但组件仍不共享。

***

## 7. 假实现 / stub 分析

| 类型                          | 位置                            | 状态    |
| --------------------------- | ----------------------------- | ----- |
| `VocabSearchCard.onTap` 空函数 | `search_result_cards.dart`    | ❌ 仍为空 |
| 搜索历史不持久化                    | `search_history_service.dart` | ❌ 纯内存 |

***

## 8. 潜在问题

### 8.3 搜索历史方法名混

`SearchHistoryService` 方法名一致，但无持久化。

***

## 9. 测试覆盖分析

| 组件                     | 单元测试                               | Widget 测试                                           |
| ---------------------- | ---------------------------------- | --------------------------------------------------- |
| `SearchViewModel`      | ✅ 5 tests（`test/features/search/`） | N/A                                                 |
| `SearchHistoryService` | ❌                                  | N/A                                                 |
| `SearchPage`           | N/A                                | ✅ 9 tests（`test/widget/search_page_test.dart`）      |
| `BookSearchPage`       | N/A                                | ✅ 4 tests（`test/widget/book_search_page_test.dart`） |

***

## 10. 优化清单

| 优先级    | 类别  | 项目                             | 状态    |
| ------ | --- | ------------------------------ | ----- |
| **P0** | 假实现 | `VocabSearchCard.onTap` 空函数    | ❌ 未修复 |
| **P1** | 持久化 | `SearchHistoryService` 持久化     | ❌ 待办  |
| **P1** | 测试  | 添加 `SearchViewModel` 单元测试      | ❌ 待办  |
| **P1** | 测试  | 添加 `SearchHistoryService` 单元测试 | ❌ 待办  |
| **P2** | 代码  | 两搜索入口共享组件                      | ❌ 待办  |
| **P2** | UI  | 搜索加载态 skeleton                 | ❌ 待办  |

***

## 11. 补充发现（2026-06-05 二次审查）

### 11.1 `buildHighlightedSnippet` 高亮颜色硬编码黄色

```dart
backgroundColor: Colors.yellow.withValues(alpha: 0.4),
```

暗色模式下黄色背景 + 浅色文字对比度不足。应使用 `cs.primaryContainer`。

### 11.2 `NoteSearchCard` 中 `Ch.${note.chapterIndex + 1}` 硬编码

`"Ch."` 是英文缩写，无 l10n。

### 11.3 `VocabSearchCard` 紫色圆点 `Color(0xFFAB47BC)` 硬编码

不感知主题。

### 11.4 `VocabSearchCard.onTap` 空函数未跳转

生词搜索结果不可点击。**P0 假实现**。

### 11.5 `SearchPage` 使用 `late final` 字段而非 `useMemoized`

```dart
late final SearchViewModel vm;
```

在 `build` 之前通过 `didChangeDependencies` 初始化。`StatefulWidget` + `late final` 的寿命等同 Widget 自身，与 `useMemoized` 效果相同，模式可接受。
