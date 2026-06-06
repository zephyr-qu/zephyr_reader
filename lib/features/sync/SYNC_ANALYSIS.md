# Sync Feature 深度分析报告

> 分析基准：`lib/features/sync/` — 6 个文件
> 检测日期：2026-06-03

> **最后审查：2026-06-06**
> **修复状态：17 项已修复 / 1 项已过时 / 3 项已删除（自动同步相关），详见下方标记**

***

## 1. 架构总览

```
sync/
├── application/
│   ├── storage_sync_view_model.dart     ← 同步/storage VM（~145 行）
│   └── services/
│       ├── webdav_sync_service.dart     ← WebDAV 同步引擎（~310 行）
│       ├── webdav_config_service.dart   ← WebDAV 配置管理（~170 行）
│       └── sync_models.dart             ← 数据模型（~95 行）
├── page/
│   ├── storage_sync_page.dart           ← 存储与同步主页（~523 行）
│   └── widgets/
│       └── webdav_config_dialog.dart    ← WebDAV 配置弹窗（~190 行）
```

**数据流**：

```
StorageSyncPage → StorageSyncViewModel
                    ├── WebDavConfigService（配置存 SharedPreferences + FlutterSecureStorage）
                    └── WebDavSyncService（DIO + webdav_client 引擎）
```

**设计亮点**：

- ✅ 密码使用 `FlutterSecureStorage`（Keychain/EncryptedSharedPreferences）
- ✅ 配置 JSON 存在 `SharedPreferences`，密码单独加密存储
- ✅ 支持双向同步（upload / download / both）
- ✅ 二层确认（"重置所有数据"需 2 次对话）
- ✅ 预置 5 个 WebDAV 服务商（坚果云/Nextcloud/ownCloud/Seafile/其他）
- ✅ `CancelToken` 支持取消同步
- ✅ `SignalBuilder` + 动画过渡
- ✅ 存储用量可视化（书籍/数据库/缓存百分比条）

***

## 2. P0 级问题
> **状态：部分已修复 — §2.4 对话框已 i18n，页面主体和弹窗仍有 ~20 处硬编码**
>
> **2026-06-06 变更：** `webdav_config_dialog.dart` 全部 ~20 处字符串 → l10n；`storage_sync_page.dart` 危险操作区、确认弹窗、触发同步的 Snack 消息改用 l10n；`_showFinalConfirm`、`_triggerSync` 消息改用 l10n
### 2.1 同步引擎只做简单时间戳覆盖 — 无冲突检测

```dart
// webdav_sync_service.dart:148-192
// 逻辑：
// 仅本地有 → 上传
// 仅远程有 → 下载
// 都有 → 本地覆盖远程（本地优先）
```

没有时间戳比对、没有 diff 合成、没有冲突提示。两人使用同一账号在不同设备同步时，后同步的完全覆盖前者的数据。这是**单用户场景可接受但数据不安全**的设计——如果用户在设备 A 修改了数据、在设备 B 也修改了数据，其中一方的修改会丢失。

### 2.2 同步失败时局部成功被标记为整体失败

> **状态：❌ 未修复**

```dart
// webdav_sync_service.dart:112-114
} else {
  result.error = opResult.$2;  // 记录错误但不 break
}

// line 121:
result.success = result.error == null;
```

如果 3 种数据类型（progress/bookmarks/bookshelf）中的 2 种成功、1 种失败，`result.success` 为 false，但 `uploadedCount`/`downloadedCount` 已经累加。**调用方无法得知哪些成功了哪些失败了**——只看到「同步失败」但部分数据实际已上传/下载。

<br />

### 2.4 所有 UI 字符串硬编码中文

`storage_sync_page.dart` 几乎全部用户可见字符串硬编码：

