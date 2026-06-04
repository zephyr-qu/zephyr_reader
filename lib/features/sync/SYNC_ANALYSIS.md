# Sync Feature 深度分析报告

> 分析基准：`lib/features/sync/` — 6 个文件
> 检测日期：2026-06-03

---

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

---

## 2. P0 级问题

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

```dart
// webdav_sync_service.dart:112-114
} else {
  result.error = opResult.$2;  // 记录错误但不 break
}

// line 121:
result.success = result.error == null;
```

如果 3 种数据类型（progress/bookmarks/bookshelf）中的 2 种成功、1 种失败，`result.success` 为 false，但 `uploadedCount`/`downloadedCount` 已经累加。**调用方无法得知哪些成功了哪些失败了**——只看到「同步失败」但部分数据实际已上传/下载。

### 2.3 重置数据二次确认弹窗中的确认按钮是假实现

```dart
// storage_sync_page.dart:493-498
FilledButton(
  onPressed: () {
    Navigator.pop(ctx);
    // ← 没有调用任何清除 API！
  },
  child: const Text('确认重置'),
)
```

「二次确认」对话框的「确认重置」按钮只关闭对话框，**不执行任何实际数据清除操作**。这个危险操作的按钮是一个空函数。用户点了确认、输入了 RESET、点了确认——数据毫发无损。

### 2.4 所有 UI 字符串硬编码中文

`storage_sync_page.dart` 几乎全部用户可见字符串硬编码：

| 位置 | 字符串 |
|------|--------|
| `storage_sync_page.dart:33` | `'存储与同步'` |
| `storage_sync_page.dart:45` | `'刷新'` |
| `storage_sync_page.dart:87-93` | `'正在同步…'`、`'未配置同步'`、`'尚未同步'`、`'数据已同步'` |
| `storage_sync_page.dart:172` | `'立即同步'` / `'去配置'` |
| `storage_sync_page.dart:222` | `'本地存储'` |
| `storage_sync_page.dart:266-278` | `'书籍'`、`'数据库'`、`'缓存'` |
| `storage_sync_page.dart:322` | `'同步配置'` |
| `storage_sync_page.dart:334-337` | `'WebDAV 服务器'`、`'未配置'` |
| `storage_sync_page.dart:459,462,466,474,486-487,498-499` | 弹窗全部文本 |
| `storage_sync_page.dart:514,519` | SnackBar 消息 |
| `webdav_config_dialog.dart:32` | `'配置 WebDAV'` |

---

## 3. 国际化（i18n）问题

**整个 sync 模块未使用 `AppLocalizations`**。虽然 `storage_sync_page.dart` 导入了 `l10n/app_localizations.dart` 并声明了 `final l10n = AppLocalizations.of(context)!;`，但实际代码中**只使用了 `l10n.lastSyncTime()` 这一个本地化方法**（行 143）。其余所有用户可见字符串硬编码中文。

---

## 4. ViewModel 设计缺陷

### 4.1 `StorageSyncViewModel` 直接实例化 `WebDavConfigService`

```dart
final configService = WebDavConfigService(prefs: getIt<SharedPreferences>());
```

VM 没有通过 DI 注入 `configService`，而是直接 `new` 实例。这使得单元测试中难以 mock 配置服务。

### 4.2 `initialize()` 串行等待所有任务

```dart
await _calcStorage();   // 遍历文件系统
await _loadNoteCount(); // 调 Rust API
```

`_calcStorage()` 递归遍历整个应用文档目录，可能耗时较长。与 `_loadNoteCount()` 没有并行（虽然 `_loadNoteCount` 在 `_calcStorage` 前无法计算 `totalAvailable`，但可以并行）。

### 4.3 `_dirSize` 遍历不计异常

```dart
Future<int> _dirSize(Directory dir) async {
  int total = 0;
  try {
    await for (final entity in dir.list(...)) {
      if (entity is File) total += await entity.length();
    }
  } catch (e) {
    Logging.error('计算缓存大小失败', exception: e);
  }
  return total;
}
```

如果目录中的单个文件在 `await entity.length()` 时抛出异常（如权限错误、文件被占用），整个遍历跳出，返回 `total`（可能为 0 或不完整）。应 `try-catch` 内层。

### 4.4 `_loadNoteCount` 静默吞异常

```dart
catch (_) {
  noteCount.value = 0;
}
```

