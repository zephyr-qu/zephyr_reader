# 修改日志

## [Unreleased]


### 新增
- **翻译 API**：双语模式支持自动翻译（#feat/translation-service）
  - 新增 `TranslationService` 抽象接口，支持 OpenAI-compatible 和自定义 API 适配器
  - 新增 `TranslationConfig` 持久化配置（Provider、API URL、Key、模型、语言、超时）
  - 切换双语模式时自动调用配置的翻译 API，无需手动粘贴译文
  - 翻译结果按章节内容哈希缓存，避免重复请求
  - 支持取消进行中的翻译（切换章节/模式时自动取消）
  - 配置入口：Profile → 阅读体验 → 翻译 API
  - 配套单元测试 23 项，覆盖配置、缓存、OpenAI/Custom 适配器

### 重构
- **Vocab 功能从 learning_notes 迁移至 vocabulary 模块**
  - `lib/features/learning_notes/` 缩减为纯笔记（notes-only）页面
  - 删除 `vocab_tab_widget.dart`、`tab_switcher_widget.dart`（功能已移植至 vocabulary）
  - `stat_dashboard_widget.dart` 精简为仅显示笔记数（单卡片）
  - `LearningNotesViewModel` 移除 `@injectable`、所有生词 signals/methods、tab 切换
  - `learning_notes_page.dart` 简化：AppBar "笔记"+ 生词本导航按钮，无 Tab 切换
  - **组件提取**：`NoteItemCard`、`GoReadingEmptyState`、`VocabWordListView` 提取为独立无状态组件。
  - `LearningNotesNoteTab` 参数从 6 降至 4（移除 `colorScheme` + `vm`）。
  - `stat_dashboard_widget.dart` 移除冗余 `Row` 包装（§4.3）。
  - `VocabStatusChip` / `VocabStatsRow` 新增 `l10n` 参数并改用 i18n key。

