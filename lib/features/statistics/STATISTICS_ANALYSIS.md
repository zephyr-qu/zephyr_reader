# Statistics Feature 深度分析报告

> 分析基准：`lib/features/statistics/`
> 检测日期：2026-06-06

***

## 变更记录

| 日期         | 变更 |
| ---------- | ------------------------------------------------------------------------------------- |
| 2026-06-06 | 批量修复 P0/P1/P2 共 12 项问题（§3.3/3.5/4.1/4.2/4.3/4.4/4.5/5.2/5.3/5.4/5.5 + 编译修复） |
2026-06-06 | 提交 `7b9e665`：`VocabStatBar`/`StreakCard` 颜色硬编码修复确认（已标记 ✅ 但未提交到 git，现补提交） |
| 2026-06-06 | 二次验证：确认 3.1 已修复（useEffect 已调用 loadData）；新增 3 项发现（测试编译失败、dead code、lint）；其余 16 项问题均未解决 |
| 2026-06-05 | 全面重审：新增 P0 `loadData()` 首次不触发、错误态静默吞没等 17 项问题；修正对测试覆盖的分析；保留 2.1-2.6 历史已修复项            |

***

## 1. 架构总览

```
statistics/
├── application/
│   ├── reading_stats_view_model.dart         ← 统计 VM（已迁移 AsyncState）
│   └── reading_sessions_view_model.dart      ← 阅读会话 VM（已迁移 AsyncState）
├── page/
│   ├── statistics_page.dart                  ← 全局统计页
│   ├── reading_sessions_page.dart            ← 阅读会话记录页
│   └── widgets/
│       ├── today_reading_card.dart           ← 今日阅读卡片
│       ├── streak_card.dart                  ← 连续阅读卡片
│       ├── reading_trend_chart.dart          ← 折线趋势图
│       ├── weekly_heatmap.dart               ← 每周热力图
│       ├── vocab_stats_section.dart          ← 生词统计看板
│       └── vocab_stat_bar.dart               ← 单一生词柱
```

**页面组成**：

```
Tab 统计页（StatisticsPage）
 ├── AppBar + SegmentedButton 时段选择器（今日/周/月/年）
 ├── 顶部双卡片行：TodayReadingCard | StreakCard
 ├── 阅读趋势折线图（ReadingTrendChart）
 ├── 周热力图（WeeklyHeatmap）
 └── 生词统计（VocabStatsSection → 4×VocabStatBar）

Push 阅读会话页（ReadingSessionsPage）
 ├── AppBar + 刷新按钮
 ├── 总览卡片（总时长 + 总次数）
 ├── 按书籍分组的会话列表
 └── 每本书可删除所有会话
```

***

## 2. 遗留修复记录（保留）

以下为 2026-06-04 已修复问题，保留以供追溯：

| #   | 问题                         | 修复方式                                     |
| --- | -------------------------- | ---------------------------------------- |
| 2.1 | 测试文件引用不存在文件                | 重写为 ViewModel 初始态测试（9 tests）             |
| 2.2 | `bookCache` 传参空字符串导致"未知书籍" | 改为先加载会话再逐本获取                             |
| 2.3 | 生词统计 4 次 API 调用            | 新增 Rust 聚合 API `getVocabularyStats()`    |
| 2.4 | `loadDashboard()` 错误态不触发   | 死代码已删除                                   |
| 2.5 | ~50 处硬编码中文                | 全部迁移至 `AppLocalizations`，新增 ~30 ARB key |
| 2.6 | `loadData()` 每次切换都重复请求全局统计 | 仅在首次加载时查询                                |

***

## 3. P0 级问题

<br />

***

### 3.1 `StatisticsPage` 初始不调用 `loadData()` ✅ 已修复

初始 useEffect 依赖数组不含 `vm`/空数组，首次渲染不触发 `loadData()`。
修复后：`useEffect(() { vm.loadData(period: period); return null; }, [period]);`，首次及时段切换均正确触发。

***

### 3.2 `ReadingStatsViewModel` 错误态静默吞没 ✅ 已修复

