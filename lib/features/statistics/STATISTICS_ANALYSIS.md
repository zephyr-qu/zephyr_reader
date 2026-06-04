# Statistics Feature 深度分析报告

> 分析基准：`lib/features/statistics/`
> 最后更新：2026-06-04（全部已修复）

***

## 1. 架构总览

```
statistics/
├── application/
│   ├── reading_stats_view_model.dart      ← 统计 VM
│   └── reading_sessions_view_model.dart   ← 阅读会话 VM
├── page/
│   ├── statistics_page.dart               ← 全局统计页
│   ├── reading_sessions_page.dart         ← 阅读会话记录页
│   └── widgets/
│       ├── today_reading_card.dart
│       ├── streak_card.dart
│       ├── reading_trend_chart.dart
│       ├── weekly_heatmap.dart
│       ├── vocab_stats_section.dart
│       └── vocab_stat_bar.dart
```

***

## 2. 已修复问题清单

### 2.1 测试文件引用不存在的文件（已修复）
❌ ~~`test/features/statistics/reading_stats_service_test.dart` 引用不存在的 `reading_stats_service.dart`。~~
✅ 重写为 `ReadingStatsViewModel` 初始状态与时段切换测试（9 tests）。

### 2.2 `bookCache` 空导致"未知书籍"（已修复）
❌ ~~`session_api.listSessionsByBook(bookId: '', limit: 1)`~~ ~~的错误传参导致缓存接近为空。~~
✅ 改为先加载会话，提取涉及的 bookId，再按 ID 逐本获取。

### 2.3 生词统计 4 次 API 调用获取计数（已修复）
❌ ~~4 次 `listVocabularyByStatus` 调用。~~
✅ 新增 Rust 聚合 API `getVocabularyStats()`，一次调用返回所有计数。

### 2.4 `loadDashboard()` 错误态不触发（已修复）
❌ ~~`loadDashboard()` 错误时不设 `dashboardError`。~~
✅ `loadDashboard()` 已删除（死代码）。

### 2.5 国际化硬编码中文（已修复）
❌ ~~~50 处用户可见字符串全部硬编码。~~
✅ 7 个 Dart 文件全部迁移至 `AppLocalizations`，新增 ~30 个 ARB key（en/zh）。

### 2.6 `loadData()` 调用冗余查询（已修复）
❌ ~~每次加载都重新调 `getGlobalReadingStats()` 和 `getReadingStatsByDaysWithFill()`。~~
✅ `getGlobalReadingStats()` 仅在首次加载时查询，时段切换不再重复请求。

***

## 3. 测试覆盖

| 组件 | 单元测试 | 可运行？ |
|------|---------|---------|
| `ReadingStatsViewModel` | `reading_stats_service_test.dart` | ✅ 9 tests |
| `ReadingSessionsViewModel` | `reading_sessions_view_model_test.dart` | ✅ 8 tests |
| `StatisticsPage` | ❌ | — |
| `ReadingSessionsPage` | ❌ | — |

***

## 4. 优化清单（全部已关闭）

| 优先级 | 类别 | 项目 | 状态 |
|--------|------|------|:----:|
| **P0** | Bug | ~~`bookCache` 传参错误导致"未知书籍"~~ | ✅ 2.2 |
| **P0** | Bug | ~~`loadDashboard()` 不设 `dashboardError`~~ | ✅ 死代码已删 |
| **P0** | Bug | ~~测试文件引用不存在文件，无法编译~~ | ✅ 已重写 |
| **P0** | 性能 | ~~生词统计改为 Rust 聚合计数 API~~ | ✅ 2.3 |
| **P0** | i18n | ~~全部 ~50 处硬编码迁移至 l10n~~ | ✅ 2.5 |
| **P1** | 架构 | ~~`@LazySingleton` 状态污染~~ | ✅ 改 `useMemoized` |
| **P1** | 架构 | ~~构造函数移出 `load()`~~ | ✅ |
| **P1** | 架构 | ~~`bookCache` 改为按需懒加载~~ | ✅ 2.2 |
| **P1** | 代码 | ~~两处 4 次生词计数查询提取公共方法~~ | ✅ Rust 聚合 API |
| **P1** | 代码 | ~~时间格式化函数提取共享工具~~ | ✅ `format_utils.dart` |
| **P1** | 代码 | ~~`loadData()` 冗余查询~~ | ✅ 2.6 |
| **P1** | 测试 | ~~修复测试文件引用路径~~ | ✅ |
| **P1** | 测试 | ~~添加 ViewModel 单元测试~~ | ✅ 共 17 tests |
| **P2** | UX | ~~每日阅读目标改为用户可配置~~ | ✅ `goalMinutes` signal |
| **P2** | UX | ~~`GestureDetector` 改为 `InkWell`（2 处）~~ | ✅ |
| **P2** | 代码 | ~~热力图改用整数比较替代字符串匹配~~ | ✅ `dt.weekday` |
