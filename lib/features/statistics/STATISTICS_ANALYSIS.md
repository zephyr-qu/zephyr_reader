# Statistics Feature 深度分析报告

> 分析基准：`lib/features/statistics/`
> 检测日期：2026-06-06

***

1\. 架构总览

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

<br />

3\. 5.6 测试仅覆盖初始状态与信号赋值 ❌ 未解决

两个 ViewModel 测试仅验证初始值和手动信号赋值，未测试 `loadData()` / `load()` 方法本身。

**覆盖率缺口**：所有 API 交互、错误路径、数据流完全未测试。

***

## 6. 测试覆盖分析

### 现有测试

| 文件                                                               | 类型   | 覆盖内容                     | 局限性                                    |
| ---------------------------------------------------------------- | ---- | ------------------------ | -------------------------------------- |
| `test/features/statistics/reading_stats_service_test.dart`       | 单元测试 | 初始状态 + 时段切换/派生值测试        | 未测 `loadData()`                        |
| `test/features/statistics/reading_sessions_view_model_test.dart` | 单元测试 | 初始状态 + AsyncState 信号更新测试 | 未测 `load()` / `deleteSessionsByBook()` |

### 测试修复（2026-06-06）

| 问题                                                    | 修复                                                                       |
| ----------------------------------------------------- | ------------------------------------------------------------------------ |
| `reading_stats_service_test.dart` 引用 `vm.loaded` 编译失败 | 移除不存在的 `loaded` 测试；`selectedPeriod` 默认值 `month` → `today`                |
| `reading_sessions_view_model_test.dart` 信号类型不匹配       | `sessions` 改为 `AsyncState` 模式，测试 `AsyncLoading`/`AsyncData`/`AsyncError` |

### 覆盖率缺口

| 组件                         | 单元测试  | Widget 测试 | 错误态 | 说明                                     |
| -------------------------- | ----- | --------- | --- | -------------------------------------- |
| `ReadingStatsViewModel`    | ✅ 初始态 | N/A       | ❌   | `loadData()` 核心逻辑未测                    |
| `ReadingSessionsViewModel` | ✅ 初始态 | N/A       | ❌   | `load()` / `deleteSessionsByBook()` 未测 |
| `StatisticsPage`           | N/A   | ❌         | ❌   | 需提供 mock ViewModel                     |
| `ReadingSessionsPage`      | N/A   | ❌         | ❌   | 需提供 mock ViewModel                     |
| `TodayReadingCard`         | N/A   | ❌         | N/A | 纯渲染 widget                             |
| `StreakCard`               | N/A   | ❌         | N/A | 纯渲染 widget                             |
| `ReadingTrendChart`        | ❌     | ❌         | ❌   | 空数据/少量数据边界                             |
| `WeeklyHeatmap`            | ❌     | ❌         | ❌   | 数据聚合逻辑                                 |
| `VocabStatsSection`        | ❌     | ❌         | N/A | <br />                                 |
| `VocabStatBar`             | ❌     | ❌         | ❌   | 零总数除零防卫                                |

## 7. 优化清单

### P2（代码优雅性 / 测试 / 死代码）

| 类别  | 项目                                       | 说明    | 状态    |
| --- | ---------------------------------------- | ----- | ----- |
| 死代码 | `dailyMinutes` computed `late final` 零引用 | §6 新增 | ❌ 未解决 |
| 测试  | 补充 `loadData()` / `load()` 加载逻辑测试        | §5.6  | ❌ 未解决 |
| 测试  | 补充 Widget 渲染测试                           | §6    | ❌ 未解决 |

