# 基准测试缺口详解

> 基于 `BENCHMARK_GAP_ANALYSIS.md` 中列出的 4 个主要缺口，逐一说明 What / Why / How。

---

## 1. CI 集成 — 基准已有但未接入 CI Pipeline

### 现状

项目 `rust/benches/` 和 `test/benchmarks/` 各有一套基准：
```bash
# Rust 基准（Criterion）
cargo bench

# Flutter 基准
flutter test test/benchmarks/
```

但这两条命令**从未在 CI 中自动执行**。每次跑基准都需要开发者手动在本地执行，而本地结果随机器负载波动，没有参考价值。

### 为什么需要

| 场景 | 无 CI | 有 CI |
|------|-------|-------|
| 某次重构后 parseBook 慢了 2x | 开发者可能没注意到 | CI 自动报警 |
| 新 PR 改动了 FFI 调用模式 | 需要 reviewer 手动质疑 | CI 自动显示对比数据 |
| 需要判断性能趋势 | 无数据 | 每次 CI 运行结果串联成趋势图 |

### 怎么做

在 `.github/workflows/benchmark.yml` 中增加 workflow：

```yaml
name: Benchmarks
on:
  pull_request:
    paths:
      - 'rust/**'
      - 'test/benchmarks/**'
      - 'lib/**'

jobs:
  bench:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test test/benchmarks/ --reporter json > bench_results.json
      # Rust 侧使用 cargo-criterion 输出 JSON
      - run: cargo bench --message-format json > rust_bench_results.json
      # 对比历史基线，>5% 退化给出警告
      - uses: benchmark-action/github-action-benchmark@v1
```

**估算工作量**: 0.5d（编写 workflow + 调试 runner 环境）

---

## 2. 基线追踪 — 无历史比较，无法检测回归

### 现状

当前基准运行后只打印到控制台：
```
[BENCH] parseBook(活着.txt) -> 127ms
```

这行输出没有被任何系统捕获。下次运行结果覆盖了这次，无法回答"比上周是快了还是慢了"。

### 为什么需要

检测性能回归的前提是**知道"正常值是多少"**。没有基线，每一个数字都是孤立的：

```
# 孤立数据：完全无法判断
parseBook(活着.txt) = 127ms
parseBook(活着.txt) = 98ms   ← 这是优化了还是波动？
parseBook(活着.txt) = 152ms  ← 这是回归了还是系统负载高？
```

**有基线的话：**
```
# 基线（main 分支最近 10 次均值）：105ms ± 8ms
本次 PR: 152ms  ← 超过基线 +44%，标红
```

### 怎么做

**方案 A — GitHub Actions Benchmark Action（推荐）**
- 使用 `github-action-benchmark`，自动将运行结果写入 `gh-pages` 分支
- 生成随时间变化的折线图（Chart.js）
- PR 上自动评论对比结果
- 支持设置 alert threshold（如 >10% 退化标红）

**方案 B — 自建 JSON 存储**
- 每次 CI 运行将基准结果以 JSON 写入 artifacts
- 用脚本对比当前结果与上次 main 分支结果
- 成本低但无可视化

**现有基准的输出格式已对齐 JSON**（`parse_benchmark.dart` 等均输出 `[RESULT] {...}`），接入基线追踪几乎不需要改基准代码。

**需要注意：** Flutter 基准依赖 Rust FFI，需要 runner 上能编译 Rust。GitHub Actions 的 `ubuntu-latest` 默认没有 Rust/Flutter 的 native 编译环境，需要额外配置 `cargo` 和 `flutter` action。

**估算工作量**: 1d（配置 CI + 首次基线建立 + 阈值调优）

---

## 3. Flutter Profile 模式测试 — 无法捕获 GPU/UI 线程帧率

### 现状

现有基准在 `flutter test`（即 headless Dart VM）下运行：

```
flutter test test/benchmarks/page_turn_benchmark.dart
```

`flutter test` 的行为：
- 使用 **Dart VM**，不是 Flutter Engine
- 没有 **GPU 线程**（没有 Impeller/Skia 渲染）
- 没有 **UI 线程帧管线**（没有 vsync、build/layout/paint 流水线）
- `WidgetTester.pump()` 是人工 tick 帧，不是真实帧率

这意味着 `flutter test` 只能测出**纯 Dart 逻辑的 CPU 耗时**，测不出：
- Widget build/layout/paint 耗时
- GPU 渲染/合成开销
- 由于栅格化超时而导致的丢帧（jank）

### 为什么需要

对于翻页这种**每一帧都有 16ms 预算**的操作，光测 `getPageContent` 的逻辑延迟是不够的：

```
# 现有基准测量
getPageContent(page=0) = 3ms   ← 逻辑层通过，看起来很好

# 实际用户看到的情况
Frame 1: build=12ms + paint=8ms = 20ms  ← 丢一帧
Frame 2: build=10ms + paint=9ms = 19ms  ← 又丢一帧
```

逻辑延迟 3ms + Widget 构建 12ms + GPU 栅格化 8ms = **23ms，远超 16ms 预算**。

