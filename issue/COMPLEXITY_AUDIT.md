# 代码过度复杂化审计报告

> 生成日期: 2026-06-11  
> 范围: lib/ (Dart) + rust/src/ + rust/tests/ (Rust)  
> 排除: 自动生成文件 (`frb_generated.rs`, `service_locator.config.dart`)

---

## 严重度分级

| 级别 | 含义 | 数量 |
|------|------|------|
| 🔴 高 | 严重影响可维护性，建议优先处理 | 14 |
| 🟡 中 | 增加认知负担但可渐进改进 | 22 |
| 🟢 低 | 小瑕疵，顺手改即可 | 12 |

---

## 🔴 高严重度 — 建议优先改

### 1. ReaderViewModel 纯转发层 (Dart)

**文件**: `lib/features/reader/application/reader_view_model.dart` (415 行)

**问题**: 30+ 个 getter 只是把子 Controller 的信号直接转发出去，ReaderViewModel 本身零逻辑。

```dart
// 当前：415 行的纯转发
Signal<String> get bookId => chapterManager.bookId;
Signal<int> get chapterIndex => chapterManager.chapterIndex;
AsyncSignal<List<Chapter>> get chapters => chapterManager.chapters;
// ... 30+ 行重复

// 简化：页面直接消费 Controller
final chapterManager = getIt<ChapterManager>();
final bookId = chapterManager.bookId; // 直接用
```

**收益**: 删除整个 VM 类，每个信号只声明一次。

---

### 2. RichTextSpan 8 变体枚举 (Rust)

**文件**: `rust/src/domain/types/rich_text.rs` (255 行)

**问题**: Plain/Bold/Italic/BoldItalic/Underline/Strikethrough/Code/Link 各变体重复相同字段 `text, font_size, color`，所有方法写 8 次 arm match。

```rust
// 当前：200 行重复
enum RichTextSpan {
    Plain { text, font_size, color },
    Bold { text, font_size, color },
    Italic { text, font_size, color },
    // ... 5 more identical shapes
}

// 简化：样式与数据分离
struct RichTextSpanData { text: String, font_size: Option<f32>, color: Option<String> }
enum SpanStyle { Plain, Bold, Italic, BoldItalic, Underline, Strikethrough, Code }
// Link 单独处理
```

**收益**: 消去 ~150 行样板代码。

---

### 3. persisted_signal 9 个重复工厂函数 (Dart)

**文件**: `lib/core/settings/persisted_signal.dart` (283 行)

**问题**: `persistedBool`, `persistedInt`, `persistedDouble`, `persistedString`, `persistedNullableString`, `persistedNullableInt`, `persistedEnum`, `persistedEnumCustom`, `persistedColor` — 9 个函数结构完全相同，仅 SharedPreferences getter/setter 不同。

```dart
// 当前：9 个工厂，加新类型需新函数
PersistedSignal<bool> persistedBool(prefs, key, defaultValue, {debounce}) {
  final stored = prefs.getBool(key) ?? defaultValue;
  return PersistedSignal<bool>._(initialValue: stored, ...);
}
// ×9

// 简化：一个泛型工厂接受 reader/writer 闭包
PersistedSignal<T> persisted<T>({
  required T Function() reader,
  required Future<void> Function(T) writer,
  required T defaultValue,
}) { ... }
// 调用方：persisted<bool>(reader: prefs.getBool, writer: prefs.setBool, ...)
```

**收益**: 删除 170 行重复工厂代码。

---

### 4. 集成测试初始化样板 ×13 (Rust)

**文件**: `rust/tests/*.rs` (12 个文件)

**问题**: 每个集成测试文件都复制粘贴相同的 ~18 行 `TEST_STORAGE + ensure_storage_initialized()` 和 16 字段 `Book::new()` 样板。

