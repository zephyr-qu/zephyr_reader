# 过度工程审计 — Zephyr Reader

> 审计日期: 2026-06-03
> 审计日期: 2026-06-03 (最后更新: 2026-06-03)

---

## 概要

- **总发现数**: 28（已解决 4，保留决策 3，待接入 1，未处理 20）
- **按严重程度**: A-Critical: 10, B-Important: 12, C-Minor: 6
- **最大收益的前 3 项改进**:
  1. ✅ 空 Clean Architecture 目录已删除 → A1 已解决
  2. 将阅读器的 10 个 application 文件合并为 3-4 个 → 消除 1:1 委托链
  3. 清理 pubspec 和核心层中的企业级依赖 → 将 Dio/retrofit/pretty_logger/sentry 替换为简单 HTTP 客户端（或直接移除）
  *(另见: 2026-06-03 完成的设置统一存储层重构，创建 `PersistedSignal<T>` + `settings_keys.dart`)*

---

## A. 严重过度工程（违反"简洁优先"原则）

### A1. 7/9 功能模块具有空的 Clean Architecture 层

| 模块 | 空目录 |
|--------|-------|
| `home` | `data/repositories/`, `domain/repositories/` |
| `vocabulary` | `data/`, `domain/repositories/` |
| `statistics` | `data/repositories/`, `domain/` |
| `search` | `data/`, `domain/` |
| `profile` | `data/repositories/`, `domain/` |
| `bookshelf` | 无 `domain/` 或 `data/` 层（但也没有文件） |
| `learning_notes` | 无 `domain/` 或 `data/` 层（但也没有文件） |

- **证据**: 10 个空目录，共 7 个功能。每个目录作为架构占位符存在，无任何 dart 文件。
- **为何不匹配**: 个人离线阅读器不需要企业级 Clean Architecture 脚手架。没有 `data/` 或 `domain/` 文件的模块不应该拥有这些目录。

> **[已解决] 2026-06-03** — 所有空 `data/`/`domain/` 目录已清理。仅 `lib/features/reader/data` 和 `reader/domain` 保留（含实际文件）。

- **简化方向**: 删除所有空目录。将基础架构缩小为真实文件存在之处。每个功能 2 个目录（`page/` + `application/`）足以满足此应用的规模。

### A2. 阅读器模块：10 个 application 文件形成 1:1 委托链

- **路径**: `lib/features/reader/application/`
- **文件**: `reader_view_model.dart`（489 行）+ `chapter_manager.dart` + `annotation_controller.dart` + `reader_search_controller.dart` + `bookmark_controller.dart` + `bilingual_controller.dart` + `reading_session_manager.dart` + `cache_manage_view_model.dart` + `note_manage_view_model.dart`
- **模式**: `ReaderViewModel` 是一个门面，将 18 个 getter 委托给 4 个控制器 + 2 个管理器（`reader_view_model.dart:40-77`）：
  ```dart
  Signal<String> get bookId => chapterManager.bookId;
  Signal<int> get chapterIndex => chapterManager.chapterIndex;
  AsyncSignal<List<Chapter>> get chapters => chapterManager.chapters;
  // ... 16 个类似的委托
  ```
- **问题**: 每个控制器直接调用 Rust API（例如，`annotation_controller.dart:108-109` 只是 `await note_api.deleteNote(noteId: noteId);`）。控制器层除了在门面后面再加一层包装外，不提供任何增值。
- **为何不匹配**: 这是一个单用户页面，而不是微服务网格。每个控制器 1:1 对应一个功能，仅包装 3-5 个 Rust API 调用。
- **简化方向**: 将 `AnnotationController`、`BookmarkController`、`ReaderSearchController` 和 `BilingualController` 内联到 `ReaderViewModel` 中，或合并为一个 `ReaderService`。

### A3. 同步模块的企业级架构

- **路径**: `lib/features/sync/`
- **文件数量**: 6 个文件跨 3 层（page → application → application/services）
- **核心问题**: `sync_models.dart`（~106 行）定义：
  - `WebDavConfig` 带有 `copyWith`、`toJson`、`fromJson`
  - 3 个枚举（`SyncStatus`、`SyncDataType`、`SyncDirection`）
  - `SyncResult` 带有 `uploadedCount`、`downloadedCount`、`summary`、`toJson`、`fromJson`
  - `WebDavConfigHost` 抽象接口
  - 全部用于通过 WebDAV 同步 3 个 JSON 文件（阅读进度、书签、书架）
