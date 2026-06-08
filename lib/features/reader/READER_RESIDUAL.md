# Reader Feature — 已知残留问题

> 记录 `lib/features/reader/` 清理后确定暂时不动的已知问题。

## Repository 状态字段

`rust_reader_repository.dart` 仍持有三个可变状态字段，widget 通过构造参数 `repo` 直接读取：

| 字段 | 消费者 |
|------|--------|
| `currentPages` | `PaginatedModeRenderer`、`ReaderContent`、`ChapterManager` |
| `currentRichContent` | `ScrollModeRenderer` |
| `currentRichParagraphs` | `ScrollModeRenderer` |

这些字段是 repo 层无法彻底移除的根本原因。后续重构应将其迁移到 `ChapterManager` 作为 signal，移除 widget 对 repo 的直接依赖。

## `@lazySingleton` ReaderViewModel

`reader_view_model.dart` 使用 `@lazySingleton` 注册，切换书籍时同一实例复用。`resetForNewBook()` 负责清理状态，但跨书切换存在信号订阅残留风险。

详见 READER_ANALYSIS.md §2.5。修复方式：改用 `@factoryParam` 或每次导航创建新实例。

## `VocabularyMarkerService` 注入不一致

`vocabulary_marker_service.dart` 在 `page/` 层通过 `getIt<>()` 直接获取（`reader_page.dart` 的 `_loadVocabularyWords`），而非通过构造函数注入。该 service 只有 1.3KB，功能简单，不影响运行，但与全项目的依赖注入模式不一致。如需统一，应在 `ReaderViewModel` 中注入并暴露给页面。

## 书签管理页字符串硬编码

`bookmark_manage_page.dart` 中时间格式、对话框文本均为中文硬编码：

- `刚刚`、`分钟前`、`小时前`、`天前`
- 对话框标题/按钮文字

全项目一致，非单文件问题。如需 l10n 化，应在项目级统一处理。
