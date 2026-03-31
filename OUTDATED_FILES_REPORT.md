# Zephyr Reader 项目过时文件报告

> **审查日期**: 2026 年 3 月 31 日  
> **审查目的**: 识别项目中过时、废弃、待清理的文件和代码

---

## 📋 概述

经审查，项目中**没有发现严重过时的文件**（如 `.bak`、`.old`、`_backup` 等后缀的备份文件）。但发现以下需要关注的文件和问题：

---

## 🔴 严重：空实现文件

### 1. `lib/features/bookshelf/data/bookshelf_service.dart`

| 属性 | 值 |
|------|-----|
| **状态** | ❌ 完全空实现 |
| **内容** | 仅 1 行注释 |
| **影响** | 书架模块服务层缺失 |
| **建议** | **立即实现或移除** |

**文件内容**:
```dart
// TODO Implement this library.
```

**处理建议**:
- **选项 A**: 实现该服务（推荐，如书架管理为核心功能）
- **选项 B**: 移除该文件，将逻辑整合到 `bookshelf_local_data_source.dart`
- **选项 C**: 标记为预留功能，添加说明文档

---

## 🟡 中等：生成代码文件

以下文件为代码生成工具自动生成，**不应手动修改**，但需确认是否为最新版本：

### Freezed 生成文件 (10 个)

| 文件路径 | 生成器 | 状态 |
|---------|--------|------|
| `lib/domain/models/book.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/bookmark.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/chapter.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/daily_reading_record.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/layout_cache.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/reading_history.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/reading_progress.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/reading_session.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/domain/models/reading_stats.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |
| `lib/src/rust/ffi/types.freezed.dart` | freezed | ⚠️ 包含 `deprecated_member_use` 忽略 |

**说明**: 这些文件包含 `deprecated_member_use` 忽略规则，表明使用了已废弃的 API，但为生成代码，不影响功能。

**处理建议**:
- 运行 `dart run build_runner build` 重新生成最新代码
- 升级 `freezed` 和 `freezed_annotation` 依赖版本

### Build Runner 生成文件 (5 个)

| 文件路径 | 生成器 | 用途 |
|---------|--------|------|
| `lib/core/database/database.g.dart` | drift | 数据库类型安全查询 |
| `lib/features/article/data/article_api.g.dart` | retrofit | API 接口实现 |
| `lib/features/article/domain/models/article.g.dart` | json_serializable | JSON 序列化 |
| `lib/features/auth/data/auth_api.g.dart` | retrofit | API 接口实现 |
| `lib/features/auth/domain/models/user.g.dart` | json_serializable | JSON 序列化 |

**处理建议**:
- 定期运行 `dart run build_runner build --delete-conflicting-outputs` 更新生成代码
- 检查生成器包版本是否需要升级

---

## 🟡 中等：命名潜在问题

### `lib/features/reader/page/reader_page_new.dart`

| 属性 | 值 |
|------|-----|
| **文件名** | 包含 `_new` 后缀 |
| **状态** | ✅ 正常使用中 |
| **风险** | 可能存在旧版 `reader_page.dart` 混淆 |
| **建议** | 重命名为 `reader_page.dart`（如无旧版） |

**说明**: 
- 当前项目中仅有 `reader_page_new.dart`，未发现 `reader_page.dart`
- `_new` 后缀可能是开发过程中的临时命名

**处理建议**:
1. 确认是否存在旧版 `reader_page.dart`（已删除）
2. 如无旧版，重命名为 `reader_page.dart`
3. 更新所有引用路径

---

## 🟢 轻微：Deprecated API 使用

### 1. Gradle 配置警告

**位置**: `android/app/build.gradle.kts`

**问题**: 使用 Gradle 8.14 已废弃的语法

```kotlin
// 废弃语法（当前）
android {
    namespace "com.example.zephyr_reader"
    minSdk 26
}

