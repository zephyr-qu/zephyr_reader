# Utils 深度分析报告

> 分析基准：`lib/core/utils/` — 11 个文件
> 检测日期：2026-06-06

***

## 变更记录

| 日期 | 变更 |
|------|------|
| 2026-06-05 | 初版：发现 16 项问题，涵盖死代码、i18n 遗漏、`format_utils.dart` 命名冲突、`guardAndroid` 竞态、`CacheUtils` 低效遍历等 |
| 2026-06-06 | 修复 7 项（§4.2~4.4,4.6~4.8 已解决 + §4.1 确认）；确认 §2.3 device_id 死代码；更新 §5 测试覆盖 |

***

## 1. 架构总览

```
├── async_utils.dart            ← AsyncStateSignalExt (22 行)
├── logging.dart                ← Logging 封装 (46 行)
├── cover_utils.dart            ← resolveCoverPath (14 行)
├── cache_utils.dart            ← CacheUtils (144 行)
├── app_error_mapper.dart       ← AppErrorMapper (74 行)
├── device_id.dart              ← getOrCreateDeviceId (14 行)
├── date_formatters.dart        ← formatRelativeTime / formatDateYYYYMMDD (23 行)
├── format_utils.dart           ← formatFileSize (10 行)
├── platform_guard.dart         ← guardAndroid (9 行)
├── haptic.dart                 ← hapticFeedback (15 行)
└── adaptive_scroll_physics.dart ← adaptiveScrollPhysics (14 行)
```

**交叉引用**：
- `async_utils` → `logging`
- `cache_utils` → `logging`
- `app_error_mapper` → 无内部依赖（依赖 Flutter/DIO/FRB 类型）
- 其余文件无内部依赖

---

## 2. 功能覆盖与死代码

### 2.1 `AppErrorMapper` 未被 ViewModel 全面使用

`AppErrorMapper.humanReadable()` 能将异常转为用户可读消息且无 i18n 问题（因为所有消息面向中文用户），但搜索结果显示只有 **2 个文件** 使用它：

| 使用方 | 方式 |
|--------|------|
| `backup_view_model.dart` | ✅ `AppErrorMapper.humanReadable(e)` |
| `vocabulary_page.dart` | ✅ `AppErrorMapper.humanReadable(err)` |

但其他 ViewModel 直接用 `e.toString()` 展示错误：

| 文件 | 代码 |
|------|------|
| `reader_view_model.dart` | `error.value = '加载失败：$e'` |
| `reader_view_model.dart` | `error.value = '翻译失败：$e'` |
| `chapter_manager.dart` | `error.value = '章节加载失败：$e'` |
| `reader_view_model.dart` | `error.value = '加载失败：$e'` |

等等，这些是 `reader` 和 `chapter_manager`，它们在 feature 目录下，不是核心 utils。但需要被纳入优化范围。

### 2.2 `platform_guard.dart` 仅被 battery/network 使用

`guardAndroid` 在 `battery_state_service.dart` 和 `network_state_service.dart` 中使用了 5 次。如果代码库扩展到 iOS 平台（通过 FRB 暴露原生电池/网络 API），此函数需要重写。

这本身不是问题，但函数名和注释隐含 `guardAndroid` 仅保护 Android 平台调用。如果其他平台模拟器有对应实现，需要重构。

### 2.3 `getOrCreateDeviceId` 死代码 ✅

`lib/` 下零导入、零调用。仅测试文件引用自身。`uuid` 依赖仅此一处使用。

---

## 3. i18n 问题

### 3.1 `formatDateYYYYMMDD` 返回纯数字，可接受 ✅

### 3.2 `formatFileSize` 使用英文单位，可接受 ✅

使用英文单位（B/KB/MB/GB），在国际化层面可接受。

### 3.3 `CacheUtils` 日志硬编码中文

```dart
// cache_utils.dart:35,62,102,126,141
Logging.debug('清理缓存失败：$e');
Logging.debug('计算缓存大小失败：$e');
Logging.debug('删除目录内容失败：$e');
Logging.debug('计算目录大小失败：$e');
Logging.debug('获取日志目录失败：$e');
```

这些 `debug` 日志全部硬编码中文。虽然日志面向开发调试（非用户可见），但在英文团队的 CI 日志中难以阅读。

---

## 4. 代码质量问题

### 4.1 命名冲突（已解决）
~
`lib/shared/format_utils.dart` 已合并至 `lib/core/utils/format_utils.dart`，`lib/shared/` 目录已删除。
~
原 `formatFileSize` + `formatDuration` + `formatChars` 统一在 `core/utils/format_utils.dart` 中导出。

---

### 4.2 `CacheUtils.formatCacheSize` 与 `formatFileSize` 重复（已解决）✅