已迁移至 `AsyncState` 模式：
- `globalStats` → `asyncSignal<GlobalStats?>(AsyncState.loading())`
- `dailyRecords` → `asyncSignal<List<ReadingStats>>(AsyncState.loading())`
- API 失败 → 设置 `AsyncState.error(e)`，UI 可通过 `.value` 访问或通过 `.hasError`/`.isLoading` 感知

***

### 3.3 `ReadingSessionsViewModel` 异常完全吞没 ✅ 已修复

**修复内容**：
- `catch (_)` → 带 `Logging.error()` 的完整异常记录
- 添加 `AsyncState` 信号 → 三态（loading/data/error）
- 异常时 UI 展示错误页 + 重试按钮
- 书籍缓存失败仅记日志，不影响会话展示
- `deleteSessionsByBook` 也增加 try/catch + 日志

**影响文件**：`reading_sessions_view_model.dart`, `reading_sessions_page.dart`

### 3.4 `formatDuration` / `formatChars` 硬编码中文 ✅ 已修复

**问题**：两个函数内部硬编码中文单位（"秒"、"分钟"、"小时"、"字"、"千字"），英文环境下仍然显示中文。

**修复**：函数签名改为 `formatDuration(int seconds, AppLocalizations l10n)` 和 `formatChars(int chars, AppLocalizations l10n)`，使用 l10n 键：

| 键 | en | zh |
| --- | --- | --- |
| `secondsUnit` | "sec" | "秒" |
| `hoursUnit` | "hr" | "小时" |
| `charsUnit` | " chars" | "字" |
| `thousandCharsUnit` | "K" | "千" |

**影响文件**：`format_utils.dart`、`reading_sessions_page.dart`、`reading_session_overview_card.dart`、`reading_session_book_group.dart`、`profile_page.dart`

***

### 3.5 `goalMin` 除零风险 ✅ 已修复

`goalMin == 0` 时 `todayMin / goalMin` 产生 `Infinity`/`NaN`。
修复：`goalMin > 0 ? (todayMin / goalMin).clamp(0.0, 1.0) : 0.0`

***

## 4. P1 级问题

### 4.1 热力图性能浪费 ✅ 已修复

`_getWeekMinutes` 原被调用 28 次（7 天 × 4 周），每次遍历全部 records 并执行 `DateTime.parse`。
365 条记录时迭代 **10,220 次**。

**修复**：替换为单次遍历构建 `4×7` / `N×7` 矩阵（`_buildGrid()`），一次 `DateTime.parse` 完成全部聚合。
同时修复原 bug：`weekOffset` 参数从未使用，所有 4 周显示相同数据。

***

### 4.2 `useEffect` `load()` 未 await ✅ 已修复

修复：`unawaited(vm.load())` — 显式标记 fire-and-forget 意图。`load()` 内部已有完整 try/catch，不会产生未处理 Future 异常。

***

### 4.3 热力图固定 4 周不感知时段选择 ✅ 已修复

**修复**：`WeeklyHeatmap` 新增 `period` 参数，按 `StatisticsPeriod` 动态计算天数/周数：
- 今日 → 1 周 × 7 天
- 周 → 1 周 × 7 天
- 月 → 4~5 周 × 7 天
- 年 → ~53 周 × 7 天（在 ListView 内自然滚动）

***

### 4.4 `VocabStatBar` / `StreakCard` 颜色硬编码 ✅ 已修复

| 组件 | 旧值 | 新值 |
| --- | --- | --- |
| VocabStatBar learning | `Colors.orange` | `cs.tertiary` |
| VocabStatBar mastered | `Colors.green` | `cs.primary` |
| VocabStatBar ignored | `Colors.grey` | `cs.outline` |
| StreakCard fire icon | `Colors.orange` | `cs.primary` |

***

### 4.5 `reading_sessions_page.dart` 方法参数过多 ✅ 已修复

`_buildBody` 原接受 **10 个参数**（含 `BuildContext` + `ThemeData`）。

**修复**：
- 移除 `loaded` / `loading` / `grouped` / `sessions` / `context` 共 5 个参数（`loaded`/`loading` 由 AsyncState 替代，`grouped`/`sessions` 移至内部 `_buildSessionList`，`context` 函数内未使用）
- 全链路 `ThemeData theme` → `ColorScheme cs`（仅需 colorScheme）

`_buildBody` 当前 6 参数：`l10n, cs, sessionsState, bookCache, deleteSessionsByBook, onRetry`