```rust
// 当前：在每个测试文件里
static TEST_STORAGE: OnceLock<TempDir> = OnceLock::new();
async fn ensure_storage_initialized() -> TempDir { ... }
async fn ensure_book() -> Book {
    Book { id, title, author, ..., created_at, updated_at } // 16 字段
}
// ×12 文件

// 简化：提取到 common/mod.rs
pub async fn ensure_test_book() -> Book { ... }
pub async fn init_test_storage() -> TempDir { ... }
```

**收益**: 删除 ~250 行重复设置代码。

---

### 5. AppError 构造函数全部冗余 (Rust)

**文件**: `rust/src/domain/error.rs` (240 行)

**问题**: 14 个错误变体各有一个构造方法，仅包装参数进 `Into<String>`。

```rust
// 当前：110 行构造函数
impl AppError {
    pub fn file_not_found(path: impl Into<String>) -> Self {
        AppError::FileNotFound { path: path.into() }
    }
    // ×13 more
}

// 简化：直接构造
Err(AppError::FileNotFound { path: file_path.to_string() })
```

`thiserror` 已经自动派生 `Display` + `Error`，构造方法不增加价值。

**收益**: 删除 ~110 行。

---

### 6. ReaderPage 550 行 build() (Dart)

**文件**: `lib/features/reader/page/reader_page.dart` (550 行)

**问题**: `build()` 方法内定义 4 个闭包 builder (`buildContentArea`, `buildBottomArea`, `buildTopToolbar`, `buildSelectionToolbar`)，每次 rebuild 重建所有闭包。5 种面板状态通过独立 `useState`/`useSignal` 管理。

**收益**: 拆分 builder 为独立 Widget，合并面板状态。

---

### 7. reader_settings_overlay 950 行单文件 (Dart)

**文件**: `lib/features/reader/page/widgets/reader_settings_overlay.dart`

**问题**: 一个文件包含 4 个大型 section builder，每个内部重复实现 sectionHeader/sliderTile/toggle 等子组件。接受 35+ 个独立 callback 参数。

**收益**: 拆分为 4 个独立文件，传配置对象代替 callback 爆炸。

---

### 8. 3 条并行分页路径 (Dart)

**文件**: `lib/features/reader/page/widgets/paginated_renderer.dart` (532 行)

**问题**: Rust descriptor 分页 + PageInfo 缓存回退 + Dart 纯估算回退，三套路径并存。回退路径用硬编码 400×600 估算尺寸。

**收益**: 只保留 Rust 分页路径，失败显示错误。

---

### 9. cover_extractor trait 过度抽象 (Rust)

**文件**: `rust/src/parser/cover_extractor.rs` (250+ 行)

**问题**: `CoverExtractor` trait + 2 个实现 + `Arc<dyn CoverExtractor>` boxing + `OnceLock<HashMap>` registry。实际只有 Epub 和 Pdf 两种实现。

```rust
// 简化：枚举代替 trait
enum CoverExtractor { Epub, Pdf }
impl CoverExtractor {
    fn extract(&self, ...) -> Result<Vec<u8>> {
        match self { Self::Epub => extract_epub_cover(...), Self::Pdf => extract_pdf_cover(...) }
    }
}
// 无 vtable, 无 HashMap, 无 Arc
```

**收益**: 删除 trait + registry + boxing，~80 行。

---

### 10. API 缓存函数 ×4 重复 (Rust)

**文件**: `rust/src/api/core.rs` (~170 行)

**问题**: `try_get_cached_pages`/`try_save_cached_pages` 和 `try_get_cached_chunk`/`try_save_cached_chunk` 四组函数几乎一样，仅 `chunk_index: Some(n)` vs `chunk_index: None` 不同。

**收益**: 合并为 2 个接受 `Option<u32>` 的函数。

---

### 11. Parser 枚举手写 5×4 方法转发 (Rust)

**文件**: `rust/src/parser/mod.rs` (102 行)

**问题**: `Parser` 枚举的 4 个变体 + 5 个方法 = 20 次 `match { Parser::Epub(p) => p.foo(), ... }`。

