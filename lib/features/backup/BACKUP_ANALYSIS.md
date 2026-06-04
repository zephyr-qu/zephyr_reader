# Backup Feature 深度分析报告

> 分析基准：`lib/features/backup/` 及 `rust/src/api/backup.rs`
> 检测日期：2026-06-03

---

## 目录

1. [架构总览](#1-架构总览)
2. [P0 级 Bug — 双文件选择器导致恢复流程断裂](#2-p0-级-bug--双文件选择器导致恢复流程断裂)
3. [国际化（i18n）问题](#3-国际化i18n问题)
4. [ViewModel 设计缺陷](#4-viewmodel-设计缺陷)
5. [UI/UX 问题](#5-uiux-问题)
6. [代码层统一建议](#6-代码层统一建议)
7. [潜在问题](#7-潜在问题)
8. [测试覆盖缺口](#8-测试覆盖缺口)
9. [Rust 侧点评](#9-rust-侧点评)
10. [优化清单](#10-优化清单)

---

## 1. 架构总览

```
backup/
├── application/
│   └── backup_view_model.dart    ← Signal 驱动的 ViewModel
├── page/
│   ├── backup_page.dart          ← 主页面（HookWidget）
│   └── widgets/
│       ├── backup_action_tile.dart   ← 操作按钮（备份/还原）
│       ├── backup_status_card.dart   ← 状态卡片（渐变背景）
│       └── restore_confirm_dialog.dart ← 还原确认弹窗
```

**Rust FFI 契约** (`rust/src/api/backup.rs`)：
- `get_backup_stats()` → `BackupStats`
- `export_database(dest_path)` → `BackupManifest`
- `inspect_backup(path)` → `Option<BackupManifest>`
- `restore_database(backup_path)` → `BackupManifest`
- `cleanup_auto_snapshots(older_than_unix)` → `i64`

**数据流**：Page → ViewModel → FFI → Rust (sqlx + SQLite)

**优点**：
- 清晰的 Signal 响应式状态管理
- Rust 侧备份/还原有完善的快照保护、版本兼容性检查
- manifest 嵌入 db 自身，方便文件自由传输

**问题**：详见下文。

---

## 2. P0 级 Bug — 双文件选择器导致恢复流程断裂

### 症状

用户点击「从备份还原」后，**会被系统文件选择器连续弹两次**，选择同一个文件。

### 根因

`backup_page.dart:95-107`:
```dart
Future<void> _performRestore(BuildContext context, BackupViewModel vm) async {
  final filePath = await _pickBackupFile();         // ← 第一次 pick
  if (filePath == null) return;
  final manifest = await inspectBackup(backupPath: filePath);  // inspect
  // ... 确认对话框
  await vm.performRestore();                         // ← 不传 filePath
}
```

`backup_view_model.dart:108-126`:
```dart
Future<void> performRestore() async {
  // ...
  final result = await FilePicker.pickFiles(         // ← 第二次 pick！
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['db'],
      allowMultiple: false,
  );
  // ... 再次 inspect ...
}
```

**`performRestore()` 不接受文件路径参数**，只能自己重新 pick。结果：页面 pick → inspect → dialog → VM 再 pick → 再 inspect → 真正恢复。用户无端多操作一遍。

### 修复方向

`performRestore()` 应接受 `String filePath` 参数，从 page 传入，VM 不再自行 pick 和 inspect。相应地，`_prefs` 中的 `last_backup_at`/`last_backup_size` 也应从页面的 manifest 传下去，或合并 restore 逻辑到 VM 单入口。

### 连带影响

- `file_picker` 在 page 和 VM 两端都 import，冗余
- `inspectBackup` 被 page 和 VM 各调一次，冗余 IO + 无意义延迟

---

## 3. 国际化（i18n）问题

本地化极不完整。项目已有 `AppLocalizations` 体系且 `l10n` 在多数页面已注入，但 backup 模块大量硬编码中文。

| 文件 | 硬编码字符串 |
|------|------------|
| `backup_page.dart:47` | `'从未备份'`、`'天前备份 — 建议立即备份'` |
| `backup_page.dart:56` | `'从备份还原'` |
| `backup_page.dart:82` | `SnackBar(content: Text('备份成功'))` |
| `backup_page.dart:87` | `'备份失败：${...}'` |
| `backup_page.dart:103` | `'所选文件不是有效的备份文件'` |
| `backup_page.dart:122-123` | `'恢复成功'`、`'数据已还原，请重启应用以生效。'` |
| `backup_page.dart:166` | `'当前数据统计'` |
| `backup_status_card.dart:22-40` | `'备份中…'`、`'恢复中…'`、`'操作失败：'`、`'上次备份：'`、`'尚未进行过备份'` |
| `backup_status_card.dart:81-82` | `'本书 · '`、`'条笔记'` |
| `backup_status_card.dart:96-102` | `'刚刚'`、`'分钟前'`、`'小时前'`、`'天前'`、`'个月前'` |
| `restore_confirm_dialog.dart:21` | `'确认还原'` |
| `restore_confirm_dialog.dart:29` | `'此操作将覆盖当前所有数据...'` |
| `restore_confirm_dialog.dart:42-53` | `'备份版本'`、`'导出时间'`、`'书籍'`、`'笔记'`、`'书签'`、`'生词'` |
| `restore_confirm_dialog.dart:67` | `'确认还原'` |
| `backup_view_model.dart:128` | `'无法读取选择的文件路径'` |
| `backup_view_model.dart:136` | `'所选文件不是有效的 Zephyr Reader 备份文件'` |

**所有以上字符串都应迁移至 `AppLocalizations`**。`l10n` 已在 page 和 dialog 中可用；VM 中的错误消息可通过外部传入或从 AppError 直接映射。

---

## 4. ViewModel 设计缺陷

### 4.1 `performRestore()` 不接受参数（与 §2 关联）

VM 不应自行触发 UI 相关的文件选择。`performRestore(String filePath)` 才是正确的接口。

### 4.2 `lastBackupTimeAgo()` — 死代码

```dart
String? lastBackupTimeAgo(AppLocalizations l10n) { ... }
```

从未被任何 UI 调用。Page 有自己的 `_backupSubtitle()` 做了同样的计算。两者逻辑不一致（一个返回英文如 `5h ago`，一个返回中文）。应删除 VM 版本或统一为一个工具函数。

### 4.3 `lastManifest` signal 未被 UI 消费

```dart
final lastManifest = signal<BackupManifest?>(null);
```

在 `performBackup()` 和 `performRestore()` 中被写入，但没有任何 Widget 读它。要么删除，要么在 UI 中展示（例如显示版本号、导出时间等）。

### 4.4 `_refreshStats()` 静默吞噬所有异常

```dart
Future<void> _refreshStats() async {
  try {
    currentStats.value = await getBackupStats();
  } catch (e) {
    // 静默失败，stats 为 null 时 UI 降级显示
  }
}
```

降级显示是可接受的设计，但没有任何日志输出。当 `getBackupStats()` 失败时无从排查。应当 `tracing.warning` 或至少 `debugPrint`。

### 4.5 `dismissResult()` resets `lastManifest`

```dart
Future<void> dismissResult() async {
  status.value = BackupStatus.idle;
  lastManifest.value = null;
  errorMessage.value = null;
  await _refreshStats();
}
```

清空了 `lastManifest`，但 manifest 中可能包含备份时间/大小等有用信息。如需要展示最近一次备份详情，不应在此处清除。

### 4.6 `factory` 生命周期

```dart
gh.factory<_BackupViewModel>(() => _BackupViewModel(gh<SharedPreferences>()));
```

`factory` 每次注入都新建实例。虽由 `useMemoized` 缓存页面生命周期内，但一旦页面 GC、回退重进，状态丢失。Signal 状态（`lastBackupAt`、`lastBackupSize`）通过 `SharedPreferences` 持久化，但 `status`/`currentStats` 丢失。可考虑 `@lazySingleton` 或至少 `@preResolve`。

---

## 5. UI/UX 问题

### 5.1 硬编码颜色，破坏主题一致性

| 文件 | 行 | 硬编码值 | 应使用 |
|------|---|---------|--------|
| `backup_action_tile.dart:44-45` | `Color(0xFFE3F2FD)` / `Color(0xFF1976D2)` | Material 2 Blue — 应改用 `cs.primaryContainer` / `cs.onPrimaryContainer` |
| `backup_action_tile.dart:53-54` | `Color(0xFFFFF3E0)` / `Color(0xFFE65100)` | Material 2 Orange — 应改用 `cs.secondaryContainer` / `cs.onSecondaryContainer` |
| `backup_status_card.dart:21` | `Colors.blue` | 应使用 `cs.primary` 或主题色 |
| `backup_status_card.dart:26` | `Colors.orange` | 同上 |
| `backup_status_card.dart:31` | `Colors.red` | `cs.error` |
| `backup_status_card.dart:38` | `Colors.green` | `cs.tertiary` 或其他主题色 |
| `restore_confirm_dialog.dart:65` | `Colors.red.shade700` | `cs.error` |

### 5.2 无障碍（Semantics）缺失

所有交互元素（InkWell、IconButton 等）均缺少 `Semantics`/`semanticLabel`。屏幕阅读器用户无法获取有意义的描述。

### 5.3 操作中无进度指示

`BackupStatus.exporting` 和 `BackupStatus.restoring` 只显示一行文本。当备份大数据库（>100MB）时，用户无法感知操作进度。考虑 `LinearProgressIndicator` 或 `CircularProgressIndicator`。

### 5.4 成功/失败反馈不统一

- 备份成功：SnackBar（自动消失）
- 恢复成功：Dialog（modal，需手动关闭）
- 失败：SnackBar

反馈模式不一致。建议统一使用 SnackBar（非破坏性）或 Dialog（破坏性操作），避免用户困惑。

### 5.5 宽屏/平板布局未适配

`ListView` 单列布局在大屏上会极宽。可考虑居中约束或 `Sliver` 自适应布局。

---

## 6. 代码层统一建议

### 6.1 「时间差计算」重复 3 份

| 位置 | 函数/方法 |
|------|----------|
| `backup_page.dart:66-74` | `_backupSubtitle()` |
| `backup_view_model.dart:166-174` | `lastBackupTimeAgo()` |
| `backup_status_card.dart:96-103` | `_formatAgo()` |

三份实现逻辑各自不同：
- `_backupSubtitle`：混合建议文案、中文、分段
- `lastBackupTimeAgo`：返回英文 `5h ago` 格式
- `_formatAgo`：纯中文，支持月级

应统一为一个 `HumanReadableDuration` 工具类，支持 locale 参数。

### 6.2 文件选择逻辑重复

`_pickBackupFile()` 在 page 中定义，VM 中 `performRestore()` 又写了一份几乎一样的。应合并到 VM 或一个独立的 repository/service。

### 6.3 `RestoreConfirmDialog` 硬编码中文行

```dart
_statRow(ctx, '备份版本', manifest.appVersion),
_statRow(ctx, '导出时间', ...),
_statRow(ctx, '书籍', ...),
```

应通过映射表或 `l10n` 动态生成 label。

### 6.4 备份文件名生成在 VM

```dart
final suggestedName = 'zephyr-backup-${now.year}...'
```

应在 Rust 侧或共享常量定义。硬编码在 Dart 侧跨平台有风险。

### 6.5 错误消息来源不统一

- VM 内：手动写中文 error message
- Rust 侧：`AppError` 携带英文消息
- 部分错误 (`e.toString()`) 直接展示给用户

应建立统一的错误映射层（`AppError` → 用户可读消息）。

---

## 7. 潜在问题

### 7.1 WAL checkpoint 大文件阻塞

```rust
sqlx::query("PRAGMA wal_checkpoint(TRUNCATE)")
```

完整 checkpoint 会回放 WAL 到主文件，对大型 db（>500MB）可能耗时数秒。如果在 UI 线程感知的 async 范围内执行，会产生可见卡顿。建议增加 checkpoint 超时或分步 checkpoint。

### 7.2 快照清理不完整

`cleanup_auto_snapshots` 只清理 `auto_snapshot_<ts>.db` 文件，但 restore 失败时这些快照不会被用户发现。应在 UI 中提供「查看快照」入口。

### 7.3 无备份加密

备份是明文 `.db` 文件，包含所有书籍内容、笔记、生词。无对称加密。如果用户通过云盘传输，数据暴露风险。

### 7.4 `inspectBackup` 无 WAL 处理

`open_readonly_pool` 以只读方式打开备份文件。但如果备份文件正处于 WAL 模式且未 checkpoint，只读打开可能看不到最新数据。当 `_backup_meta` 表尚在 WAL 中时，`read_manifest_from_pool` 可能返回 None。

### 7.5 `context.mounted` 竞争

`_performBackup` / `_performRestore` 多次检查 `context.mounted`，但其间有 `await`。如果页面在 await 期间被 dispose，后续 ScaffoldMessenger/Dialog 调用会抛出异常。检查链基本正确，但 `_performBackup` 行 78 检查后，79-83 没有再次检查。极端条件下可能 crash：

```dart
if (!context.mounted) return;     // 行 78
if (vm.status.value == BackupStatus.exportingDone) {
  ScaffoldMessenger.of(context)    // 如果 78-79 之间 unmount，抛异常
```

### 7.6 `stats_json` 使用 `serde_json` 序列化

```rust
let stats: BackupStats = serde_json::from_str(&stats_json)...
```

JSON 序列化/反序列化 stats 到 `_backup_meta` 表。如果 struct 字段增减但没有 migration，旧备份可能反序列化失败。应添加向后兼容（`#[serde(default)]`）。

---

## 8. 测试覆盖缺口

| 层面 | 文件 | 状态 |
|------|------|------|
| Rust 单元测试 | `rust/src/api/backup.rs` | ✅ 有 `manifest_roundtrip_json` 等 |
| Dart 单元测试 — ViewModel | — | ❌ 完全缺失 |
| Dart Widget 测试 | — | ❌ 完全缺失 |
| Dart 集成测试 | — | ❌ 完全缺失 |

需要添加的测试：

1. **ViewModel 单元测试**
   - `performBackup()` 状态机转换：idle → exporting → exportingDone → idle
   - `performRestore()` 状态机转换（mock FilePicker）
   - `dismissResult()` 重置状态
   - `_refreshStats()` 异常处理
   - `isBackupStale` 边界条件（刚好 7 天、刚过 7 天）

2. **Widget 测试**
   - `BackupActionTile`：tap 回调
   - `BackupStatusCard`：不同状态渲染
   - `RestoreConfirmDialog`：确认/取消
   - `BackupPage`：完整渲染快照

3. **集成/端到端测试**
   - 备份 → 验证文件存在
   - 还原 → 验证数据恢复

---

## 9. Rust 侧点评

### 优点

- `BackupManifest` 用 `#[serde(default)]` （实际查看了代码，没有标记——应加上）
- 严格路径校验 (`validate_file_path_async`)
- 自动快照保护机制
- semver 兼容性检查拒绝高版本备份降级还原
- WAL checkpoint + meta 表管理完整

### 建议

1. 增加 `#[serde(default)]` 到 `BackupStats` 和 `BackupManifest` 以向前兼容
2. `cleanup_auto_snapshots` 用 `walkdir` 或 glob 替代手动 `read_dir`
3. 增加 AES-GCM 加密选项（可选，非 blocking）
4. `export_database` 中 `std::fs::copy` 后缺少 `fsync`/`flush` 保证，极端掉电场景可能写出损坏文件。考虑 `File::sync_all()`

---

## 10. 优化清单

按优先级（P0=修复/阻塞, P1=重要, P2=建议）排列：

| 优先级 | 类别 | 项目 |
|--------|------|------|
| **P0** | Bug | `performRestore()` 不接受 filePath，导致双文件选择器 |
| **P1** | 国际化 | 全部 5 个文件中的 30+ 处硬编码中文迁移至 l10n |
| **P1** | ViewModel | 删除死代码 `lastBackupTimeAgo()` |
| **P1** | ViewModel | 删除或消费 `lastManifest` signal |
| **P1** | 主题 | `BackupActionTile` 硬编码 Material 2 颜色改用 ColorScheme |
| **P1** | 主题 | `BackupStatusCard` 硬编码颜色改用 ColorScheme |
| **P1** | 主题 | `RestoreConfirmDialog` `Colors.red.shade700` 改用 `cs.error` |
| **P1** | 冗余 | `inspectBackup` 在 page 和 VM 各调一次 → 合并在 page |
| **P1** | 测试 | 添加 ViewModel 单元测试（状态机） |
| **P1** | 测试 | 添加 Widget 测试 |
| **P1** | 日志 | `_refreshStats()` catch 块加日志 |
| **P2** | UX | 操作中增加 LinearProgressIndicator |
| **P2** | UX | 统一成功/失败反馈模式（SnackBar vs Dialog） |
| **P2** | UX | 宽屏自适应布局 |
| **P2** | 语义 | 添加 Semantics 标签 |
| **P2** | 代码 | 三份「时间差计算」统一为一个工具函数 |
| **P2** | 代码 | 文件选择逻辑合并（page + VM 重复） |
| **P2** | 代码 | 错误消息映射层（AppError → 用户可读） |
| **P2** | Rust | `BackupStats`/`BackupManifest` 加 `#[serde(default)]` |
| **P2** | Rust | `std::fs::copy` 后加 `sync_all()` |
| **P2** | 安全 | 可选备份加密 |
| **P2** | 生命周期 | VM 生命周期管理（factory → lazySingleton 或保留状态） |