***

### 4.6 `ReadingStatsViewModel` 不使用 `AsyncState` 模式 ✅ 已修复

`ReadingStatsViewModel` 已迁移至 `AsyncState` 模式：
- `globalStats` → `asyncSignal<GlobalStats?>(AsyncState.loading())`
- `dailyRecords` → `asyncSignal<List<ReadingStats>>(AsyncState.loading())`
- API 错误 → `AsyncState.error(e)`

与此对比：

| 维度   | `HomeViewModel`         | `ReadingStatsViewModel` |
| ---- | ----------------------- | ----------------------- |
| 状态建模 | `signal<AsyncState<T>>` | `signal<AsyncState<T>>` ✅ |
| 错误追踪 | `AsyncState.error`      | `AsyncState.error` ✅     |
| 加载态  | `AsyncState.loading`    | `AsyncState.loading` ✅   |
| 数据重置 | 自动（loading→data/error）  | 自动 ✅                   |

***

## 5. P2 级问题

### 5.1 `useSignalValue` 类型标注冗余 ❌ 未解决

```dart
final AsyncState<GlobalStats?> gs = useSignalValue(vm.globalStats);
final AsyncState<List<ReadingStats>> records = useSignalValue(vm.dailyRecords);
final StatisticsPeriod period = useSignalValue(vm.selectedPeriod);
```

`useSignalValue` 的返回类型已由 signal 泛型推导，显式标注是冗余的。

***

### 5.2 `ThemeData` 和 `BuildContext` 重复传递 ✅ 已修复

`_buildBody` 不再接收 `context`（函数内未使用）。
全链路 `ThemeData theme` → `ColorScheme cs`，`Theme.of(context)` 仅在 `build()` 顶部调用一次。

***

### 5.3 周热力图行列标签位置 ✅ 已修复

重构为行优先布局（row-major）：
- 表头行：空白 + Mon/Tue/Wed/Thu/Fri/Sat/Sun 标签
- 数据行：周起始日期（如 "5/25"）+ 7 格热力图

使用 `month/day` 格式标记每行起始日期，解决"两周前的周三"无法区分的问题。

***

### 5.4 `ReadingTrendChart` 日期抽稀逻辑边界问题 ✅ 已修复

旧的 `records.length > 14 && idx % 7 != 0` 逻辑有边界悬崖：
- 13 条 → 阈值不触发，全部标签显示（可能重叠）
- 15 条 → 仅 idx 0/7/14 显示（过稀疏）

**修复**：`step = max(1, records.length ~/ 6)` → 目标约 6 个标签均匀分布。
- 7 条 → step 1 → 显示 7 个
- 13 条 → step 2 → 显示 7 个
- 15 条 → step 2 → 显示 8 个
- 30 条 → step 5 → 显示 6 个
- 365 条 → step 60 → 显示 ~6 个

***

### 5.5 `_PeriodSelector` 分段按钮文案索引耦合 ✅ 已修复

旧的 `labels[period.index]` 列表与 `StatisticsPeriod.values` 索引硬耦合。
修复：使用 exhaustive `switch(period)` 表达式，添加/删除枚举值产生编译错误。

***

### 5.6 测试仅覆盖初始状态与信号赋值 ❌ 未解决

两个 ViewModel 测试仅验证初始值和手动信号赋值，未测试 `loadData()` / `load()` 方法本身。

**覆盖率缺口**：所有 API 交互、错误路径、数据流完全未测试。

---

## 6. 测试覆盖分析

### 现有测试

| 文件                                                               | 类型   | 覆盖内容                      | 局限性                                    |
| ---------------------------------------------------------------- | ---- | ------------------------- | -------------------------------------- |
| `test/features/statistics/reading_stats_service_test.dart`       | 单元测试 | 初始状态 + 时段切换/派生值测试          | 未测 `loadData()`                        |
| `test/features/statistics/reading_sessions_view_model_test.dart` | 单元测试 | 初始状态 + AsyncState 信号更新测试 | 未测 `load()` / `deleteSessionsByBook()` |

### 测试修复（2026-06-06）