```rust
// 当前：手写所有 arm
impl Parser {
    pub fn parse(&self, ...) {
        match self { Parser::Epub(p) => p.parse(...), ... }
    }
    // ×5 methods
}

// 简化：用宏生成
macro_rules! delegate {
    ($method:ident) => { pub fn $method(&self, ...) { match self { ... } } }
}
delegate!(parse); delegate!(extract_metadata); // ...
```

**收益**: 删除 ~60 行转发样板。

---

### 12. ResourceConfig dispose/resetToDefault 展开调用 (Dart)

**文件**: `lib/core/reader/reader_config.dart` (254 行)

**问题**: 14 个 PersistedSignal 字段，`dispose()` 展开写 14 次 `x.dispose()`，`resetToDefault()` 展开写 13 次 `x.reset()`。`followSystemFontScale` 在 dispose 里但不在 reset 里（不对称 bug）。

```dart
// 简化：用列表来管理
final _signals = <PersistedSignal>[];
void dispose() { for (final s in _signals) s.dispose(); }
void resetToDefault() { for (final s in _signals) s.reset(); }
```

**收益**: 删除 ~50 行并提供内置对称性保证。

---

### 13. reader_page_bindings 两套钩子重复 (Dart)

**文件**: `lib/features/reader/page/widgets/reader_page_bindings.dart`

**问题**: `useReaderBindings` (27 信号) 和 `useReaderContentBindings` (23 信号) 是两套几乎相同的钩子，仅字段略有不同。共 ~200 行，大量重复。

**收益**: 合并为一个带可选字段的钩子，或直接内联消费信号。

---

### 14. 测试 mock ReaderConfig 130 行 (Dart)

**文件**: `test/widget/reader_page_bindings_test.dart` (35-173 行)

**问题**: `_MockReaderConfig` 实现 14 个 `PersistedSignal` 的 `late final` 字段，每个都包含 `persistedEnum/Xxx(prefs, '', ...)` 初始化。130 行样板只为一个 mock。

**收益**: ReaderConfig 改为可接受 mock SharedPreferences 后可删除整个 mock 类。

---

## 🟡 中严重度

### 15. AppError 16 个相同断言测试 (Rust)

**文件**: `rust/tests/unit_domain_test.rs` (18-193 行)  

16 个 `test_apperror_*` 函数，每个 ~7 行做同样 3 个断言。用 macro/表驱动测试压缩为 ~20 行。

### 16. TypesetConfig validate 86 行重复检查 (Rust)

**文件**: `rust/src/domain/types/typeset.rs`  

7 个完全相同的 MIN/MAX 检查块，可用宏或辅助函数改写。

### 17. PageStreamer new_eager / new_lazy 重复计算 (Rust)

**文件**: `rust/src/text/pagination.rs`  

两构造函数各自独立计算 `font_size, line_spacing, page_height_px` 等，~40 行重复。

### 18. 4 个静态单词表加载器重复 (Rust)

**文件**: `rust/src/vocab_marker/wordlists.rs`  

CET4/CET6/IELTS/TOEFL 各相同模式 (`include_str! + serde_json::from_str + .collect()`)，合并为宏。

### 19. AppErrorMapper 16 路类型匹配 (Dart)

**文件**: `lib/core/utils/app_error_mapper.dart`  

按类型逐个匹配 16 种 AppError 变体返回中文消息。可用 switch 表达式或表驱动。

### 20. network_state_service 死代码 (Dart)

**文件**: `lib/core/network/network_state_service.dart`  

全文件每个方法返回硬编码 `false`/noop。插件已废弃，代码永远不会工作。直接删除。

### 21. RoutePaths / RouteNames 双份常量 (Dart)

**文件**: `lib/core/routing/route_constants.dart` (164 行)  

30 对平行常量需手动同步，已出现分歧（`RouteNames.bookmarkManage` 无对应 path）。路由名可从路径派生。

### 22. cache_utils 重复递归逻辑 (Dart)

**文件**: `lib/core/utils/cache_utils.dart`  

