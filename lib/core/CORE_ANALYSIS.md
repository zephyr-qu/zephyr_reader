# Core 层深度分析报告

> 分析基准：`lib/core/` — \~40 个文件
> 检测日期：2026-06-06

***

## 变更记录

| 日期         | 变更                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-06-05 | 全面重审：新增 `localBackup` 路由缺失（P0）、`ReaderConfig` 中文 displayName、`FontRepository` 构造器 fire-and-forget、`FileStorage` 同步 listSync、`NavigationMode` 死枚举等 19 项发现；保留 2026-06-03 所有原有分析与优化清单                                                                                                                                                                                                                                 |
| 2026-06-06 | 批量修复：`ColorScheme` 暗色模式色值（§3.2）、`ReaderTheme`/`ReaderFontSize` displayName 中文（§4.5）、`SnackUtils` 颜色硬编码（§3.6）、`DarkMode` 时间段重复（§4.3）、`FontRepository`/`TtsService` 构造器 fire-and-forget（§4.7/§4.8）、`ThemeManager` 初始化防重复（§6.1）、`localization/` 空目录（§6.1）、`AppConfig`/`NetworkStateService`/`BatteryStateService` 手动单例问题（§6.2/§6.3）、`AutoThemeService` 定时器精度（§4.4原文）、`SkeletonWidget` shimmer dispose 竞态（§6.1），共 14 项 |
| 2026-06-03 | 初版：覆盖架构评价、P0-P3 问题、测试覆盖分析                                                                                                                                                                                                                                                                                                                                                                                          |

***

## 1. 架构总览

```
lib/core/
├── app_config.dart                 ← 全局配置单例（coverDir）
├── theme/ (7 files)                ← 主题系统
├── utils/ (11 files)               ← 工具函数
├── settings/ (2 files)             ← 持久化信号基础设施
├── routing/ (2 files)              ← 路由定义
├── reader/ (3 files + 1 model)     ← 阅读器配置 & 字体服务
├── localization/ (empty)           ← 预留
├── network/ (3 files)              ← 网络监控 & WiFi 传书
├── battery/ (1 file)               ← 电池监控
├── dictionary/ (1 file)            ← 内置词典
├── local/ (1 file)                 ← 文件存储
└── presentation/
    └── widgets/ (9 files)          ← 通用 UI 组件
```

***

## 2. 架构评价 ← 保留 2026-06-03 内容

### 设计亮点 ✅ ← 不变

(保留原有 8 项设计亮点)

### 设计权衡 ⚖️ ← 不变

(保留原有 4 项设计权衡)

***

## 3. P0 级问题

### 3.1 `BackupPage` 路由缺失（导航断裂）⚠️ ❌

```dart
// route_constants.dart:53,109
RoutePaths.localBackup = '/settings/local-backup';
RouteNames.localBackup = 'localBackup';
```

`route_constants.dart` 中正确定义了 `localBackup` 的路径和名称，`profile_page.dart` 也通过 `context.push(RoutePaths.localBackup)` 导航，但 **`app_router.dart`** **中没有注册对应的** **`GoRoute`**。

```dart
// app_router.dart 中已注册备份相关路由：
GoRoute(name: RouteNames.storageSync, ...)  // 存储与同步 ✅

// 但缺少：
// GoRoute(name: RouteNames.localBackup, path: RoutePaths.localBackup,
//         builder: (_, _) => BackupPage())
```

**修复**：在 `app_router.dart` 的 `ShellRoute` 内部或独立路由中增加：

```dart
GoRoute(
  name: RouteNames.localBackup,
  path: RoutePaths.localBackup,
  builder: (_, _) => BackupPage(),
)
```

注意需要在文件头部添加 `import 'package:zephyr_reader/features/backup/page/backup_page.dart';`。

<br />

### 3.3 `NavigationStateService` / `BatteryStateService` Android-only ← 保留 2026-06-03 ⚠️ 部分已解决

(保留原有描述，增加 iOS 扩展建议)

> **2026-06-06 复核**：`NavigationStateService` 类已从代码库中完全移除 ❌→✅。`NetworkStateService` 和 `BatteryStateService` 仍使用 `guardAndroid` 保护，iOS 平台会返回默认值。‼ 未解决。

### 3.4 `HelpItem` 使用 `Colors.blue` / `Colors.grey.shade600` 硬编码 ← 保留 2026-06-03 ❌

(保留原有描述)

<br />

***

## 4. P1 级问题（新增 + 原有）

<br />

### 4.2 `AppThemes.buildTheme` 每次 rebuild 创建新 ThemeData（更新）❌

### 4.6 `FontRepository` 字体名称硬编码中文 ❌