- **为何不匹配**: 同步 ~100KB 的个人阅读进度不需要经过建模的 `SyncResult`，也不需要抽象配置宿主接口。
- **简化方向**: 将 `webdav_sync_service.dart` 和 `webdav_config_service.dart` 合并为一个 `WebDavService`。删除 `sync_models.dart` 中除 `WebDavConfig` 外的所有内容。删除 `WebDavConfigHost` 抽象层。
### A4. 离线优先应用的核心网络层

> **[保留] 2026-06-03** — 经评估，决定保留网络层及 Dio 基础设施，作为 WebDAV 同步及未来可能的网络功能的底层框架。不做移除。

- **路径**: `lib/core/network/network_module.dart:18-84`
- **代码**:
  ```dart
  // 第19-30行
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,       // 'https://api.example.com'
    responseType: ResponseType.json,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: AppConfig.defaultHeaders,
  ));
  ```
  完整设置：`RetryInterceptor`（3 次重试，指数退避）+ `PrettyDioLogger` + 自定义错误拦截器 + 注释掉的 `sentry` 集成。
- **同时**: `lib/core/app_config.dart:16-23` 配置了虚拟 API 的 `baseUrl`、超时、重试参数。
- **问题**: 此应用使用 Dio 的唯一位置是 WebDAV 同步，但它使用 `webdav_client` 包，而不是 `Dio`。重试策略、超时配置和日志拦截器服务于零个活跃的 HTTP API 端点。`retrofit` 和 `pretty_dio_logger` 依赖项被拉进来但从未有效使用。
- **决定**: 保留现有实现。虽然当前只有 WebDAV 同步活跃使用，Dio 层为后续网络功能提供就绪基础设施，移除成本与重建成本不匹配。
- **简化方向**: 移除整个 `network_module.dart`。从 pubspec 中移除 `dio`、`dio_smart_retry`、`pretty_dio_logger`、`retrofit`、`retrofit_generator`。

### A5. ReaderRepository 中不必要的 Dart 层缓存

- **路径**: `lib/features/reader/data/repositories/rust_reader_repository.dart:71-74`
- **代码**:
  ```dart
  final Map<String, Map<int, ChapterCacheItem>> _cache = {};
  final Map<String, Map<int, TextSpan>> _richContentCache = {};
  final Map<String, Map<int, List<RichParagraph>>> _richParagraphCache = {};
  static const int maxCacheSize = 10;
  ```
- **问题**: Rust 排版引擎已经通过 `sled KV` 拥有排版缓存（README 中注明）。此 Dart 端缓存（伴随 694 行的仓库类）重复缓存且最大条目数为 10。该类还包含特定于 EPUB 的渲染细节（`_parseCssColor` 第 288-307 行、`_spanToStyle` 第 260-286 行、`_richParagraphsToRichText` 第 336-372 行），属于渲染层而非仓库层。
- **简化方向**: 信任 Rust `sled` 缓存。将 EPUB 富文本渲染移到专用的 Dart 渲染器中，或直接使用 Rust 的 `paginateAllContent`。将 `ReaderRepository` 从 694 行减到 ~150 行。

### A6. ConnectivityBanner 使用轮询而非流

- **路径**: `lib/core/presentation/widgets/connectivity_banner.dart:24-28`
- **代码**:
  ```dart
  timer.value = Timer.periodic(const Duration(seconds: 10), (_) {
    _checkConnectivity(isOnline);
  });
  ```
- **问题**: 每 10 秒轮询 `NetworkStateService.isConnected()`，而 `NetworkStateService` 已经有一个 `listen()` 方法（`network_state_service.dart:36-39`）。在离线阅读器上，轮询系统连接状态毫无意义，该阅读器的唯一网络操作是手动触发的 WebDAV 同步。
- **简化方向**: 移除 `ConnectivityBanner`（它对阅读体验贡献为零）。或者用 `NetworkStateService.listen()` 流订阅替换轮询。

### A7. 孤立无援的 BatteryStateService

- **路径**: `lib/core/battery/battery_state_service.dart`（38 行）
- **代码**: 用于查询充电状态、电池百分比和监听电池变化的完整单例。
- **问题**: 此服务不在任何功能模块中使用。README 中的功能列表不提到与电池相关的行为。没有常亮设置或其他功能依赖它。
- **简化方向**: 如果不需要，删除此文件。如果常亮是计划中的功能，将其内联到调用位置。