`_deleteDirectoryContents` 和 `_calculateDirectorySize` 共享相同的 `.list(recursive: true)` 迭代逻辑，仅 per-item 动作不同。提取 `_walkDir` 辅助函数。

### 23. bookshelf_book_content 网格/列表双份构建 (Dart)

**文件**: `lib/features/bookshelf/page/shelf/bookshelf_book_content.dart` (525 行)  

`_buildGridContent` 和 `_buildListContent` 重复所有选择/动画/手势/进度/状态逻辑，仅外层容器不同。抽取共享 Widget。

### 24. reader_content 6 个竞争 useEffect (Dart)

**文件**: `lib/features/reader/page/widgets/reader_content.dart` (562 行)  

6 个 useEffect (page sync, bilingual, auto-scroll, scroll listener, jump, vertical writing) 管理复杂生命周期。按渲染模式拆分 Widget。

### 25. highlight_painter 静态可变缓存 (Dart)

**文件**: `lib/features/reader/page/widgets/highlight_painter.dart` (416 行)  

静态类 + 静态可变缓存字段 + 手动版本计数器。改为实例类，合并 paint 路径。

### 26. chapter_manager 3 阶段加载流水线 (Dart)

**文件**: `lib/features/reader/application/chapter_manager.dart` (562 行)  

`loadChapter()` 100+ 行：firstSpine → partialPaginate → fullPaginate，各带缓存+回退。8+ Stopwatch 调用混在业务逻辑中。提取计时器 + 简化为单流水线。

### 27. ThemeManager 手写单例 + 手动 prefs (Dart)

**文件**: `lib/core/theme/theme_manager.dart` (175 行)  

手写 `_instance` + 私有构造函数 + `SharedPreferences.getInstance()` 直接调，不用 DI。`persistedEnum` 已存在于项目但未使用。改用 `persistedEnum<AppThemeType>`。

### 28. logging init/_instance 双重 PrettyPrinter (Dart)

**文件**: `lib/core/utils/logging.dart`  

`init()` 和 `_instance` getter 各自独立构建相同的 `PrettyPrinter(...)` 配置，须手动同步。提取 `_defaultPrinter()` 工厂。

### 29. app_theme _textTheme 11 种全部重写 (Dart)

**文件**: `lib/core/theme/app_theme.dart`  

每个 Material 文本样式完整指定 fontSize/fontWeight/letterSpacing（与默认值相同），仅改 color。用 `copyWith(color: ...)` 或只覆盖需要的样式即可。

### 30. battery_state_service 类型擦除结果 (Dart)

**文件**: `lib/core/battery/battery_state_service.dart`  

`Future.wait([...])` 返回 `List<Object?>`，通过 `results[0]`/`results[1]` 魔数索引取值。顺序错误编译期不报错。改为顺序 await。

### 31. haptic.dart 枚举包装已有 API (Dart)

**文件**: `lib/core/utils/haptic.dart`  

`HapticType` 枚举 + switch 函数把 `HapticFeedback.lightImpact()` 变成 `hapticFeedback(HapticType.light)`——更长的间接调用。直接 import `HapticFeedback` 即可。

### 32. font_repository 单个字体变更触发全量重新加载 (Dart)

**文件**: `lib/core/reader/custom_font_service.dart`  

`importFont()` 和 `deleteCustomFont()` 都调用 `loadFonts()` 全量扫描目录并重新注册。5 个字体无所谓，50+ 个字体 O(n) 每次变更。改为增量操作。

### 33. 空占位测试 (Rust)

**文件**: `rust/tests/api_test.rs`  

`test_search_initialization` 和 `test_dictionary_availability` 只有 `println!`，无断言。

### 34. validate_file_path_async 不必要的 spawn_blocking (Rust)

**文件**: `rust/src/utils/security.rs`  

`validate_file_path_async` 将同步 `stat()`/`is_file()` 包装在 `spawn_blocking` 中。这些 OS 调用不会阻塞 runtime。直接同步调用即可。

### 35. arc_extractor 字节级大小写比较 (Rust)

**文件**: `rust/src/parser/registry.rs`  