| 问题 | 修复 |
| --- | --- |
| `reading_stats_service_test.dart` 引用 `vm.loaded` 编译失败 | 移除不存在的 `loaded` 测试；`selectedPeriod` 默认值 `month` → `today` |
| `reading_sessions_view_model_test.dart` 信号类型不匹配 | `sessions` 改为 `AsyncState` 模式，测试 `AsyncLoading`/`AsyncData`/`AsyncError` |

### 覆盖率缺口

| 组件 | 单元测试 | Widget 测试 | 错误态 | 说明 |
| --- | --- | --- | --- | --- |
| `ReadingStatsViewModel` | ✅ 初始态 | N/A | ❌ | `loadData()` 核心逻辑未测 |
| `ReadingSessionsViewModel` | ✅ 初始态 | N/A | ❌ | `load()` / `deleteSessionsByBook()` 未测 |
| `StatisticsPage` | N/A | ❌ | ❌ | 需提供 mock ViewModel |
| `ReadingSessionsPage` | N/A | ❌ | ❌ | 需提供 mock ViewModel |
| `TodayReadingCard` | N/A | ❌ | N/A | 纯渲染 widget |
| `StreakCard` | N/A | ❌ | N/A | 纯渲染 widget |
| `ReadingTrendChart` | ❌ | ❌ | ❌ | 空数据/少量数据边界 |
| `WeeklyHeatmap` | ❌ | ❌ | ❌ | 数据聚合逻辑 |
| `VocabStatsSection` | ❌ | ❌ | N/A |  |
| `VocabStatBar` | ❌ | ❌ | ❌ | 零总数除零防卫 |

## 7. 优化清单

### P0（功能性 Bug）

| 类别   | 项目                                                    | 说明    | 状态    |
| ---- | ----------------------------------------------------- | ----- | ----- |
| Bug  | `StatisticsPage` 初始不调用 `loadData()` 导致永久 loading      | §3.1  | ✅ 已修复 |
| Bug  | 错误态静默：无 error 信号、无重试、无失败提示                            | §3.2  | ✅ 已修复 |
| Bug  | `ReadingSessionsViewModel` `catch (_)` 吞异常无日志         | §3.3  | ✅ 已修复 |
| i18n | `formatDuration` / `formatChars` 硬编码中文                | §3.4  | ✅ 已修复 |
| Bug  | `goalMin` 为 0 时除零风险                                   | §3.5  | ✅ 已修复 |
| 编译   | `reading_stats_service_test.dart` 引用 `vm.loaded` 编译失败 | §6 新增 | ✅ 已修复 |

### P1（架构/性能）

| 类别 | 项目                                                          | 说明   | 状态 |
| -- | ----------------------------------------------------------- | ---- | -- |
| 性能 | `WeeklyHeatmap._getWeekMinutes` 28 次全量遍历 + `DateTime.parse` | §4.1 | ✅ 已修复 |
| 代码 | 统一为 `AsyncState` 模式（与 HomeViewModel 一致）                     | §4.6 | ✅ 已修复 |
| 代码 | `load()` 未 await 的 fire-and-forget                          | §4.2 | ✅ 已修复 |
| 代码 | `_buildBody` 10 个参数 → 提取独立 Widget                           | §4.5 | ✅ 已修复 |
| UI | 热力图固定 4 周不感知时段选择                                            | §4.3 | ✅ 已修复 |
| UI | `VocabStatBar` / `StreakCard` 颜色硬编码                         | §4.4 | ✅ 已修复 |

### P2（代码优雅性 / 测试 / 死代码）

| 类别  | 项目                                       | 说明    | 状态 |
| --- | ---------------------------------------- | ----- | -- |
| 代码  | `useSignalValue` 冗余类型标注                  | §5.1  | ❌ 未解决 |
| 代码  | `PeriodSelector` labels 列表与枚举索引硬耦合       | §5.5  | ✅ 已修复 |
| 代码  | `ThemeData` 在方法间重复传递                     | §5.2  | ✅ 已修复 |
| 死代码 | `dailyMinutes` computed `late final` 零引用 | §6 新增 | ❌ 未解决 |
| 测试  | 补充 `loadData()` / `load()` 加载逻辑测试        | §5.6  | ❌ 未解决 |
| 测试  | 补充 Widget 渲染测试                           | §6    | ❌ 未解决 |