| 位置                                                       | 字符串                                    |
| -------------------------------------------------------- | -------------------------------------- |
| `storage_sync_page.dart:33`                              | `'存储与同步'`                              |
| `storage_sync_page.dart:45`                              | `'刷新'`                                 |
| `storage_sync_page.dart:87-93`                           | `'正在同步…'`、`'未配置同步'`、`'尚未同步'`、`'数据已同步'` |
| `storage_sync_page.dart:172`                             | `'立即同步'` / `'去配置'`                     |
| `storage_sync_page.dart:222`                             | `'本地存储'`                               |
| `storage_sync_page.dart:266-278`                         | `'书籍'`、`'数据库'`、`'缓存'`                  |
| `storage_sync_page.dart:322`                             | `'同步配置'`                               |
| `storage_sync_page.dart:334-337`                         | `'WebDAV 服务器'`、`'未配置'`                 |
| `storage_sync_page.dart:459,462,466,474,486-487,498-499` | 弹窗全部文本                                 |
| `storage_sync_page.dart:514,519`                         | SnackBar 消息                            |
| `webdav_config_dialog.dart:32`                           | `'配置 WebDAV'`                          |

***

## 3. 国际化（i18n）问题
> **状态：部分已修复 — `webdav_config_dialog.dart` 和危险操作/弹窗区已本地化，页面主状态区和 section label 仍有 ~20 处硬编码**
>
> 当前 sync 模块共使用约 15 个 l10n key（`webdavConfig`、`serverUrl`、`username`、`password`、`remotePath`、`cancel`、`save`、`dangerZone`、`clearAllData`、`clearAllDataTitle`、`clearAllDataContent`、`confirmAgain`、`continueAction`、`syncSuccess`、`syncFailed`、`syncConfigInvalid`、`dataCleared`、`dataClearFailed`、`unknownError` 等），但仍缺 AppBar title、status header 4 态文本等

***

## 4. ViewModel 设计缺陷

### 4.1 `StorageSyncViewModel` 直接实例化 `WebDavConfigService`

> **状态：❌ 未修复**

```dart
final configService = WebDavConfigService(prefs: getIt<SharedPreferences>());
```

VM 没有通过 DI 注入 `configService`，而是直接 `new` 实例。这使得单元测试中难以 mock 配置服务。

<br />

### 4.3 `_dirSize` 遍历不计异常
> **状态：✅ 已修复（2026-06-06）**
>
> 内层添加 `try-catch` 包裹 `entity.length()`，单文件异常不会中止整个遍历：
<br />

### 4.5 `StorageSyncViewModel` 无 `dispose` 方法

> **状态：❌ 未修复** — VM 无 dispose，但文档注释说明当前不需要（FRB 等不需要手动释放）

虽然是 `factory`（页面每次重建），但 `WebDavConfigService` 持有的 `FlutterSecureStorage` 访问不需要 dispose。

***

## 5. UI/UX 问题

### 5.1 状态 Header 固定深蓝色渐变

> **状态：✅ 已修复（2026-06-06）**
>
> `Color(0xFF1E3C72)/Color(0xFF2A5298)` → `cs.primary / cs.primary.withValues(alpha: 0.7)`，文字配色改用 `cs.onPrimary`

<br />

### 5.3 无自动同步定时器

> **状态：🗑️ 已删除（2026-06-06）**
>
> 自动同步功能（`autoSyncEnabled`/`autoSyncInterval` 信号、`setAutoSync` 方法、l10n key、测试用例）已整块删除。§5.3、§7 自动同步条目、§10 对应 P1 项一并清除。

<br />

### 5.4 同步进度仅存储为 signal 但 UI 未消费

> **状态：❌ 未修复**
>
> `WebDavSyncService.syncProgress` 在同步过程中更新，但 `StorageSyncPage` 和 `StorageSyncViewModel` 没有展示进度条。

<br />

### 6.1 `_confirmReset` 弹窗与 profile 重复

