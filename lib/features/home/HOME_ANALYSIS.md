# Home Feature 深度分析报告

> 分析基准：`lib/features/home/`
> 检测日期：2026-06-05
> 状态：✅ 持续追踪

***

## 变更记录

| 日期         | 变更                                                                                                              |
| ---------- | --------------------------------------------------------------------------------------------------------------- |
| 2026-06-05 | 全面重审：新增 ViewModel dispose 泄漏、greeting 不更新、每日一句算法僵硬、全零趋势图、SplashPage 不等待初始化等问题；修正 FLUTTER\_CONVENTIONS 与代码不一致的说明 |
| 2026-06-05 | `buildDailyQuote` 重构为 `DailyQuote` StatelessWidget；更新调用处 `home_page.dart`                                       |
| 2026-06-04 | 修复 P1 ViewModel/UI 问题；`buildReadingTrend`→`ReadingTrend`；导航改为 push 阅读器；5 个初始态测试；清除已完成条目                         |

***

## 1. 架构总览

```
home/
├── application/
│   └── home_view_model.dart      ← Signal 驱动的 ViewModel
├── page/
│   ├── home_page.dart            ← 首页主页面（HookWidget）
│   ├── home_reading_trend.dart   ← 阅读趋势折线图（StatelessWidget）
│   ├── home_quotes.dart          ← 每日一句名言（全局函数 + data）
│   └── splash_page.dart          ← 启动闪屏页面（HookWidget）
```

**数据流**：Page → ViewModel (Signal) → FFI (`book_api`, `stats_api`)

**页面组成**：

```
SplashPage (1.2s auto →)
HomePage
 ├── 问候语（时段自适应，useMemoized 快照法） + "继续阅读" 标题
 ├── 每日一句（DailyQuote Widget）
 ├── Hero 卡片（有书/空态，共用 _HeroCard 布局）
 ├── 阅读趋势图（ReadingTrend Widget）
 └── 最近阅读横向滑动列表
```

***

## 2. 国际化（i18n）问题

整体情况比 backup 好，`l10n` 使用充分，但仍有一些问题。

| 文件                      | 问题                                                           |
| ----------------------- | ------------------------------------------------------------ |
| `home_quotes.dart:5-16` | **全部 12 条名言硬编码中文**。跨语言用户会一直看到中文。建议从 asset/Rust 侧按 locale 加载。 |
| `home_quotes.dart:67`   | 无英文数据源，`DailyQuote` 不感知 locale                               |

其余页面中，`splash_page.dart` 使用 `l10n.splashTagline`，`home_page.dart` 全部使用 `l10n.xxx` ✅。

***

## 3. UI/UX 问题

### 3.1 阅读趋势图 touch 被禁用

```dart
// home_reading_trend.dart:52
lineTouchData: const LineTouchData(enabled: false),
```

用户不能在趋势图上触摸查看具体数值（某日读了 X 分钟）。体验损失。

### 3.2 无 loading skeleton

加载中两个 signal 状态都展示 `SizedBox.shrink()`（空 Widget）。用户打开首页会看到短暂空白，然后才弹出内容。应使用 shimmer / skeleton 占位。

### 3.3 问候语截止点生硬 + 永不更新

```dart
// home_page.dart:361-372
final greeting = useMemoized(() {
  final hour = DateTime.now().hour;
  return hour < 6  ? l10n.greetingLateNight
       : hour < 12 ? l10n.greetingMorning
       : hour < 14 ? l10n.greetingNoon
       : hour < 18 ? l10n.greetingAfternoon
       : l10n.greetingEvening;
}, [DateTime.now().hour]);
```

两层面问题：

**(a) 时间分段**：6:00 算「上午」而非「早晨」；12:00-14:00 包含 12:00-13:00 这段通常被视为「下午」的文化区间。l10n 已通过不同 key 支持，时间分段策略可优化。

**(b)** **`useMemoized`** **依赖值快照化**：`DateTime.now().hour` 在 build 时被计算一次作为依赖值传入，不会随小时变化而更新。如果用户在 11:50 打开首页并保持到 12:10，greeting 仍显示「上午」。虽然实际影响很小（用户很少在首页停留超过 1 小时），但代码语义上这是 bug。

**建议**：改为 `useState` + `Timer.periodic` 定时更新，或使用 `useEffect` 监听系统时间变化（Android `TimeTick` / iOS `NSTimeZone`）。

### 3.4 封面占位图标使用 `bookOpenText`

Hero 卡片（`_heroCoverPlaceholder`）、空态卡片、最近阅读卡片三者都用 `PhosphorIconsRegular.bookOpenText` 图标（line 118, 321, 等），缺乏视觉区分。

<br />

***

## 4.2 每日一句算法僵硬

