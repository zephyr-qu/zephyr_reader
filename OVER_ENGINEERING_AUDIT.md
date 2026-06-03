# 过度工程审计 — Zephyr Reader

> 审计日期: 2026-06-03
> 审计日期: 2026-06-03 (最后更新: 2026-06-03)

---

## 概要

- **总发现数**: 28（已解决 14，保留决策 5，待接入 1，未处理 8）
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

### A2. ✅ 阅读器 10 个 application 文件 → 3 个

> **[已解决] 2026-06-03** — `AnnotationController`/`BookmarkController`/`BilingualController`/`ReaderSearchController` 内联到 `ReaderViewModel`，删除 4 个文件 + 17 个 getter 代理 + 4 个 DI 注册。当前 `application/` 保留 `reader_view_model.dart`、`chapter_manager.dart`、`reading_session_manager.dart` 共 3 个实体文件 + 2 个管理 VM。
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

### A5. ✅ ReaderRepository 缓存已移除

> **[已解决] 2026-06-03** — 删除 3 个冗余 Dart 缓存 map（信任 Rust sled）+ 7 个缓存管理方法 + 5 个死代码方法。当前页/章节的中间结果使用实例字段（`currentPages`/`currentRichContent`），无需多书多章 LRU。仓库从 694 行减至 ~500 行。渲染方法保留待后续移出。

### A6. ✅ ConnectivityBanner 已删除

> **[已解决] 2026-06-03** — `ConnectivityBanner` 对离线阅读器无实际意义（唯一网络操作为手动 WebDAV 同步），直接删除。轮询问题随之消除。

### A7. 孤立无援的 BatteryStateService

- **路径**: `lib/core/battery/battery_state_service.dart`（38 行）
- **代码**: 用于查询充电状态、电池百分比和监听电池变化的完整单例。
- **问题**: 此服务不在任何功能模块中使用。README 中的功能列表不提到与电池相关的行为。没有常亮设置或其他功能依赖它。
- **简化方向**: 如果不需要，删除此文件。如果常亮是计划中的功能，将其内联到调用位置。

> **[待接入] 2026-06-03** — 计划在阅读页面使用（充电时保持常亮/低电量时调暗），等待接入。保留文件，不做删除。

### A8. ✅ WebDAV 双存储已合并

> **[已解决] 2026-06-03** — 将 7 个 SharedPreferences 配置键合并为 1 个 JSON 键 + 密码保留 SecureStorage。删除 `WebDavConfigHost` 抽象类。配置服务从 179 行减至 ~120 行。

### A9. 功能模块中的 @injectable 注册每个 ViewModel

- **路径**: `lib/di/service_locator.dart`（38 行）+ 自动生成的 `.config.dart` + `app_module.dart`
- **问题**: 对于只有 ~12 个 ViewModel、每个仅实例化一次的应用，`injectable` + `get_it` + `build_runner` + `.config.dart` 生成带来的开销毫无必要。
- **简化方向**: 删除 `injectable`/`get_it`。使用普通的 Dart 构造函数或简单的 `ViewModelProvider` 模式。移除 `injectable`、`injectable_generator`、`build_runner`（用于注入）依赖。

> **[保留] 2026-06-03** — DI 的自动装配和单例管理对项目有实际价值，`build_runner` 的开销在个人项目中可接受。保留现有注入方式。

### A10. ✅ app_config.dart 企业级配置已清理

> **[已解决]** — `baseUrl`、超时、重试等网络配置已移除，`AppConfig` 缩减为 22 行的单例初始器。

---

## B. 重要 — 与应用调性不符

### B1. ✅ 7 个 Future.wait → 单 Rust 函数

> **[已解决] 2026-06-03** — Rust 侧创建 `get_book_detail` 聚合函数，Dart 侧 `BookDetailViewModel.loadData()` 从 7 次 FFI 调用 + 7 个 `as` 强转改为 1 次调用。去除 `limit: 10000` 硬编码。

### B2. bookshelf 的 page/widgets/ 中有 13 个 widget 文件