> **[待接入] 2026-06-03** — 计划在阅读页面使用（充电时保持常亮/低电量时调暗），等待接入。保留文件，不做删除。

### A8. 为个人 WebDAV 同步使用 flutter_secure_storage + SharedPreferences

- **路径**: `lib/features/sync/application/services/webdav_config_service.dart:11-12`
- **代码**: `WebDavConfigService` 同时需要 `SharedPreferences` 和 `FlutterSecureStorage`，管理 8 个键（第 26-32 行），为单用户阅读器存储 2 个凭证。
- **简化方向**: 使用单个 `SharedPreferences` 键将整个 `WebDavConfig` 存储为 JSON。移除 `flutter_secure_storage` 依赖。

### A9. 功能模块中的 @injectable 注册每个 ViewModel

- **路径**: `lib/di/service_locator.dart`（38 行）+ 自动生成的 `.config.dart` + `app_module.dart`
- **问题**: 对于只有 ~12 个 ViewModel、每个仅实例化一次的应用，`injectable` + `get_it` + `build_runner` + `.config.dart` 生成带来的开销毫无必要。
- **简化方向**: 删除 `injectable`/`get_it`。使用普通的 Dart 构造函数或简单的 `ViewModelProvider` 模式。移除 `injectable`、`injectable_generator`、`build_runner`（用于注入）依赖。

### A10. app_config.dart 中的企业运行时配置

- **路径**: `lib/core/app_config.dart:16-61`
- **证据**: `connectTimeoutSeconds`、`receiveTimeoutSeconds`、`retries`、`apiTimeout`、`defaultPageSize`，以及 `.env` 文件中从未被有效 HTTP API 使用的 `BASE_URL`。
- **简化方向**: 移除所有与网络相关的配置。移除 `flutter_dotenv`。使 `AppConfig` 成为一个仅包含实际使用设置的普通 Dart 类。

---

## B. 重要 — 与应用调性不符

### B1. BookDetailViewModel 中 7 个 Future.wait 调用

- **路径**: `lib/features/bookshelf/application/book_detail_view_model.dart:33-44`
- **代码**: 7 个独立的 FFI 调用获取书籍详情（book、progress、notes、chapters、categories、sessions、vocabulary），其中 `listSessionsByBook(limit: 10000)` 获取所有记录。
- **简化方向**: 创建 Rust 函数 `getBookDetail(bookId)` 一次性返回所有数据。删除硬编码的 `limit: 10000`。

### B2. bookshelf 的 page/widgets/ 中有 13 个 widget 文件

- **路径**: `lib/features/bookshelf/page/widgets/`（13 个文件，单一书籍详情页）
- **简化方向**: 合并为 3-4 个 widget：`BookDetailHeader`、`BookDetailInfo`、`BookDetailActions`。

### B3. 过度分解的 Reader widgets（page/widgets/ 中 17 个文件）

- **路径**: `lib/features/reader/page/widgets/`（17 个文件）
- **简化方向**: 合并相关的渲染器（scroll/pagination/bilingual）；将工具栏面板分组。

### B4. Reader 数据层：typeset 的 3 个导出文件

- **路径**:
  - `lib/features/reader/data/typeset_calibrator.dart`（133 行）
  - `lib/features/reader/data/typeset_config_builder.dart`（82 行）
  - `lib/features/reader/data/vocabulary_marker_service.dart`
- **简化方向**: 将 `buildTypesetConfig` 内联到 `ReaderRepository` 中。将 `typeset_calibrator.dart` 减为单个函数。合并到 1 个 ~60 行的文件中。

### B5. ViewModel 中手动的信号 dispose 样板代码

- **路径**: 出现在 `book_detail_view_model.dart:68-79`、`reader_view_model.dart:459-487` 等。
- **问题**: 每个 ViewModel 有 7-15 行手动 dispose 代码。容易遗漏。
- **简化方向**: 使用 `AutoDispose` mixin 或基类模式。

### B6. Statistics 功能有 3 个 application 文件

- **路径**: `lib/features/statistics/application/`（`statistics_view_model.dart`、`reading_sessions_view_model.dart`、`reading_stats_service.dart`）
- **简化方向**: 合并为 1 个 `StatisticsViewModel`。

