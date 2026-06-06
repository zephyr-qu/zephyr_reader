# 过度工程审计 — Zephyr Reader

> 审计日期: 2026-06-03
> 审计日期: 2026-06-03 (最后更新: 2026-06-03)

***

## 概要

- **总发现数**: 28（已解决 14，保留决策 5，待接入 1，未处理 8）

## A. 严重过度工程（违反"简洁优先"原则）

### A3. 同步模块的企业级架构

- **路径**: `lib/features/sync/`
- **文件数量**: 6 个文件跨 3 层（page → application → application/services）
- **核心问题**: `sync_models.dart`（\~106 行）定义：
  - `WebDavConfig` 带有 `copyWith`、`toJson`、`fromJson`
  - 3 个枚举（`SyncStatus`、`SyncDataType`、`SyncDirection`）
  - `SyncResult` 带有 `uploadedCount`、`downloadedCount`、`summary`、`toJson`、`fromJson`
  - `WebDavConfigHost` 抽象接口
  - 全部用于通过 WebDAV 同步 3 个 JSON 文件（阅读进度、书签、书架）
- **为何不匹配**: 同步 \~100KB 的个人阅读进度不需要经过建模的 `SyncResult`，也不需要抽象配置宿主接口。
- **简化方向**: 将 `webdav_sync_service.dart` 和 `webdav_config_service.dart` 合并为一个 `WebDavService`。删除 `sync_models.dart` 中除 `WebDavConfig` 外的所有内容。删除 `WebDavConfigHost` 抽象层。

### A4. 离线优先应用的核心网络层

> **\[保留] 2026-06-03** — 经评估，决定保留网络层及 Dio 基础设施，作为 WebDAV 同步及未来可能的网络功能的底层框架。不做移除。

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

<br />

### A7. 孤立无援的 BatteryStateService

- **路径**: `lib/core/battery/battery_state_service.dart`（38 行）
- **代码**: 用于查询充电状态、电池百分比和监听电池变化的完整单例。
- **问题**: 此服务不在任何功能模块中使用。README 中的功能列表不提到与电池相关的行为。没有常亮设置或其他功能依赖它。
- **简化方向**: 如果不需要，删除此文件。如果常亮是计划中的功能，将其内联到调用位置。

> **\[待接入] 2026-06-03** — 计划在阅读页面使用（充电时保持常亮/低电量时调暗），等待接入。保留文件，不做删除。

<br />

### A9. 功能模块中的 @injectable 注册每个 ViewModel

- **路径**: `lib/di/service_locator.dart`（38 行）+ 自动生成的 `.config.dart` + `app_module.dart`
- **问题**: 对于只有 \~12 个 ViewModel、每个仅实例化一次的应用，`injectable` + `get_it` + `build_runner` + `.config.dart` 生成带来的开销毫无必要。
- **简化方向**: 删除 `injectable`/`get_it`。使用普通的 Dart 构造函数或简单的 `ViewModelProvider` 模式。移除 `injectable`、`injectable_generator`、`build_runner`（用于注入）依赖。

> **\[保留] 2026-06-03** — DI 的自动装配和单例管理对项目有实际价值，`build_runner` 的开销在个人项目中可接受。保留现有注入方式。

<br />

***

## B. 重要 — 与应用调性不符

<br />

### B2. bookshelf 的 page/widgets/ 中有 13 个 widget 文件

- **路径**: `lib/features/bookshelf/page/widgets/`（13 个文件，单一书籍详情页）
- **简化方向**: 合并为 3-4 个 widget：`BookDetailHeader`、`BookDetailInfo`、`BookDetailActions`。

### B3. 过度分解的 Reader widgets（page/widgets/ 中 17 个文件）

- **路径**: `lib/features/reader/page/widgets/`（17 个文件）
- **简化方向**: 合并相关的渲染器（scroll/pagination/bilingual）；将工具栏面板分组。

### B

### B6. Statistics 功能有 3 个 application 文件

- **路径**: `lib/features/statistics/application/`（`statistics_view_model.dart`、`reading_sessions_view_model.dart`、`reading_stats_service.dart`）
- **简化方向**: 合并为 1 个 `StatisticsViewModel`。

<br />

## 范围外观察

这些模式*看起来*像过度工程，但对于当前架构是有理由的：

- **Rust 引擎层**: 重型 Rust 引擎适用于需要性能的文本处理。这是预期的。
- **FRB 桥接**: 自动生成，不计算在内。
- **Signals + signals\_flutter**: 选定的响应式原语，使用合理。
- **Freezed 数据类**: 必要的状态不变性保证，适度使用。
- **WebDAV sync 功能本身**: 合理。过度的是管理它的服务分层。
- **Reader widgets 的分解**: 17 个 widget 文件处于*可接受*一侧，但结合 application 层过度工程则需警惕。

***

## 建议优先级

1. **本周**: 压缩同步模块（A3）
2. **后续**: 合并过度分解的 widgets（B2、B3、B4、B5、B6）