```dart
// home_quotes.dart:26
final day = DateTime.now().day;
final quote = quotes[day % quotes.length];
```

- 每月同一天看到完全相同的一句。连续数月在同一天打开，句子反复出现。
- 12 条写死在 dart 源码中，修改需要发版

**建议**：使用 `(year * 100 + dayOfYear) % quotes.length` 或随机偏移 + 本地持久化上次显示的日期。

### 4.7 `SplashPage` 最小展示时长不等待实际初始化

```dart
// splash_page.dart:26-29
const minDisplay = Duration(milliseconds: 1200);
final timer = Timer(minDisplay, () {
  if (context.mounted) context.go(RoutePaths.home);
});
```

- 如果 Rust FFI 初始化（加载字典、迁移数据库）超过 1.2s，用户看到 Splash 消失但首页空白/卡住
- 如果初始化在 200ms 内完成，用户在无意义的 Splash 上浪费 1s

**建议**：`Timer` 应同时等待初始化完成（使用 `Future.any([initFuture, minDisplay])`）。

### 4.8 `_HomeErrorView` 嵌套 Scaffold

```dart
// home_page.dart:136
class _HomeErrorView extends StatelessWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Scaffold(  // ← 嵌套 Scaffold
      body: SafeArea(
        child: Center(
```

`_HomeErrorView` 返回完整 `Scaffold`，但调用处将其放在 `CustomScrollView` 的 `SliverToBoxAdapter` 中（`home_page.dart:412-418`），而 `CustomScrollView` 本身已在 `Scaffold` 内。Flutter 禁止 Scaffold 嵌套，会导致布局异常和 runtime 警告。

**建议**：移除 `_HomeErrorView` 中的 `Scaffold` 包裹，仅返回内容布局（`Center` → `Padding` + `Column`），提取时修复。

<br />


<br />

6\. 测试覆盖分析

### 现有测试

| 文件                                                         | 类型        | 覆盖内容                                                 |
| ---------------------------------------------------------- | --------- | ---------------------------------------------------- |
| `test/features/home/application/home_view_model_test.dart` | 单元测试      | 5 个初始状态断言（无 FFI）                                     |
| `test/widget/home_page_test.dart`                          | Widget 测试 | **测试的是** **`signals_hooks`** **机制，非** **`HomePage`** |

### 覆盖率缺口

| 组件                  | 单元测试  | Widget 测试 | 错误态       | 说明                                        |
| ------------------- | ----- | --------- | --------- | ----------------------------------------- |
| `HomeViewModel`     | ✅ 初始态 | N/A       | ❌(需 Rust) | 无 `loadData` 加载/错误态测试                     |
| `HomePage`          | N/A   | ❌         | ❌         | 需 DI/FRB mock                             |
| `SplashPage`        | N/A   | ❌         | ❌         | 需 timer mock                              |
| `DailyQuote`        | ❌     | ❌         | N/A       | 已重构为 `const DailyQuote()` StatelessWidget |
| `ReadingTrend`      | ❌     | ❌         | ❌         | 需 mock 数据                                 |
| `_HeroCard`         | N/A   | ❌         | N/A       | 纯 Widget 渲染测试                             |
| `_RecentBookCard`   | N/A   | ❌         | ❌         | 封面加载失败/无封面                                |
| `_HomeHeaderSliver` | N/A   | ❌         | N/A       | <br />                                    |
| `_HomeErrorView`    | N/A   | ❌         | ❌         | 重试按钮回调                                    |

### 关键问题

1. `test/widget/home_page_test.dart` 使用 `HookBuilder` 测试 `signals_hooks` 库的 `useSignalValue` 行为——这部分是第三方库的行为，**不应该由业务项目测试**。应替换为真实的 `HomePage` widget 测试。
2. 所有错误路径均未测试（需要 mock Rust FFI）。

***

## 7. 优化清单

<br />

### P2（体验优化）

| 类别 | 项目                                 | 说明                   |
| -- | ---------------------------------- | -------------------- |
| UI | 阅读趋势图启用 touch 显示具体数值               | (issue 3.1)          |
| UI | 加载态 skeleton/shimmer 占位            | (issue 3.2)          |
| 代码 | 每日一句算法改为 `year*100 + dayOfYear` 取模 | 避免每月同一天重复（issue 4.2） |
| 代码 | 每日一句从 asset JSON 加载，支持动态更新         | (issue 4.2)          |

### P3（代码优雅性）

| 类别 | 项目                                         | 说明           |
| -- | ------------------------------------------ | ------------ |
| 代码 | greeting 改为 `useState` + 定时更新              | (issue 3.3b) |
| 测试 | 替换 `home_page_test.dart` 为真实 `HomePage` 测试 | (issue 6)    |
| 测试 | 补充 `ReadingTrend` Widget 测试                | (issue 6)    |