`format_from_extension` 手动 byte-by-byte ASCII tolower。`ext.to_lowercase().as_str()` 更清晰，分配量可忽略。

### 36. DI 三套并发策略 (Dart)

**文件**: `lib/di/service_locator.dart` + `lib/core/theme/theme_manager.dart`

(a) `@injectable` 注解 + 代码生成  
(b) `getIt.registerXxx()` 手动注册  
(c) ThemeManager 手写单例绕过 DI  

统一为一种策略。

---

## 🟢 低严重度

### 37. DesignTokens.spacing/radius switch 分发 (Dart)

`DesignTokens.spacing(Spacing.md)` 比 `Spacing.md.value` 多一次函数调用。改为扩展 getter。

### 38. AutoThemeService getSunriseTime/getSunsetTime (Dart)

`getSunriseTime()` 返回 `Duration(hours: darkModeEndHour.value)`，仅一行封装，无价值。

### 39. tts_service 手写句子分割 (Dart)

`_splitSentences()` 用字符级遍历分割句子。`RegExp(r'[.!?。！？](?=\s|$)').split(text)` 一行完成。

### 40. async_utils 不必要抽象 (Dart)

简单 `delay()` 包装 `Future.delayed()`，无额外价值。

### 41. format_utils formatFileSize 硬编码英文字符串 (Dart)

返回 "B"/"KB"/"MB"/"GB" 硬编码英文，不支持 i18n（而同一文件里的 `formatChars` 支持 i18n）。不一致。

### 42. kvStore 嵌套 match/if-let (Rust)

`get_layout_cache` 用 4 层嵌套模式匹配。可用 `and_then` / `or_else` 组合子拉平。

### 43. traverse_dom 200 行递归 (Rust)

`traverse_dom` 单函数 200 行深度嵌套 tag name match。拆分为小函数。

### 44. TypesetConfig 手动 Hash 实现 (Rust)

手动 `hash(&mut hasher)` 每个 field。`#[derive(Hash)]` + `ordered_float` 可替代。

### 45. 测试中并发 tokio 任务包装同步调用 (Rust)

`test_concurrent_format_checks` 对同步 `format_from_extension` 调用 spawn 4 个 tokio 任务。简单 for 循环即可。

### 46. book_detail_view_model 9 个独立信号 (Dart)

一次 API 调用加载 9 个信号，错误时分别设置。合并为单一状态 class + 1 信号。

### 47. reading_stats_view_model 4 个信号总是一起设置 (Dart)

vocabUnstarted/vocabLearning/vocabMastered/vocabIgnored 4 个 Signal<int> 总从同一个 VocabStats 对象同时设置。用单一信号。

### 48. auto_theme_service ThemeTimePreset + Extension (Dart)

3 选项枚举 + 扩展共 25 行。把 `l10nLabel` 直接放枚举即可。

---

## 总结

| 层级 | 文件数 | 可删除行数（估） | 主要模式 |
|------|--------|-----------------|---------|
| Dart core | 10 | ~200 | 工厂函数爆炸、重复迭代、死代码 |
| Dart features | 8 | ~300 | Facade 转发层、巨型 widget、并行回退路径 |
| Dart DI/app | 4 | ~50 | 三种 DI 策略混用、样板代码 |
| Rust src | 7 | ~350 | 枚举变体重叠、构造函数冗余、缓存 copy-paste |
| Rust tests | 10 | ~250 | 测试初始化样板 ×13、表驱动测试缺失 |
| **合计** | **39** | **~1150** | |

**核心原则**: 如果一段代码写了两次，提取；如果三份完全相同只是参数不同，用循环/表/宏；如果四份以上，立刻重构。

**高回报优先顺序**:  
1. ReaderViewModel 转发层 (删 415 行)  
2. Rust 集成测试样板 (删 250 行)  
3. RichTextSpan 枚举拆分 (删 150 行)  
4. persisted_signal 工厂合并 (删 170 行)  
5. AppError 构造函数删除 (删 110 行)  