```dart
// custom_font_service.dart:108-111
FontInfo(id: 'system', name: '系统默认', isBuiltIn: true),
FontInfo(id: 'serif', name: '宋体', isBuiltIn: true),
FontInfo(id: 'sans', name: '黑体', isBuiltIn: true),
```

系统字体名称不经过 l10n。英文用户看到中文名。

### 4.7 `FontRepository` 构造器 fire-and-forget `_initialize()` ❌

```dart
// custom_font_service.dart:14-16
FontRepository(this._prefs) {
  _initialize();
}
```

<br />

### 4.9 `PersistedSignal` `_readEnum` 使用 `catch(_)` 吞异常 ❌

```dart
// persisted_signal.dart:199-204
T _readEnum<T extends Enum>(...) {
  try { return parser(stored); }
  catch (_) { return defaultValue; }
}
```

如果存储的枚举值因版本迁移导致 `parser` 抛出非预期的异常，异常被静默吞没，返回默认值。用户设置丢失但无人知晓。

### 4.10 `ReaderConfig.fontSizeValue` 读取时四舍五入但写入时不约束 ❌

```dart
double get fontSizeValue => ReaderFontSize.fromSize(fontSize.value).size;
```

`fontSize` 信号存储自由的 double 值（来自 Slider），但 `fontSizeValue` getter 通过 `ReaderFontSize.fromSize` 四舍五入到最近的档位（14/16/18/20）。如果用户从 Slider 选择 15.0，getter 返回 16.0（medium），但写入仍存 15.0 — 下次读取仍得到 16.0。数值和显示不一致。

***

## 5. 代码层问题（新增 + 原有）

### 5.1 `FileStorage._getDirSize` 使用 `listSync()` 阻塞 ❌

```dart
// file_storage.dart:107-114
final files = dir.listSync(recursive: true, followLinks: false);
for (var file in files) { if (file is File) total += await file.length(); }
```

`listSync()` 同步遍历目录树，对于大型文档目录（如含封面缓存）可能阻塞 UI 线程数百毫秒。对比 `CacheUtils._calculateDirectorySize` 已使用异步 `dir.list()`，两者不一致。

### 5.2 `FontRepository._loadCustomFonts` 使用 `listSync()` ❌

```dart
// custom_font_service.dart:142
final files = fontDir.listSync().whereType<File>().where(...)
```

同上，同步遍历。

### 5.3 `FileStorage.getUsage` 返回 KB（与其他接口不一致）❌

```dart
return (total / 1024).ceil();  // KB
```

注释写"使用空间（KB）"，但同一 layer 的 `CacheUtils.getCacheSize()` 返回 bytes。外部消费者容易混淆。

### 5.4 `NavigationMode` 枚举死代码 ❌

```dart
// adaptive_layout.dart:84-88
enum NavigationMode {
  bottomNavigationBar,
  navigationRail,
  permanentNavigationRail;
}
```

定义了完整的导航模式枚举，但全代码库搜索 `NavigationMode.` 返回 **0 个匹配** — 从未被使用。

### 5.5 `SelectionChip` 使用 `GestureDetector` 无 Ripple ❌

```dart
// selection_chip.dart:22
child: GestureDetector(onTap: onTap, ...)
```

项目已有多处将 `GestureDetector` 改为 `InkWell` 以获取 ripple 效果（BOOKSHELF\_ANALYSIS §2.11），但 `SelectionChip` 未被修复。

### 5.6 `SelectionChip` 接受 `ColorScheme` 而非使用 `Theme.of(context)` ❌

```dart
class SelectionChip extends StatelessWidget {
  final ColorScheme colorScheme;  // 参数化
  ...
  // 调用方每次都手动传入 Theme.of(context).colorScheme
}
```

每次使用时需要手动传参，调用方模板代码多。如果改为内部读取 `Theme.of(context).colorScheme`，调用方只需传 `label`，`onTap`。

***

## 6. 潜在问题（更新）

### 6.1 保留原有 8 项（5.1–5.8）❌ 5 项未解决，3 项已解决

保留 CORE\_ANALYSIS.md §5.1–5.8 内容（WiFi 传输服务监听 loopback、二进制解析、重试拦截器、PersistedSignal 可选类型嵌套、cover\_utils）。

> **2026-06-06 ✅ ThemeManager 初始化防重复已解决**：`init()` 方法增加 `Future<void>? _initFuture` 惰性初始化守卫。第一次调用启动 `_doInit()`，后续并发调用复用同一 Future；初始化完成后 `_initialized` 短路返回。消除了 async gap 期间重复初始化导致重复注册 effect 的问题。
> **2026-06-06 ✅ localization/ 空目录已解决**：删除 `lib/core/localization/` 空目录。该目录无任何文件且未被任何 import 引用，项目使用 `lib/l10n/` 进行 i18n。
> **2026-06-06 ✅ SkeletonWidget 3s shimmer dispose 竞态已解决**：`useEffect` 中 `Future.delayed().then(...)` 改为 `Timer(duration, callback)` + 返回 `timer.cancel` 作为 dispose 回调。Widget 被 dispose 时自动取消定时器，不再触发已 disposed state 的写入。