没有 Profile 模式测试，**页面渲染的实际流畅度是盲区**。

### 怎么做

使用 `flutter drive --profile` 而不是 `flutter test`：

```bash
# Profile 模式下运行集成测试
flutter drive \
  --profile \
  --target=test_driver/performance_test.dart
```

测试代码中使用 `Timeline` 来追踪帧渲染：

```dart
// test_driver/performance_test.dart 示例
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmark;

  testWidgets('翻页帧率测试', (tester) async {
    // 收集 60 帧的 Timeline 数据
    await binding.traceAction(
      () async {
        for (int i = 0; i < 60; i++) {
          await tester.tap(find.byKey(Key('next_page')));
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'page_turn_frame_budget',
    );
  });
}
```

Profile 模式下可以采集到的指标：

| 指标 | 含义 | 健康值 |
|------|------|--------|
| `frame_count` | 总帧数 | — |
| `frame_build_time_ms` (avg/p99) | Widget build 耗时 | < 8ms |
| `frame_rasterizer_time_ms` (avg/p99) | GPU 栅格化耗时 | < 8ms |
| `missed_frame_count` | 超 16ms 预算的帧数 | 0 |
| `frame_rate` | 实际帧率 | 60 fps 接近 |

**估算工作量**: 1d（编写集成测试 + CI 中配置 Flutter Drive 环境）

---

## 4. 翻页帧率（16ms 预算） — 当前测量的是逻辑延迟，不含实际渲染

### 现状

`page_turn_benchmark.dart` 目前测量的是：

```dart
// 翻页基准：测的是这个
final (content, elapsed) = await TestHelper.measure(
  'getPageContent(page=$i)',
  () => core_api.getPageContent(/* ... */),
);
```

它测量的是 Dart → Rust FFI 调用 `getPageContent` 的**纯逻辑耗时**。这个数字通常很小（1-5ms），会给人一种"翻页很快"的错觉。

但用户实际感受到的翻页延迟 = 完整帧管线耗时：

```
触控事件   layout   paint   合成   GPU栅格化   显示
  |         |        |       |       |         |
  ↓         ↓        ↓       ↓       ↓         ↓
 touch → build → layout → paint → compositing → rasterize → display
  |         |        |       |                |            |
 0ms       5ms     8ms     12ms             18ms         20ms
                                              ↑
                                   16ms 预算已超，丢一帧
```

### 为什么现有测量不够

| 测量维度 | 现有基准 | 缺少的部分 |
|----------|----------|------------|
| `getPageContent` 延迟 | ✅ 3ms | — |
| Widget `build()` 耗时 | ❌ | `ReaderContent.build()` Rebuild 开销 |
| `paint()` 耗时 | ❌ | 文本排版 + 高亮绘制 |
| GPU 栅格化 | ❌ | 首次渲染的 shader 编译 + 纹理上传 |
| **端到端总计** | **3ms** | **实际 ~20ms** |

### 补全方式：叠加两种测量

**层级 1 — 逻辑延迟**（已有，继续保留）
```dart
// test/benchmarks/page_turn_benchmark.dart
// 测量 FFI 调用本身
```

**层级 2 — 渲染帧率**（新增）
```dart
// test_driver/page_turn_frame_rate_test.dart (新增)
// 使用 flutter drive --profile，采集 Timeline 帧数据
```

两者互为补充：逻辑延迟告诉你 Rust 侧有没有变慢；渲染帧率告诉你 UI 层有没有丢帧。一个 PR 可能改进了逻辑延迟（Rust 优化）却恶化了渲染帧率（Widget 复杂度增加），只有一个测量就发现不了。

### 翻页流畅度的健康标准

| 指标 | 目标 | 硬门禁 |
|------|------|--------|
| 平均帧构建耗时 | < 6ms | > 10ms 报警 |
| P99 帧构建耗时 | < 12ms | > 16ms 失败 |
| 丢帧率（超 16ms 的帧） | 0% | > 5% 报警 |
| `getPageContent` P99 | < 10ms | > 20ms 报警 |

**估算工作量**: 1d（编写 FrameTiming 集成测试 + 调优 profile 模式环境）

---

## 优先级总览

| 缺口 | 优先级 | 估算 | 依赖 |
|------|--------|------|------|
| CI 集成 | P1 | 0.5d | GitHub Actions 配置 |
| 基线追踪 | P2 | 1d | CI 集成完成 |
| Profile 模式测试 | P2 | 1d | Flutter Drive 环境 |
| 翻页帧率测试 | P2 | 1d | Profile 模式就绪后 |

## 当前项目已有但 CI 未覆盖的基准

```
test/benchmarks/              ← flutter test 下运行（逻辑延迟）
├── parse_benchmark.dart      ✅ parseBook 耗时
├── reader_tti_benchmark.dart ✅ 全链路打开耗时
├── page_turn_benchmark.dart  ✅ getPageContent 延迟（逻辑层）
└── search_benchmark.dart     ✅ 搜索索引+查询

rust/benches/                 ← cargo bench 下运行
└── parsing_benchmark.rs      ✅ Criterion 基准（已有参数化测试）
```