`noteCount` 无 UI 消费——该 signal 从未在 UI 中使用。属于死代码（或未来预留）。

### 4.5 `StorageSyncViewModel` 无 `dispose` 方法

虽然是 `factory`（页面每次重建），但 `WebDavConfigService` 持有的 `FlutterSecureStorage` 访问不需要 dispose。

---

## 5. UI/UX 问题

### 5.1 状态 Header 固定深蓝色渐变

```dart
gradient: const LinearGradient(
  colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
```

固定深蓝色渐变。暗色模式下可能与深色主题融合，对比度下降。文字全白色。

### 5.2 存储百分比条使用 `Expanded` flex 近似

```dart
flex: (booksPct * 100).round().clamp(1, 100),
```

通过 `flex` 模拟百分比条，但 `flex` 是整数。对于小比例值（如 0.3%），`(0.003 * 100).round()` = 0，被 `clamp` 到 1，导致微小的数据段占用至少 1/102 的空间。

### 5.3 无自动同步定时器

UI 和配置中都有 `autoSyncEnabled` / `autoSyncInterval` 信号，但**从未实际实现自动同步**。没有 `Timer.periodic` 调度。

```dart
final autoSyncEnabled = signal(false);
final autoSyncInterval = signal(30);  // 30 分钟
```

这两个信号仅存储和读取，无任何消费代码。

### 5.4 同步进度仅存储为 signal 但 UI 未消费

`WebDavSyncService.syncProgress` 在同步过程中更新，但 `StorageSyncPage` 和 `StorageSyncViewModel` 没有展示进度条。用户看不到同步进度。

### 5.5 Status Header 中 `GestureDetector` 无 ripple

```dart
GestureDetector(
  onTap: () { ... },
  child: Container(... borderRadius: BorderRadius.circular(20) ...)
)
```

「立即同步」/「去配置」按钮使用 `GestureDetector`。

---

## 6. 代码层统一建议

### 6.1 `_confirmReset` 弹窗与 profile `_confirmResetSettings` 高度重复

两个模块都有「确认重置」弹窗：`storage_sync_page.dart:446-479` 和 `other_settings_page.dart:529-558`。结构几乎相同（warning icon + 标题 + 描述 + 取消/确认按钮）。应提取为共享的 `ConfirmResetDialog`。

### 6.2 `WebDavConfigService` 与 `WebDavSyncService` 都在测试连接

`WebDavConfigService.testCurrentConfig()` 和 `WebDavSyncService._getConnectedClient()` 都做了 `client.ping()`。可合并为一处。

### 6.3 危险操作区域在 sync 和 profile 重复

`_buildDangerZone` 在 `storage_sync_page.dart:353-442` 和 `other_settings_page.dart:272-325` 几乎完全相同。应提取为共享组件。

### 6.4 `formatBytes` 与项目其他格式化

`formatBytes` 在 `storage_sync_view_model.dart:99-105` 中实现。项目其他地方可能有相同的格式化（待验证）。

---

## 7. 假实现 / stub 分析

| 类型 | 位置 | 说明 |
|------|------|------|
| **重置数据确认按钮** | `storage_sync_page.dart:495-497` | 二次确认弹窗的确认按钮只 `Navigator.pop`，不执行任何清除 |
| **自动同步** | `WebDavConfigService` + `StorageSyncViewModel` | `autoSyncEnabled`/`autoSyncInterval` 存储了配置但不启动任何 Timer |
| **同步进度 signal** | `WebDavSyncService` | `syncProgress` 更新但 UI 未消费 |
| **`noteCount` signal** | `storage_sync_view_model.dart:78` | `_loadNoteCount()` 设置但 UI 从未读 `noteCount.value` |
| **`totalAvailable`** | `storage_sync_view_model.dart:28` | 始终为 0（未从 `FileSystemStat` 获取可用空间）。显示为 `'0B / —'` |

---

## 8. 潜在问题

### 8.1 同步数据类型仅有 3 项

```dart
enum SyncDataType {
  readingProgress('reading_progress.json', '阅读进度'),
  bookmarks('bookmarks.json', '书签'),
  bookshelf('bookshelf.json', '书架');
}
```

不包含：阅读设置、自定义词典配置、笔记CSV、生词表。用户期望的「全量备份」只有部分数据。

### 8.2 密码明文传入 `webdav.newClient`

