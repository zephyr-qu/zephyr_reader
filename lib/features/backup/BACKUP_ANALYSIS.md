# Backup Feature 分析报告 — 剩余项

> 分析基准：`lib/features/backup/` 及 `rust/src/api/backup.rs`
> 检测日期：2026-06-03
> 最后更新：2026-06-05（剔除假问题/已修复项）

---

## 目录

1. [架构总览](#1-架构总览)
2. [未修复问题](#2-未修复问题)
3. [测试覆盖缺口](#3-测试覆盖缺口)
4. [已决策跳过](#4-已决策跳过)

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

---

## 2. 未修复问题

### 2.1 无障碍（Semantics）缺失

所有交互元素（InkWell、IconButton 等）均缺少 `Semantics`/`semanticLabel`。屏幕阅读器用户无法获取有意义的描述。

### 2.2 无备份加密

备份是明文 `.db` 文件，包含所有书籍内容、笔记、生词。无对称加密。如果用户通过云盘传输，数据暴露风险。

---

## 3. 测试覆盖缺口

| 层面 | 文件 | 状态 |
|------|------|------|
| Rust 单元测试 | `rust/src/api/backup.rs` | ✅ 有 `manifest_roundtrip_json` 等 |
| Dart 单元测试 — ViewModel | `test/features/backup/backup_view_model_test.dart` | ✅ 10 项测试 |
| Dart Widget 测试 | `test/features/backup/backup_widgets_test.dart` | ✅ 7 项测试 |
| Dart 集成测试 | — | ❌ 缺失 |

---

## 4. 已决策跳过

- **操作中增加 LinearProgressIndicator** — 备份操作用户等待几秒可接受，不增加进度条。