<br />

### 6.4 `FontRepository` 中 `_getUniqueFilePath` 使用 `existsSync()` ❌

```dart
while (File(destPath).existsSync()) { ... }
```

在异步方法中使用同步文件检查，小问题但积累多了影响性能。

***

## 7. 测试覆盖分析

### 保留 2026-06-03 表格

| 组件                 | 单元测试 | 新增发现                                  |
| ------------------ | ---- | ------------------------------------- |
| `ReaderConfig`     | ❌    | 13 个 persistedSignal 组合，数值/枚举序列化反序列化  |
| `FontRepository`   | ❌    | 字体加载、注册、导入、删除路径                       |
| `TtsService`       | ❌    | `_init()` 完成前调用保护                     |
| `PersistedSignal`  | ❌    | debounce、`saveImmediately`、dispose 隔离 |
| `AppRouter`        | ❌    | 路由完整性（`localBackup` 缺失即因此发现）          |
| `FileStorage`      | ❌    | 异步/同步路径一致性                            |
| `AppErrorMapper`   | ❌    | 14 种异常映射（已在 UTILS\_ANALYSIS 中记录）      |
| 其他 4 个（2026-06-03） | ❌    | <br />                                |

***

## 8. 优化清单

### P0（功能性 Bug）

| 类别  | 项目                           | 说明   | 状态    |
| --- | ---------------------------- | ---- | ----- |
| Bug | `BackupPage` 无路由注册 → 导航至 404 | §3.1 | ❌ 未解决 |

### P1（代码正确性）

| 类别   | 项目                                                   | 说明                                         | 状态     |
| ---- | ---------------------------------------------------- | ------------------------------------------ | ------ |
| i18n | `ReaderTheme` / `ReaderFontSize` displayName 中文      | §4.5 ✅ 已解决 — 移除 `displayName` 字段           | <br /> |
| i18n | `FontRepository` 系统字体名中文                             | §4.6                                       | ❌      |
| 代码   | `PersistedSignal._readEnum` `catch(_)` 吞异常           | §4.9                                       | ❌      |
| 代码   | `FileStorage._getDirSize` `listSync()` 阻塞            | §5.1                                       | ❌      |
| 代码   | `FontRepository._loadCustomFonts` `listSync()` 阻塞    | §5.2                                       | ❌      |
| 代码   | `ReaderConfig.fontSizeValue` 读写不一致                   | §4.10                                      | ❌      |
| 代码   | `FileStorage.getUsage` 返回 KB 非 bytes（接口不一致）          | §5.3                                       | ❌      |
| 代码   | `DarkMode` 时间段判断重复 2 次                               | §4.3 ✅ 已解决 — 提取 `_isDarkHour` 静态方法统一调用     | <br /> |
| 代码   | `FontRepository` 构造器 `_initialize()` fire-and-forget | §4.7 ✅ 已解决 — `Completer<void> _ready` 异步守卫 | <br /> |
| 代码   | `TtsService` 构造器 `_init()` fire-and-forget           | §4.8 ✅ 已解决 — `Completer<void> _ready` 异步守卫 | <br /> |
| 代码   | `AppThemes.buildTheme` 每次 rebuild 创建新 ThemeData      | §4.2                                       | ❌      |

### P2（代码整洁/死代码）

| 类别  | 项目                                                                    | 说明                                                          | 状态     |
| --- | --------------------------------------------------------------------- | ----------------------------------------------------------- | ------ |
| 死代码 | `NavigationMode` 枚举全量未被引用                                             | §5.4                                                        | ❌      |
| 代码  | `SelectionChip` `GestureDetector` 无 ripple                            | §5.5                                                        | ❌      |
| 代码  | `SelectionChip` 参数化 `ColorScheme` vs 自动获取                             | §5.6                                                        | ❌      |
| 架构  | `AppConfig`/`NetworkStateService`/`BatteryStateService` 手动单例与 DI 冲突风险 | §6.2 ✅, §6.3 ✅ 已解决 — 全部移除 factory 构造函数，改用 `instance` getter | <br /> |

### ✅ 已解决项目

| 类别 | 项目                           | 说明                                                                                   | 解决日期       |
| -- | ---------------------------- | ------------------------------------------------------------------------------------ | ---------- |
| 架构 | `NavigationStateService` 被移除 | §3.3 ⚠️ 部分解决 — 类已从代码库删除，但 `NetworkStateService`/`BatteryStateService` 仍 Android-only | 2026-06-06 |