### B7. ✅ `reader_enums.dart` 已内联到 `reader_config.dart`

> **[已解决] 2026-06-03** — `ReadingMode` 枚举已移至 `reader_config.dart`，`reader_enums.dart` 已删除。所有 11 处引用已更新。


### B8. ✅ 导入别名冲突已解决

> **[已解决] 2026-06-03** — 删除 `reader_view_model.dart` 中重复的别名导入 `as bilingual_api`，统一使用裸导入。`bilingual_api.createBilingualHighlightPair` 改为裸调用。


### B9. 多个 ViewModel 中重复的 AsyncState 模板代码

- **路径**: 出现在 `home_view_model.dart`、`statistics_view_model.dart` 等。
- **简化方向**: 如果 signals 是首选模式，使用 `AsyncSignal`/`AsyncState` 内建支持，不需要在每个 ViewModel 中手动 try/catch。

### B10-12: 其他过度分解

- 阅读器的 3 个独立管理页面（`note_manage_page.dart`、`cache_manage_page.dart`、`bookmark_manage_page.dart`）应为面板而不是全屏页面。
- `learning_notes/application/models/note_with_book.dart` 单独文件放一个简单数据类。
- `core/localization/enum_extensions.dart` 一个扩展方法就占一个文件。

---
## C. 次要 — 值得再次审视的边界情况

### C1. ✅ pubspec 未用依赖已清理

> **[已解决] 2026-06-03** — 移除 `cached_network_image`, `device_info_plus`。`retrofit`/`retrofit_generator`/`pretty_dio_logger`/`sentry_flutter`/`flutter_dotenv` 不在 pubspec 中（已提前清理）。

### C2. ✅ WebDavPreset 硬编码服务预设

> **[保留] 2026-06-03** — 为用户提供常见 WebDAV 服务商一键配置模板，属于实用 UX 功能，不做移除。

### C3. 空的 `data/repositories/` 目录

4 个模块中有空的 `data/repositories/` 目录。建议随模块改造时清理。

### C4. ✅ settings/ 薄包装

> **[保留] 2026-06-03** — 6 个设置组件维持全局视觉一致性，多处复用，属于合理封装。

### C5. ✅ 小工具独立文件

> **[保留] 2026-06-03** — `platform_guard.dart` 被 2 个服务共 7 次调用，保留合理复用。`device_id.dart` 已整合到 SettingsKeys，为多设备同步预留。

### C6. `library;` 声明清理

41 个文件有无参数的 `library;` 声明，纯装饰无功能。建议随其他修改顺手清理。

---

## 范围外观察

这些模式*看起来*像过度工程，但对于当前架构是有理由的：

- **Rust 引擎层**: 重型 Rust 引擎适用于需要性能的文本处理。这是预期的。
- **FRB 桥接**: 自动生成，不计算在内。
- **Signals + signals_flutter**: 选定的响应式原语，使用合理。
- **Freezed 数据类**: 必要的状态不变性保证，适度使用。
- **WebDAV sync 功能本身**: 合理。过度的是管理它的服务分层。
- **Reader widgets 的分解**: 17 个 widget 文件处于*可接受*一侧，但结合 application 层过度工程则需警惕。
---


## 变更记录

| 日期 | 变更 | 类型 |
|------|------|------|
| 2026-06-03 | A1 空目录已清理 | 已解决 |
| 2026-06-03 | A4 网络层决定保留 | 保留决策 |
| 2026-06-03 | 设置统一存储层重构 (`PersistedSignal<T>` + `settings_keys.dart`) | 已完成 |
  | 2026-06-03 | B7 `reader_enums.dart` 内联到 `reader_config.dart` | 已解决 |
  | 2026-06-03 | B8 统一 `bilingual.dart` 导入策略 | 已解决 |
  | 2026-06-03 | C1 移除 `cached_network_image`、`device_info_plus` | 已解决 |

## 建议优先级
1. **立即行动**: ~~删除所有空目录（A1）~~ ✅，~~移除未用依赖（C1）~~ ✅，移除网络层和依赖（A4 ⏭️ 保留、A10）
2. **本周**: 将阅读器 application 层减半（A2），压缩同步模块（A3）
3. **本月**: 瘦身 ReaderRepository（A5），移除 injectable（A9）