### 修复
- **书架设置**：`显示阅读进度` 开关现在实际控制封面百分比显示，并修复开关只能点击一次的 reactivity 问题（底部弹出层内 `StatelessWidget` 未对信号变化重建）。
- **i18n**：AppBar title、tooltip、Stat label 三处硬编码中文替换为 `AppLocalizations` key（§3.1-3.3）。
- **LearningNotesViewModel**：`_loadNotes()` 初始不触发 → 加入 `initialize()` Future.wait（§2.1）。
- **LearningNotesViewModel**：提取 `_loadAll()` 消除 `initialize()`/`refresh()` 重复代码（§4.1）。
- **LearningNotesViewModel**：`_loadNotes()` 移除重复 `rust_book.listBooks()`，改用 `bookTitles.value`（§4.2）。
- **LearningNotesViewModel**：`_initialized` 失败时回退，允许重试（§4.6）。
- **LearningNotesViewModel**：新增 `dispose()` 释放 7 个 signal（§4.7）。
- **LearningNotesViewModel**：`error` signal 写入前清空旧值（§4.8）。
- **ReaderViewModel**：移除 `initialize()` 中 `bookId` 守卫（§2.5），改为每次调用 `resetForNewBook()` 确保跨页面状态隔离。消除 `@lazySingleton` 跨页面状态混淆与竞态问题。
- **ReaderPage**：新增 `useSignalEffect` 监听 `showSearch` 自动清空 `searchController`（§4.2）。关闭搜索或切换书籍时同步清除旧搜索文本，消除跨页面搜索文本残留。
- **ReaderPage**：工具栏自动隐藏改为完全隐藏而非仅降透明度（§5.1）。`AnimatedToolbarPanel` 移除无用的 `opacity` 参数，4 秒闲置后 `showToolbar=false` 滑出屏幕，释放阅读区域并消除触摸拦截。
- **ChapterManager**：移除从未被调用的 `dispose()`（§8.1），`reset()` 改用 `stopAutoScroll()` 并置空 `_searchIndexOperation`，统一清理模式、消除死代码。
- **ReaderPage**：提取 4 个内联对话框为独立组件（§6.1）。`ReaderAnnotationDialog`（合并创建/编辑笔记）、`ReaderTranslationDialog`、`ReaderHighlightSheet` 分别独立文件，删除废弃 import。`ReaderAnnotationDialog` 内部管理 `TextEditingController` 生命周期。
- **ReaderPage**：`resetHideTimer` 模式统一为 `withTimer` 辅助函数（§6.3）。6 处 `action; resetHideTimer()` 重复替换为 `withTimer(action)`，消除代码重复。
- **ReaderPage**：`ThemeData` 改用 `useMemoized` 缓存（§6.4）。避免每次 build 创建新 `ThemeData` 导致整个子树重建，仅在 `readerTheme` 变更时重新计算。
- **i18n**：`ReaderAnnotationDialog`、`ReaderTranslationDialog`、`ReaderHighlightSheet` 三组件接入 `AppLocalizations`，移除全部硬编码中文。新增 `pasteTranslationPlaceholder` 多语言 key。
- **ReaderViewModel**：`loadHighlights` 添加章节缓存（§4.4）。`forceRefresh` 参数控制绕过缓存，保存/删除/更新后传 `true`，章节切换命中缓存时不调 API。切换书籍时清空缓存。
- **CacheManageViewModel**：构造函数移除 fire-and-forget `load()`（§4.5）。`load()` 移至 `useEffect` 调用，对齐 widget 生命周期，消除构造函数异步反模式。
- **CacheManageVM/Page**：移除空函数 `clearAllCache()` 及误导性的「清空全部缓存」按钮（§4.6）。Rust sled 自动管理缓存，Dart 端无对应功能，假操作已清除。
- **ReaderConfig/Page**：新增 `followSystemFontScale` 持久化开关（§5.7）。代替硬编码 `TextScaler.noScaling`，允许用户选择是否跟随系统字体缩放。对应设置在 ReaderSettingsPanel 中。
- **READER_ANALYSIS.md**：更新分析报告，标记 §2.5、§4.2、§4.4–4.6、§5.1、§5.7、§6.1、§6.3–6.4、§8.1 为 ✅ 已修复，添加 fix 注释。
- **ChapterManager**：`_searchIndexOperation` 的 `onCancel: () {}` 空回调替换为 `Logging.debug`（§8.2）。开发者可通过日志观察索引取消事件。
- **ChapterManager**：`_prefetchChapters` 改为批次并发（§8.3）。batchSize=2，避免 `for` 循环未 await 全部并行导致的 Rust 层压力。caller 使用 `unawaited` 继续不阻塞 UI。
- **ReadingSessionManager**：`_lastSaveTime` 初始值 `DateTime(2000)` 改为 `DateTime.fromMillisecondsSinceEpoch(0)`（§8.4）。语义清晰的「零值」哨兵，消除 2000 年这一非直观魔法值。
- **ReaderViewModel**：`loadPage()` 的 `saveProgress` 从 `await` 改为 `unawaited`（§8.6）。翻页不再阻塞进度保存，后台静默写入。内置 5 秒防抖 + 30 秒自动保存兜底。
- **RustReaderRepository**：`_spanToStyle` 链接移除硬编码 `Colors.blue`（§8.8）。链接颜色继承主题前景色（仅保留下划线装饰），消除深色/羊皮纸主题下对比度不足问题。
- **ReaderViewModel**：搜索匹配从 Dart `indexOf` 循环改为 FTS5（§2.1）。`onSearchChanged` 调用 `search_api.search()` 获取匹配数，widget 端 `_onSearchChanged` 删除。FTS5 索引未就绪时静默降级。
- **词汇词表**：`cet6`/`ielts`/`toefl` 三个 getter 改为返回各自词表而非全量（§2.3）。Rust 侧新增 `get_cet6_words`/`get_ielts_words`/`get_toefl_words` FBR API，Dart 侧 `VocabularyMarkerService` 分别加载。FRB 重新生成。
- **ReaderDictionaryPanel**：全部硬编码中文替换为 `AppLocalizations`（词条检索/错误提示/配置引导）。新增 `invalidMdxFile`/`dictionaryLoadFailed`/`selectDictionaryFile`/`selectMdxDescription` 等 i18n key。
  - `lib/features/reader/application/reader_view_model.dart`：移除 5 个 UI 面板 Signal（`showCatalog`/`showBookmarks`/`showToolbar`/`showSettings`/`showSelectionToolbar`）及对应 toggle 方法；`updateSelection`/`clearSelection`/`jumpToChapter`/`jumpToBookmark` 不再操作面板状态
  - `lib/features/reader/page/reader_page.dart`：新增 4 个 `useSignal(false)` 局部状态；`showSelection` 派生自 `vm.selectedText.value`；toggle/jump 回调改为局部 lambda
  - `lib/features/reader/page/widgets/reader_page_bindings.dart`：移除 5 个面板 bool 字段（class/constructor/both binding functions）
  - `lib/features/profile/application/other_settings_view_model.dart`：移除 `appVersion` Signal，改为页面 `useState`+`useEffect` 加载 PackageInfo
  - `lib/features/reader/application/reading_session_manager.dart`：`readingDuration`/`isReading` 改为 private 字段 + 公开 getter