> **状态：✅ 已修复（2026-06-06）**
>
> 提取共享对话框 `showConfirmActionDialog`（`lib/core/presentation/widgets/confirm_action_dialog.dart`），sync 和 profile 两端改用该组件，每端减少 ~25 行重复代码

### 6.2 `WebDavConfigService` 与 `WebDavSyncService` 连接测试重复

> **状态：✅ 已修复（2026-06-06）**
>
> 删除 `_getConnectedClient()` 中的 `await _client!.ping()`。配置测试 `testCurrentConfig()` 保留自己的 ping。

### 6.3 危险操作区域重复

> **状态：✅ 已修复（2026-06-06）**
>
> 提取共享组件 `DangerSection` + `DangerItem`（`lib/core/presentation/widgets/danger_section.dart`），sync 和 profile 两端改用。删除了 profile 端的 `_dangerItem` 私有方法（~50 行）。


### 6.4 `formatBytes` 与项目其他格式化

`formatBytes` 在 `storage_sync_view_model.dart:99-105` 中实现。项目其他地方可能有相同的格式化（待验证）。

***

## 7. 假实现 / stub 分析

| 类型                   | 位置                                             | 说明                                                     | 状态    |
| -------------------- | ---------------------------------------------- | ------------------------------------------------------ | ----- |
| **重置数据确认按钮**         | `storage_sync_page.dart:370-374`               | 二次确认弹窗的确认按钮现在调用 `vm.clearAllLocalData()` 执行全量数据清除      | ✅ 已修复 |
| **自动同步**             | `WebDavConfigService` + `StorageSyncViewModel` | 整块删除（signal + method + l10n + test）              | 🗑️ 已删除 |
| **同步进度 signal**      | `WebDavSyncService`                            | `syncProgress` 更新但 UI 未消费                              | ❌ 未修复 |
| **`totalAvailable`** | `storage_sync_view_model.dart:28`              | 从未从 `FileSystemStat` 获取可用空间（始终为 0）                    | ❌ 未修复 |

***

### 8.1 同步数据类型仅有 3 项

> **状态：❌ 未修复**

```dart
enum SyncDataType {
  readingProgress('reading_progress.json', '阅读进度'),
  bookmarks('bookmarks.json', '书签'),
  bookshelf('bookshelf.json', '书架');
}
```

不包含：阅读设置、自定义词典配置、笔记CSV、生词表。用户期望的「全量备份」只有部分数据。

### 8.2 密码明文传入 `webdav.newClient`

> **状态：✅ 已修复（2026-06-06）**
>
> 密码在 `_getConnectedClient()` 中通过 `Uint8List` 零化 + `config.clearPassword()` 缩短堆生命周期。注释说明 Dart `String` 不可擦除的固有限制。

<br />

### 8.3 `webdav_client` 包的 `mkdirAll` 可能抛异常

> **状态：❌ 未修复**

```dart
await _client!.mkdirAll(remoteDir, _cancelToken);
```

如果远程目录已存在，某些 WebDAV 服务器返回 405（Method Not Allowed）而非 200，导致 `_ensureRemoteDirectory` 返回 false。不同服务商兼容性可能有问题。

### 8.4 `_fileExists` 读整个目录

> **状态：✅ 已修复（2026-06-06）**
>
> `readDir(parentDir) + entries.any()` → `readProps(remotePath)`（单文件 PROPFIND），每类数据从 N 次目录读降为 1 次单文件查询。

<br />

### 8.5 同步失败时错误消息暴露内部异常

> **状态：✅ 已修复（2026-06-06）**
>
> `e.toString()` 替换为 `'同步异常，请检查网络或服务器配置'`（L124）；`'同步 ${type.displayName} 异常：$e'` 替换为 `'${type.displayName} 同步异常'`（L188）

<br />

### 8.6 `SyncResult.summary` 中显示中文硬编码

