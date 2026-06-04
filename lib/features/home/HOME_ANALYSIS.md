# Home Feature 深度分析报告

> 分析基准：`lib/features/home/`
> 检测日期：2026-06-04

***

## 变更记录

| 日期         | 变更                                                                                      |
| ---------- | --------------------------------------------------------------------------------------- |
| 2026-06-04 | 修复 P1 ViewModel/UI 问题；`buildReadingTrend`→`ReadingTrend`；导航改为 push 阅读器；5 个初始态测试；清除已完成条目 |

***

***

## 1. 架构总览

```
home/
├── application/
│   └── home_view_model.dart      ← Signal 驱动的 ViewModel
├── page/
│   ├── home_page.dart            ← 首页主页面（HookWidget）
│   ├── home_reading_trend.dart   ← 阅读趋势折线图（pure function）
│   ├── home_quotes.dart          ← 每日一句名言（data + widget）
│   └── splash_page.dart          ← 启动闪屏页面
```

**数据流**：Page → ViewModel (Signal) → FFI (`book_api`, `stats_api`)

**页面组成**：

```
SplashPage (2s auto →)
HomePage
 ├── 问候语（时段自适应） + "继续阅读" 标题
 ├── 每日一句（buildDailyQuote）
 ├── Hero 卡片（有书/空态）
 ├── 阅读趋势图（buildReadingTrend）
 └── 最近阅读横向滑动列表
```

***

## 2. 国际化（i18n）问题

整体情况比 backup 好，`l10n` 使用充分，但仍有一些问题。

| 文件                       | 问题                                                                                                                  |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------- |
| `home_quotes.dart:5-16`  | **全部 12 条名言硬编码中文**。每日一句是功能特性，硬编码非英文不属于 i18n 问题（名言本身就是中文），但无英文 fallback。跨语言用户会一直看到中文。建议：从 asset 或 Rust 侧按 locale 加载。 |
| `home_quotes.dart:56,67` | `fontFamily: 'LXGW WenKai'` 硬编码开字体，该字体可能未在 en/other locale 加载。                                                      |

其余页面中，`splash_page.dart` 使用 `l10n.splashTagline`，`home_page.dart` 全部使用 `l10n.xxx`，这部分 ✅。

***

## 3. UI/UX 问题

### 3.1 阅读趋势图 touch 被禁用

```dart
lineTouchData: const LineTouchData(enabled: false),
```

用户不能在趋势图上触摸查看具体数值（某日读了 X 分钟）。体验损失。

### 3.2 无 loading skeleton

加载中两个 signal 状态都展示 `SizedBox.shrink()`（空 Widget）。用户打开首页会看到短暂空白，然后才弹出内容。应使用 shimmer / skeleton 占位。

### 3.3 问候语截止点生硬

```dart
hour < 6 → 深夜
hour < 12 → 上午
hour < 14 → 中午
hour < 18 → 下午
else → 晚上
```

- 6:00 算「上午」而非「早晨」
- 中午（12:00-14:00）包含 12:00-13:00 这段通常也被视为「下午」的文化区间

这是一个跨文化 issue，但 l10n 已通过不同 key（`greetingMorning` vs `greetingNoon`）支持，目前只是时间分段策略可优化。

### 3.4 封面占位图标使用 `bookOpenText`

Hero 卡片、空态卡片、最近阅读卡片三者都用 `bookOpenText` 图标，缺乏视觉区分。

***

## 4. 代码层统一建议

### 4.1 每日一句的实现方式

```dart
// home_quotes.dart:4-16
const quotes = [
  QuoteData('读书破万卷，下笔如有神。', '杜甫'),
  ...
];
```

- 12 条写死在 dart 源码中，修改需要发版
- 索引算法 `DateTime.now().day % quotes.length` 导致每月同一天看到同一句（每月 1 日「读书破万卷」、2 日「书籍是造就灵魂的工具」……）。如果用户连续几个月在同一天打开，完全相同的句子反复出现。
- 建议从 asset JSON 加载或增加随机偏移

## 5. 假实现 / stub 分析

| 类型          | 位置                 | 说明                 |
| ----------- | ------------------ | ------------------ |
| **每日一句静态库** | `home_quotes.dart` | 12 条硬编码。可工作但非可扩展方案 |

***

## 6. 测试覆盖分析

### 现有测试：`test/features/home/application/home_view_model_test.dart`

**优点**：

- 有 Rust FFI 可用性检测，优雅跳过不可用环境
- 测试了初始状态（5 个用例），该部分不依赖 FFI

**问题**：

1. **数据加载/错误路径测试依赖 Rust FFI**
   Rust 后端就绪后可直接验证 `loadData` 状态转换
2. **未测试 Widget 层**
   `HomePage` 使用 `getIt<HomeViewModel>()`，需要注入框架初始化
3. **未测试** `SplashPage`、`buildDailyQuote`、`ReadingTrend`

### 覆盖率缺口地图

| 组件                | 单元测试    | Widget 测试 | 错误态测试     |
| ----------------- | ------- | --------- | --------- |
| `HomeViewModel`   | ✅ (初始态) | N/A       | ❌(需 Rust) |
| `HomePage`        | N/A     | ❌(需 DI)   | ❌         |
| `SplashPage`      | N/A     | ❌         | N/A       |
| `buildDailyQuote` | ❌       | ❌         | N/A       |
| `ReadingTrend`    | ❌       | ❌         | N/A       |

***

## 7. 优化清单

| 优先级    | 类别 | 项目                         |
| ------ | -- | -------------------------- |
| **P2** | UI | 加载态 skeleton/shimmer 替代空白  |
| **P2** | UI | 阅读趋势图启用 touch（显示具体数值）      |
| **P2** | 代码 | 每日一句从 asset JSON 加载，支持动态更新 |
| **P2** | 代码 | 每日一句算法改为 offset 而非 day 取模  |
| **P2** | 内容 | 名言添加英文数据源，按 locale 切换      |