- **路径**: `lib/features/bookshelf/page/widgets/`（13 个文件，单一书籍详情页）
- **简化方向**: 合并为 3-4 个 widget：`BookDetailHeader`、`BookDetailInfo`、`BookDetailActions`。

### B3. 过度分解的 Reader widgets（page/widgets/ 中 17 个文件）

- **路径**: `lib/features/reader/page/widgets/`（17 个文件）
- **简化方向**: 合并相关的渲染器（scroll/pagination/bilingual）；将工具栏面板分组。
### B4. ✅ typeset 文件已合并
>
> **[已解决]** — `typeset_config_builder.dart`（82 行）已内联到 `typeset_calibrator.dart`，删除原文件。`vocabulary_marker_service.dart` 保持独立（职责无关）。

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
### B9. ✅ 重复 try/catch 模板已统一
>
> **[已解决]** — 创建 `lib/core/utils/async_utils.dart`，提供 `safeLoad()` 和 `AsyncStateSignalExt.loadAsync()`。已应用到 `home_view_model`、`statistics_view_model`、`bilingual_controller`、`bookmark_controller`。

### B10: 其他过度分解

- ~~阅读器的 3 个独立管理页面（`note_manage_page.dart`、`cache_manage_page.dart`、`bookmark_manage_page.dart`）应为面板而不是全屏页面。~~ ✅ B10 `NoteManagePage` 已改为底部面板；`CacheManagePage`/`BookmarkManagePage` 保留全屏
- ~~`learning_notes/application/models/note_with_book.dart` 单独文件放一个简单数据类。~~ ✅ B11 已内联到 `learning_notes_view_model.dart`
- ~~`core/localization/enum_extensions.dart` 一个扩展方法就占一个文件。~~ ✅ B12 已内联到各枚举定义文件

---
## C. 次要 — 值得再次审视的边界情况

### C1. ✅ pubspec 未用依赖已清理

> **[已解决] 2026-06-03** — 移除 `cached_network_image`, `device_info_plus`。`retrofit`/`retrofit_generator`/`pretty_dio_logger`/`sentry_flutter`/`flutter_dotenv` 不在 pubspec 中（已提前清理）。

### C2. ✅ WebDavPreset 硬编码服务预设

> **[保留] 2026-06-03** — 为用户提供常见 WebDAV 服务商一键配置模板，属于实用 UX 功能，不做移除。
### C3. ✅ 空 data/repositories/ 目录已清理
> **[已解决] 2026-06-03** — 仅 `lib/features/reader/data/repositories/` 保留（有实际文件），其余已全部删除。
### C4. ✅ settings/ 薄包装
>
> **[保留] 2026-06-03** — 6 个设置组件维持全局视觉一致性，多处复用，属于合理封装。

### C5. ✅ 小工具独立文件
>
> **[保留] 2026-06-03** — `platform_guard.dart` 被 2 个服务共 7 次调用，保留合理复用。`device_id.dart` 已整合到 SettingsKeys，为多设备同步预留。

### C6. ✅ `library;` 声明已清理

> **[已解决] 2026-06-03** — `lib/` 下 41 处 `library;` 声明已全部删除。

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
| 2026-06-03 | A5 ReaderRepository 移除冗余缓存 | 已解决 |
| 2026-06-03 | A8 WebDAV 双存储合并，删除 `WebDavConfigHost` | 已解决 |
| 2026-06-03 | 设置统一存储层重构 | 已完成 |
| 2026-06-03 | B7 `reader_enums.dart` 内联到 `reader_config.dart` | 已解决 |
| 2026-06-03 | B8 统一 `bilingual.dart` 导入策略 | 已解决 |
| 2026-06-03 | C1 移除 `cached_network_image`、`device_info_plus` | 已解决 |
| 2026-06-03 | B10 `NoteManagePage` 改为底部面板 | 已解决 |
| 2026-06-03 | A2 阅读器 4 控制器内联到 VM，删 4 文件 | 已解决 |
| 2026-06-03 | B1 7 Future.wait → Rust `get_book_detail` 聚合 | 已解决 |

## 建议优先级
1. **本周**: 压缩同步模块（A3）
2. **后续**: 合并过度分解的 widgets（B2、B3、B4、B5、B6）