`CacheUtils.formatCacheSize` 已删除，统一使用 `formatFileSize`。`formatCacheSize` 使用 `toStringAsFixed(2)` 而 `formatFileSize` 使用 `toStringAsFixed(1)` 的不一致也不再存在。

---

### 4.3 `CacheUtils` 遍历文件计算大小 + 清理（已解决）✅

`_calcStorage(knownCacheBytes: 0)` 消除清理后立即重新遍历目录的冗余操作。`clearCache()` 后直接传入 `knownCacheBytes: 0`，跳过 `getCacheSize()` 调用。
---

### 4.4 `guardAndroid` 在未初始化的 platform 上返回默认值（已解决）✅

`catch (_)` 改为 `catch (e) { Logging.error(...) }`，不再沉默吞异常。

### 4.5 `AppErrorMapper` 所有消息硬编码中文

```dart
// app_error_mapper.dart
return '引擎内部错误，请重试或重启应用';
return '数据处理异常，请稍后重试';
return '网络异常，请检查网络连接';
// ... 14 条中文消息
```

`AppErrorMapper` 用于将异常转换为用户可见的消息字符串。所有 14 条消息都是中文硬编码，不经过 l10n。在英文环境下用户看到中文错误提示。

---

### 4.6 `Logging` 使用 `PrettyPrinter`（已解决）✅

已添加 `kReleaseMode ? null : PrettyPrinter(...)`，生产环境使用轻量 `SimpleLogPrinter`。

### 4.7 `Logging.error` 的 fallback 日志字符串异常（已解决）✅

`(logger threw: )` → `(logger threw: $e)`，已补全异常信息拼接。

---


### 4.8 `safeLoad` 未处理 factory 内部异步初始化（已解决）✅

`safeLoad` 零调用者，已直接删除。问题代码不复存在。

### 4.9 `adaptiveScrollPhysics` 平台枚举未覆盖 Web

Flutter Web 使用 `TargetPlatform.android` 或 `TargetPlatform.iOS`（取决于浏览器），所以该函数对 Web 有效。但如果 Web 版本的 `ListWheelScrollView` 需要 `BouncingScrollPhysics`，当前逻辑不提供。可接受。

---


## 5. 测试覆盖分析（截至 2026-06-06）

| 文件 | 单元测试 | 说明 |
|------|:--------:|------|
| `async_utils.dart` | ❌ | `loadAsync` 无测试 |
| `logging.dart` | ❌ | 日志框架通常不测 |
| `cover_utils.dart` | ❌ | 业务耦合（需 `AppConfig` mock） |
| `cache_utils.dart` | ❌ | 文件 IO 复杂但可用 `Directory.systemTemp` |
| `app_error_mapper.dart` | ❌ | 纯函数，易于测试 ✅ |
| `format_utils.dart` | ❌ | 纯函数，易于测试 ✅ |
| `date_formatters.dart` | ✅ | 已有测试 |
| `platform_guard.dart` | ✅ | 已有测试 |
| `haptic.dart` | ✅ | 已有测试 |
| `adaptive_scroll_physics.dart` | ✅ | 已有测试 |

`AppErrorMapper`、`formatFileSize` 是纯函数，无 IO 依赖，仍无测试覆盖。

---

## 6. 优化清单（截至 2026-06-06）

### P1（i18n）— 仍待处理

| 类别 | 项目 | 说明 |
|------|------|------|
| i18n | `AppErrorMapper` 12 条错误消息硬编码中文 | §4.5 |
| i18n | `CacheUtils` 5 处日志硬编码中文 | §3.3 |

### P2（代码质量）— 全部已解决 ✅

| 类别 | 项目 | 状态 |
|------|------|:----:|
| 代码 | 两个 `format_utils.dart` 命名冲突 | ✅ 此前已解决 |
| 代码 | `CacheUtils.formatCacheSize` 与 `formatFileSize` 重复 | ✅ 2026-06-06 |
| 代码 | `CacheUtils` 清理/计算两次遍历目录 | ✅ 2026-06-06 |
| 代码 | `guardAndroid` `catch(_)` 无声 | ✅ 2026-06-06 |
| 代码 | `Logging` 生产环境仍用 `PrettyPrinter` | ✅ 2026-06-06 |
| 代码 | `Logging.error` fallback 字符串无 `$e` | ✅ 2026-06-06 |

### P3（测试）— 部分已覆盖

| 类别 | 项目 | 状态 |
|------|------|:----:|
| 测试 | `AppErrorMapper` 无测试 | ❌ 仍缺 |
| 测试 | `formatFileSize` / `formatDuration` / `formatChars` 无测试 | ❌ 仍缺 |
| 测试 | `date_formatters` | ✅ 已有 |
| 测试 | `adaptiveScrollPhysics` | ✅ 已有 |