> **状态：✅ 已修复（2026-06-06）**
>
> 删除 `summary` getter（生产代码零调用，纯测试用）。测试改为直接断言 `.success`/`.uploadedCount`/`.downloadedCount`/`.error` 字段。

***

## 9. 测试覆盖分析

> **状态：❌ 未修复** — 测试覆盖无变化，仍仅覆盖 `WebDavConfigService` 和 `SyncResult`
>
> **注：** `SyncResult` 的 `summary` getter 已删除，对应测试改为字段级断言。核心同步引擎和 ViewModel 无测试的缺口依旧。
| ---------------------- | ---------------------------------------------------- | ---------------------- |
| `WebDavConfigService`  | ✅ `test/features/sync/webdav_sync_service_test.dart` | 配置 CRUD、连接测试、状态 signal |
| `SyncResult`           | ✅                                                    | 成功/失败/边界               |
| `WebDavSyncService`    | ❌                                                    | 无（测试只测了配置服务）           |
| `StorageSyncViewModel` | ❌                                                    | 无                      |
| `StorageSyncPage`      | ❌                                                    | 无                      |

**测试亮点**：

- 配置服务的测试较完整（6 个 group）
- mock 了 `FlutterSecureStorage` 平台通道
- 边界条件测试（空配置、无效 URL、长密码等）

**缺口**：

- 同步引擎（`syncAll`）零测试——核心同步逻辑无覆盖
- ViewModel 零测试
- Widget 零测试

***

## 10. 优化清单

| 优先级    | 类别   | 项目                                                  | 状态    |
| ------ | ---- | --------------------------------------------------- | ----- |
| **P0** | 假实现  | 重置数据二次确认按钮改为实际调用清除 API                              | ✅ 已修复 |
| **P0** | 假实现  | 删除或实现 `noteCount` signal（当前已死代码）                    | ✅ 已修复 |
| **P0** | Bug  | `_showFinalConfirm` 确认按钮空函数                         | ✅ 已修复 |
| **P0** | 进度   | `syncProgress` signal 展示到 UI（进度条）                   | ❌ 未修复 |
| **P0** | i18n | 全部 UI 字符串迁移至 l10n（对话框已修，页面仍有 ~20 处）            | 🔶 部分修复 |
| **P1** | 架构   | 冲突检测（时间戳比对 + 冲突标记）                                  | ❌ 未修复 |
| **P1** | 架构   | 同步数据类型扩展到更多数据集                                      | ❌ 未修复 |
| **P1** | 架构   | 自动同步定时器实现                                           | 🗑️ 已删除 |
| **P1** | 架构   | `StorageSyncViewModel` 通过 DI 注入 `configService`     | ❌ 未修复 |
| **P1** | 错误   | 同步失败 `$e` 消息不暴露内部异常                                 | ✅ 已修复 |
| **P1** | 代码   | 危险操作弹窗提取共享组件（与 profile 重复）                          | ✅ 已修复 |
| **P1** | 代码   | `WebDavConfigService` 与 `WebDavSyncService` 连接测试合并  | ✅ 已修复 |
| **P1** | 测试   | `WebDavSyncService.syncAll` 单元测试                    | ❌ 未修复 |
| **P1** | 测试   | `StorageSyncViewModel` 单元测试                         | ❌ 未修复 |
| **P2** | 性能   | `_fileExists` 使用 `HEAD`/`PROPFIND` 替代 `readDir`    | ✅ 已修复 |
| **P2** | 性能   | `_dirSize` 内层异常继续而非全局跳出                             | ✅ 已修复 |
| **P2** | 安全   | 密码使用 `dart:ffi` 或 `Pointer.allocate` 擦除式管理        | ✅ 已修复 |
| **P2** | UX   | 存储可用空间 `totalAvailable` 从 `FileSystemStat` 获取       | ❌ 未修复 |
| **P2** | UX   | 状态 Header `GestureDetector` → `InkWell`             | ✅ 已修复 |