```dart
_client = webdav.newClient(baseUrl, user: config.username, password: config.password, ...);
```

密码从 `FlutterSecureStorage` 解密后以 `String` 形式在内存中传递。虽比明文存储好，但 `String` 在 Dart 堆中不可擦除（直到 GC）。在破解者可以读取进程内存的场景下不安全。

### 8.3 `webdav_client` 包的 `mkdirAll` 可能抛异常

```dart
await _client!.mkdirAll(remoteDir, _cancelToken);
```

如果远程目录已存在，某些 WebDAV 服务器返回 405（Method Not Allowed）而非 200，导致 `_ensureRemoteDirectory` 返回 false。不同服务商兼容性可能有问题。

### 8.4 `_fileExists` 读整个目录

```dart
final entries = await _client!.readDir(parentDir);
return entries.any((entry) => entry.name == fileName);
```

`readDir` 获取远程目录的全部文件列表再内存过滤。如果远程目录中有大量文件，每个文件类型同步时都读一次完整列表（3 种数据类型 = 3 次）。应使用 `HEAD`/`PROPFIND` 直接检查单文件。

### 8.5 同步失败时错误消息暴露内部异常

```dart
return SyncResult(success: false, error: '同步 ${type.displayName} 异常：$e');
```

`$e.toString()` 直接暴露给用户（SnackBar）。可能包含凭证信息或服务器路径。

### 8.6 `SyncResult.summary` 中显示中文硬编码

```dart
return '同步失败：$error';
'上传 $uploadedCount 项'
'下载 $downloadedCount 项'
'sync complete, no changes needed'
```

中文混合英文。

---

## 9. 测试覆盖分析

| 组件 | 单元测试 | 覆盖内容 |
|------|---------|---------|
| `WebDavConfigService` | ✅ `test/features/sync/webdav_sync_service_test.dart` | 配置 CRUD、连接测试、状态 signal |
| `SyncResult` | ✅ | 成功/失败/边界 |
| `WebDavSyncService` | ❌ | 无（测试只测了配置服务） |
| `StorageSyncViewModel` | ❌ | 无 |
| `StorageSyncPage` | ❌ | 无 |

**测试亮点**：
- 配置服务的测试较完整（6 个 group）
- mock 了 `FlutterSecureStorage` 平台通道
- 边界条件测试（空配置、无效 URL、长密码等）

**缺口**：
- 同步引擎（`syncAll`）零测试——核心同步逻辑无覆盖
- ViewModel 零测试
- Widget 零测试

---

## 10. 优化清单

| 优先级 | 类别 | 项目 |
|--------|------|------|
| **P0** | 假实现 | 重置数据二次确认按钮改为实际调用清除 API |
| **P0** | 假实现 | 删除或实现 `noteCount` signal（当前已死代码） |
| **P0** | Bug | `_showFinalConfirm` 确认按钮空函数 |
| **P0** | 进度 | `syncProgress` signal 展示到 UI（进度条） |
| **P0** | i18n | 全部 UI 字符串迁移至 l10n（`storage_sync_page.dart` 已导入但未使用） |
| **P1** | 架构 | 冲突检测（时间戳比对 + 冲突标记） |
| **P1** | 架构 | 同步数据类型扩展到更多数据集 |
| **P1** | 架构 | 自动同步定时器实现 |
| **P1** | 架构 | `StorageSyncViewModel` 通过 DI 注入 `configService` |
| **P1** | 错误 | 同步失败 `$e` 消息不暴露内部异常 |
| **P1** | 代码 | 危险操作弹窗提取共享组件（与 profile 重复） |
| **P1** | 代码 | `WebDavConfigService` 与 `WebDavSyncService` 连接测试合并 |
| **P1** | 测试 | `WebDavSyncService.syncAll` 单元测试 |
| **P1** | 测试 | `StorageSyncViewModel` 单元测试 |
| **P2** | 性能 | `_fileExists` 使用 `HEAD` 替代 `readDir` 全量读取 |
| **P2** | 性能 | `_dirSize` 内层异常继续而非全局跳出 |
| **P2** | 安全 | 密码使用 `dart:ffi` 或 `Pointer.allocate` 擦除式管理 |
| **P2** | UX | 存储可用空间 `totalAvailable` 从 `FileSystemStat` 获取 |
| **P2** | UX | 状态 Header `GestureDetector` → `InkWell` |