### 文件变更（续）
| 创建 | `lib/features/learning_notes/page/widgets/note_item_card.dart` |
| 创建 | `lib/shared/widget/go_reading_empty_state.dart` |
| 修改 | `lib/features/vocabulary/page/widgets/vocab_word_list_view.dart` |
| 修改 | `lib/features/vocabulary/page/widgets/vocab_status_chip.dart` |
  - DI config 重新生成，移除 `LearningNotesViewModel` 注册
- **VocabTab UI 增强移植到 vocabulary 模块**
  - `VocabListItemTile` 增强：translation 显示、wordList badge、状态圆点指示器、book 图标替代 emoji、stagger fadeIn 动画
  - `vocabulary_page.dart` 空态增强：图标 + 引导文字 + "去阅读"按钮（指向 `/bookshelf`）
  - 增加 `index` 参数支持动画错峰

### 修复
- 修复 `ProfilePage.build` 方法缺少 `return Scaffold(` 导致的编译错误
  - `lib/features/profile/page/profile_page.dart`
- **VocabularyViewModel**：移除 `searchQuery` 死代码信号
- **VocabularyViewModel**：`_loadBookTitles()` 二次渲染闪烁修复 — 移入 `Future.wait` 并行加载
- **VocabStatsRow**：`stats!` 非空断言替换为局部变量 `final s = stats!`
- **LearningNotesViewModel**：`setNoteFilterBook` 支持直接通过 `noteList.value` 过滤（当 `_allNotes` 为空时）

### 导航
- **profile**："学习管理" 区域新增 "生词本" 菜单项 → `/vocabulary`
- **learning_notes**：AppBar 右侧新增生词本导航按钮 → `/vocabulary`
- **vocabulary**：空态 "去阅读" 按钮使用 `RoutePaths.bookshelf`

### 文件变更
| 操作 | 文件 |
|------|------|
| 修改 | `lib/features/vocabulary/application/vocabulary_view_model.dart` |
| 修改 | `lib/features/vocabulary/page/vocabulary_page.dart` |
| 修改 | `lib/features/vocabulary/page/widgets/vocab_list_item_tile.dart` |
| 修改 | `lib/features/vocabulary/page/widgets/vocab_stats_row.dart` |
| 修改 | `lib/features/learning_notes/application/learning_notes_view_model.dart` |
| 修改 | `lib/features/learning_notes/page/learning_notes_page.dart` |
| 修改 | `lib/features/learning_notes/page/widgets/stat_dashboard_widget.dart` |
| 修改 | `lib/features/profile/page/profile_page.dart` |
| 修改 | `test/widget/vocab_components_test.dart` |
| 修改 | `test/features/learning_notes/application/learning_notes_view_model_test.dart` |
| 修改 | `lib/di/service_locator.config.dart`（自动生成） |
| 删除 | `lib/features/learning_notes/page/widgets/vocab_tab_widget.dart` |
| 删除 | `lib/features/learning_notes/page/widgets/tab_switcher_widget.dart` |