// 推荐语法（应改为）
android {
    namespace = "com.example.zephyr_reader"
    minSdk = 26
}
```

**影响**: Gradle 10.0 将移除此语法支持

**处理建议**: 在 `build.gradle.kts` 中添加 `=` 赋值符号

---

### 2. iOS 配置警告

**位置**: `ios/Runner.xcodeproj/project.pbxproj`

**问题**: `CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES`

**说明**: 这是 Xcode 项目配置，警告 Objective-C 实现中的废弃 API，属于正常配置。

**处理建议**: 无需处理，正常配置

---

## 📝 TODO 标记文件（非过时但需清理）

以下文件包含 TODO 标记，虽非过时但需关注：

| 优先级 | 文件路径 | TODO 数量 | 主要内容 |
|--------|---------|----------|---------|
| **P0** | `lib/features/bookshelf/data/bookshelf_service.dart` | 1 | 整个文件未实现 |
| **P1** | `lib/features/profile/page/app_settings_page.dart` | 5 | 清理缓存、备份恢复等 |
| **P1** | `lib/features/profile/page/about_page.dart` | 3 | 用户协议、隐私政策等 |
| **P2** | `lib/features/sync/application/services/advanced_webdav_sync_service.dart` | 2 | WiFi/充电状态检查 |
| **P2** | `lib/features/reader/application/services/custom_font_service.dart` | 1 | HTTP 下载字体 |
| **P2** | `lib/features/home/page/splash_page.dart` | 1 | 登录状态检查 |
| **P2** | `test/features/bookshelf_test.dart` | 3 | 测试占位符 |
| **P2** | `android/app/build.gradle.kts` | 1 | 生产签名配置 |

---

## 🗑️ 构建产物（可安全删除）

以下文件为构建过程生成，可安全删除，需要时会重新生成：

| 文件路径 | 类型 | 大小估算 | 建议 |
|---------|------|---------|------|
| `android/build/reports/problems/problems-report.html` | Gradle 报告 | ~50KB | 可删除 |
| `**/*.g.dart` | 生成代码 | - | 不应手动删除，运行 build_runner 更新 |
| `**/*.freezed.dart` | 生成代码 | - | 不应手动删除，运行 build_runner 更新 |

---

## ✅ 无过时文件确认

以下常见过时文件类型**未发现**：

| 文件类型 | 检查结果 |
|---------|---------|
| `*.bak` 备份文件 | ✅ 无 |
| `*.backup` 备份文件 | ✅ 无 |
| `*.old` 旧版本文件 | ✅ 无 |
| `*.tmp` 临时文件 | ✅ 无 |
| `*.temp` 临时文件 | ✅ 无 |
| `_backup/*` 备份目录 | ✅ 无（仅代码中的备份功能） |
| `old_*` 旧版本文件 | ✅ 无 |
| `*_v1`, `*_v2` 版本文件 | ✅ 无 |

---

## 📊 清理优先级

| 优先级 | 操作 | 预计工时 | 风险 |
|--------|------|---------|------|
| **P0** | 实现/移除 `bookshelf_service.dart` | 4h | 低 |
| **P1** | 重命名 `reader_page_new.dart` | 0.5h | 中（需更新引用） |
| **P1** | 修复 Gradle 废弃语法 | 0.5h | 低 |
| **P2** | 重新生成 freezed 代码 | 0.5h | 低 |
| **P2** | 清理 TODO 标记 | 8h | 低 |
| **P3** | 删除构建报告 | 0.1h | 无 |

---

## 🚀 建议行动

### 立即执行（本周）

```bash
# 1. 重新生成代码（确保最新）
dart run build_runner build --delete-conflicting-outputs

# 2. 检查 Gradle 配置
# 编辑 android/app/build.gradle.kts，添加 = 符号
```

### 短期执行（本月）

1. **处理 `bookshelf_service.dart`**
   - 实现功能或移除文件
   
2. **重命名阅读器页面**
   ```bash
   # 重命名文件
   git mv lib/features/reader/page/reader_page_new.dart lib/features/reader/page/reader_page.dart
   
   # 更新所有引用（IDE 会自动完成）
   ```

3. **清理 TODO 标记**
   - 优先完成 P1 级别 TODO

### 长期执行（下季度）

1. 升级依赖包版本（freezed, drift, retrofit 等）
2. 定期检查 `flutter pub outdated`
3. 建立代码审查机制，防止新的过时文件产生

---

## 📈 监控建议

### Git 钩子（防止备份文件提交）

`.git/hooks/pre-commit`:
```bash
#!/bin/bash

# 检查备份文件
if git diff --cached --name-only | grep -E '\.(bak|backup|old|tmp)$'; then
    echo "Error: Backup files should not be committed!"
    exit 1
fi
```

### .gitignore 检查

确认以下规则存在于 `.gitignore`:
```gitignore
# 备份文件
*.bak
*.backup
*.old
*.tmp
*.temp

# 生成代码（如项目策略允许提交则注释）
# *.g.dart
# *.freezed.dart

# 构建产物
build/
**/build/
```

---

## 📌 总结

| 类别 | 数量 | 状态 |
|------|------|------|
| **严重过时文件** | 1 | ❌ 需立即处理 |
| **生成代码文件** | 15 | ⚠️ 需定期更新 |
| **命名潜在问题** | 1 | ⚠️ 建议重命名 |
| **Deprecated API** | 2 | ⚠️ 建议修复 |
| **TODO 标记** | 17 | ⚠️ 需清理 |
| **构建产物** | 1 | ✅ 可安全删除 |

**整体评价**: 项目文件管理良好，无大量过时文件堆积。主要问题为 1 个空实现文件需优先处理。

---

**报告生成时间**: 2026 年 3 月 31 日  
**下次审查计划**: 2026 年 4 月 30 日
