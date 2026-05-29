# 测试与可观测性代码审查报告

**审查日期**: 2026-05-28
**审查范围**: test/\*\*/*.dart + lib/main.dart + lib/core/utils/logging.dart
**维度**: 7 个深度分析维度

---

## 审查范围

| 文件 | 行数 |
|------|------|
| `lib/main.dart` | 90 |
| `lib/core/utils/logging.dart` | 40 |
| `test/helpers/fixtures.dart` | 155 |
| `test/helpers/test_helper.dart` | 179 |
| `test/features/reader/reader_view_model_test.dart` | 543 |
| `test/features/sync/webdav_sync_service_test.dart` | 416 |
| `test/features/sync/sync_view_model_test.dart` | 155 |
| `test/features/article/article_view_model_test.dart` | 127 |
| `test/features/home/application/home_view_model_test.dart` | 202 |
| `test/features/statistics/reading_stats_service_test.dart` | 99 |
| `test/features/reader/vocabulary_marker_service_test.dart` | 92 |
| `test/features/bookshelf/bookshelf_view_model_test.dart` | 60 |
| `test/features/vocabulary/vocabulary_view_model_test.dart` | 51 |
| `test/features/search/search_view_model_test.dart` | 52 |
| `test/core/reader/font_config_test.dart` | 161 |
| `integration_test/` | **空目录, 0 文件** |

---

## 问题总览表

| # | 维度 | 严重级别 | 文件:行号 | 问题摘要 |
|---|------|---------|-----------|----------|
| 1 | FFI 测试启用 | **Critical** | `vocabulary_marker_service_test.dart:14-15` | Rust FFI 直接调用无 `RustLib.init()`, 运行期崩溃 |
| 2 | 全局错误处理 | **Critical** | `logging.dart:24-30` | `Logging.error()` 未上报 Sentry, 错误数据丢失 |
| 3 | Mock 模式 | **Critical** | `test_helper.dart:1` | `import 'package:fake_async/fake_async.dart'` — 包不在 pubspec 依赖中, 编译失败 |
| 4 | 全局错误处理 | **High** | `main.dart:37` | `RustLib.init()` 无 try-catch, FFI 初始化失败即崩溃 |
| 5 | 全局错误处理 | **High** | `main.dart:56-58` | `PlatformDispatcher.onError` 仅 log, 未上报 Sentry |
| 6 | 全局错误处理 | **High** | `main.dart:84-89` | `runZonedGuarded` 回调仅 log, 未上报 Sentry |
| 7 | Mock 模式 | **High** | `home_view_model_test.dart:12` | `_MockBookApi extends Mock` 无 `implements` 子句, mock 无类型约束 |
| 8 | 信号断言 | **High** | `vocabulary_view_model_test.dart:31-43` | 3 个测试方法调用后零断言, 假阳性测试 |
| 9 | 信号断言 | **High** | `home_view_model_test.dart:78-80` | `returnsNormally` 只验证不抛异常, 不验证功能正确性 |
| 10 | FFI 测试启用 | **High** | `home_view_model_test.dart:93-189` | 大量测试被注释为 `/* ... */`, 等同于零覆盖率 |
| 11 | HookBuilder 测试 | **High** | 全部 `test/**/*.dart` | 零个 `HookBuilder` + `testWidgets` 的 hooks 测试, 所有 hooks widget 未经测试 |
| 12 | 测试覆盖率 | **High** | `integration_test/` | 目录为空, 零集成测试, 但 pubspec 有 `integration_test` 依赖 |
| 13 | 代码质量 | **Medium** | `test_helper.dart:49-102` | `setupNullReturn/setupEmptyReturn/setupThrowReturn` 泛型签名 `dynamic Function()` 绕过类型检查 |
| 14 | 代码质量 | **Medium** | `test_helper.dart:171-178` | `extension on AsyncValue<Object?>` 使用了错误的类型名(应为 `AsyncState`) |
| 15 | HookBuilder 测试 | **Medium** | `test_helper.dart:53-56,65-68` | `runWithFakeAsync/advanceAndPump` 在 fake_async 闭包中调用 `pump()` 无效果 |
| 16 | Mock 模式 | **Medium** | `reader_view_model_test.dart:64` | 所有信号 Mock 用 `TestWidgetsFlutterBinding` 但不做 widget 测试, 纯浪费 |
| 17 | 信号断言 | **Medium** | `article_view_model_test.dart:88` | `error?.toString()` 直接调用类型不安全的 toString 而非结构化错误字段 |
| 18 | 信号断言 | **Medium** | `home_view_model_test.dart:61-67` | 测试 `'computed 属性应在依赖变化时更新'` 仅断言初始状态, 未触发变化 |
| 19 | 代码质量 | **Medium** | 全部 `test/**/*.dart` | `library;` 声明缺少库名, 违反 Effective Dart |
| 20 | 测试覆盖率 | **Medium** | `test/` 全局 | 缺少 `dart_test.yaml` / `flutter_test_config.dart` 统一测试配置 |
| 21 | 全局错误处理 | **Medium** | `main.dart:61` | `ErrorWidget.builder` 仅在 `kReleaseMode` 下替换, debug 模式保留红屏 |

---

## 维度 1: HookBuilder 测试模式正确性

### 现状

`signals_hooks` v7 官方测试规范 (`.agents/skills/signals-hooks/SKILL.md:82-103`) 明确要求:

```dart
testWidgets('useSignal test', (tester) async {
  late Signal<int> state;
  await tester.pumpWidget(
    HookBuilder(builder: (context) {
      state = useSignal(42);
      return Text('$state', textDirection: TextDirection.ltr);
    }),
  );
  expect(state.value, 42);
  state.value = 43;
  await tester.pumpAndSettle();
  expect(find.text('43'), findsOneWidget);
});
```

**该项目中零个测试文件使用了此模式。** 所有 hooks widget (reader_page.dart、bookshelf_page.dart、search_page.dart 等 124 处 `useSignal`/`useSignalValue`/`useSignalEffect` 使用) 完全没有 widget 级测试覆盖。

### 问题清单

| ID | 级别 | 文件:行号 | 问题 |
|----|------|-----------|------|
| HB-1 | **High** | 全部 `lib/**/page/*.dart` | 零个 `HookBuilder` 测试, 124 处 hooks 使用未经验证。reader_page.dart 中使用 `useSignalEffect` 的自动主题切换逻辑完全未测试 |
| HB-2 | **Medium** | `test_helper.dart:48-57` | `runWithFakeAsync` 设计意图是 HookBuilder 测试辅助, 但 `fake_async` 包未在 pubspec 中, 无法编译 |
| HB-3 | **Medium** | `test_helper.dart:65-68` | `advanceAndPump` 在 fake_async 回调内调用 `tester.pump()`, 在非 widget 测试上下文中无效果 |

### 修复方案

需要新增 `test/widget/` 目录, 对每个使用 hooks 的页面添加 `HookBuilder` 测试:

```dart
// test/widget/reader_page_test.dart — HookBuilder 测试示例

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/page/reader_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReaderViewModel mockVm;

  setUp(() {
    mockVm = _MockReaderViewModel();
    when(() => mockVm.fontSize).thenReturn(signal(16.0));
    when(() => mockVm.lineHeight).thenReturn(signal(1.6));
    when(() => mockVm.bookId).thenReturn(signal('book_1'));
    when(() => mockVm.chapterIndex).thenReturn(signal(0));
    when(() => mockVm.pageIndex).thenReturn(signal(0));
    when(() => mockVm.totalPages).thenReturn(signal(1));
    when(() => mockVm.isLoading).thenReturn(signal(false));
    when(() => mockVm.error).thenReturn(signal<String?>(null));
    when(() => mockVm.showToolbar).thenReturn(signal(false));
    when(() => mockVm.showCatalog).thenReturn(signal(false));
    when(() => mockVm.showSettings).thenReturn(signal(false));
    when(() => mockVm.showBookmarks).thenReturn(signal(false));
    when(() => mockVm.showSearch).thenReturn(signal(false));
    when(() => mockVm.readerBgColorIndex).thenReturn(signal(0));
    when(() => mockVm.brightnessOverlay).thenReturn(signal(0.0));
    when(() => mockVm.chapterContent)
        .thenReturn(asyncSignal(AsyncState.data('测试内容')));
  });

  testWidgets('useSignal connects to ViewModel signals', (tester) async {
    late Signal<bool> toolbarSignal;

    await tester.pumpWidget(
      HookBuilder(builder: (context) {
        toolbarSignal = useExistingSignal(mockVm.showToolbar);
        return Container();
      }),
    );

    expect(toolbarSignal.value, isFalse);
    when(() => mockVm.showToolbar).thenReturn(signal(true));
  });

  testWidgets('useSignalEffect reacts to font size changes', (tester) async {
    int effectCallCount = 0;
    final fontSize = signal(16.0);

    await tester.pumpWidget(
      HookBuilder(builder: (context) {
        useSignalEffect(() {
          effectCallCount++;
        });
        return Container();
      }),
    );

    await tester.pump();
    expect(effectCallCount, equals(1));

    fontSize.value = 20.0;
    await tester.pump();
    expect(effectCallCount, equals(2));
  });
}

class _MockReaderViewModel extends Mock implements ReaderViewModel {}
```

---

## 维度 2: 信号断言方式

### 规范对照

根据 `signals_hooks` v7 规范, 正确的断言方式是: `signal.value` 读值, `AsyncState.data()/loading()/error()` 构造期望值。项目存在多个"调用即通过"的假阳性测试。

### 问题清单

| ID | 级别 | 文件:行号 | 问题 | 正确写法 |
|----|------|-----------|------|----------|
| SA-1 | **High** | `vocabulary_view_model_test.dart:31-37` | `updateStatus` 测试调用了方法但无任何断言 (`// All should complete without error`) | 需验证 `vm.filterStatus.value` 或调用回调并断言 |
| SA-2 | **High** | `vocabulary_view_model_test.dart:41-43` | `deleteWord` 同 `updateStatus`, 零断言 | 需 Mock Repository 验证 `deleteWord` 被调用 |
| SA-3 | **High** | `vocabulary_view_model_test.dart:46-49` | `refresh` 零断言 | 同上 |
| SA-4 | **High** | `home_view_model_test.dart:78-80` | `returnsNormally` 不验证数据是否被加载 | 应断言 `vm.recentBooks.value.hasData` |
| SA-5 | **Medium** | `article_view_model_test.dart:88` | `vm.articles.value.error?.toString()` 是脆弱的字符串断言, 取决于 Exception.toString() 实现 | 使用 `(vm.articles.value as AsyncError).error.toString()` 或 `vm.articles.value.errorMessage` |
| SA-6 | **Medium** | `home_view_model_test.dart:61-67` | 测试名承诺验证 computed 更新, 实际只断言初始值 | 需在信号变化前后分别断言值 |
| SA-7 | **Low** | `reading_stats_service_test.dart:49-57` | "short session discarded" 测试注释写明 "can't easily check internal state" — 测试本身不完整 | Mock repository 并验证 save 未被调用 |

### 修复示例

**SA-1 — vocabulary_view_model_test.dart**:

```dart
test('updateStatus converts string and updates signal', () async {
  expect(vm.filterStatus.value, equals(VocabStatus.new_));

  await vm.updateStatus('test_id', 'learning');
  expect(vm.filterStatus.value, equals(VocabStatus.learning));

  await vm.updateStatus('test_id', 'mastered');
  expect(vm.filterStatus.value, equals(VocabStatus.mastered));
});
```

**SA-5 — article_view_model_test.dart:86-88**:

```dart
// 脆弱的 toString 断言 → 类型安全结构断言
expect(vm.articles.value.hasError, isTrue);
expect(
  vm.articles.value.error.toString(),
  contains('Network error'),
);
```

---

## 维度 3: FFI 测试启用状态

### 现状

项目使用 `flutter_rust_bridge` 进行 Rust-Dart 互操作。关键的初始化调用 `RustLib.init()` 在 `main.dart:37` 中执行, 但**测试中从未调用**。导致部分测试必崩。

### 问题清单

| ID | 级别 | 文件:行号 | 问题 |
|----|------|-----------|------|
| FFI-1 | **Critical** | `vocabulary_marker_service_test.dart:14-15` | `VocabularyMarkerService().ensureLoaded()` 内部调用 Rust FFI (`scanForVocabulary`), 但测试未调用 `RustLib.init()`, 运行期必崩溃 |
| FFI-2 | **Critical** | `vocabulary_marker_service_test.dart:82` | `rust.scanForVocabulary(text: text)` 直接调用 FFI, 同 FFI-1 |
| FFI-3 | **High** | `home_view_model_test.dart:12-14` | `_MockBookApi extends Mock` 声明了 class 但未用于测试, 实际测试脚本也承认 FFI 无法 mock |
| FFI-4 | **High** | `home_view_model_test.dart:93-189` | 93 行测试代码被整体注释, 理由是 "need FFI Mock support" |
| FFI-5 | **High** | `vocabulary_view_model_test.dart` / `bookshelf_view_model_test.dart` | 无 Mock, 直接实例化 ViewModel — 这些 ViewModel 很可能在构造函数中调用 FFI, 在测试中静默失败 |
| FFI-6 | **Medium** | `test/helpers/fixtures.dart:1` | 导入 `flutter_rust_bridge_for_generated.dart` 仅用于 `PlatformInt64` 类型, 在测试环境无实际效果 (PlatformInt64 是 int 别名) |

### 修复方案

**创建 `test/flutter_test_config.dart` 统一初始化 FFI**:

```dart
// test/flutter_test_config.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 仅对需要 FFI 的测试文件初始化
  // 通过 dart_test.yaml 的 tags: [ffi] 控制
  try {
    await RustLib.init();
    final tempDir = Directory.systemTemp;
    await initStorage(dataDir: '${tempDir.path}/zephyr_test_data');
  } catch (e) {
    // Skipping FFI-dependent tests on platforms without Rust support
  }

  await testMain();
}
```

**vocabulary_marker_service_test.dart 增加 ffis 跳过保护**:

```dart
void main() {
  // 检查 Rust FFI 是否可用 (在 flutter_test_config 中初始化)
  // 如果不可用, 跳过需要 FFI 的测试组
  final ffiAvailable = () {
    try {
      // 轻量验证, 不实际调用
      return true;
    } catch (_) {
      return false;
    }
  }();

  group('VocabularyMarkerService (Dart only)', () {
    // 不需要 FFI 的测试
    test('isVocabularyWord — pure Dart path', () {
      // ...
    });
  });

  if (ffiAvailable) {
    group('VocabularyMarkerService (FFI)', () {
      test('Rust scan result matches Dart', () async {
        // ...
      });
    });
  }
}
```

---

## 维度 4: 全局错误处理完整性

### 错误处理链路分析

```
Uncaught Exception
  ├── runZonedGuarded (main.dart:84) → Logging.error() ❌ 未上报 Sentry
  ├── PlatformDispatcher.onError (main.dart:56) → Logging.error() ❌ 未上报 Sentry
  ├── FlutterError.onError (main.dart:48) → Logging.error() ❌ 未上报 Sentry
  └── ErrorWidget.builder (main.dart:62) → Logging.error() ❌ 未上报 Sentry
```

### 问题清单

| ID | 级别 | 文件:行号 | 问题 |
|----|------|-----------|------|
| EH-1 | **Critical** | `logging.dart:24-30` | `Logging.error()` 只调用 `_logger.e()`, 完全不调用 `Sentry.captureException()`. 项目引入了 `sentry_flutter` 但错误只 log 不上报 — Sentry 引入毫无意义 |
| EH-2 | **High** | `main.dart:37` | `RustLib.init()` 无 try-catch 包裹。FFI 初始化失败 (如 native 库缺失) 直接导致进程崩溃 |
| EH-3 | **High** | `main.dart:39` | `initStorage()` 无 try-catch。如果存储目录不可写, 崩溃 |
| EH-4 | **High** | `main.dart:56-58` | `PlatformDispatcher.instance.onError` 仅 log, 未 `Sentry.captureException()`. 平台级错误被静默丢弃 |
| EH-5 | **High** | `main.dart:84-89` | `runZonedGuarded` 的 onError 回调仅 log, 未上报 Sentry |
| EH-6 | **Medium** | `main.dart:61` | `ErrorWidget.builder` 仅 `kReleaseMode` 下替换, debug 模式无自定义错误 UI |
| EH-7 | **Low** | `logging.dart:24-30` | `error()` 方法 3 个分支 (`exception && stackTrace` / `exception only` / `neither`) 逻辑冗余, 可合并为一个 `Sentry.captureException()` 调用 |

### 修复方案

**EH-1 (Critical) — `logging.dart` 集成 Sentry**:

```dart
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class Logging {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void info(String message) {
    _logger.i(message);
  }

  static void error(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    if (exception != null && stackTrace != null) {
      _logger.e(message, error: exception, stackTrace: stackTrace);
      Sentry.captureException(exception, stackTrace: stackTrace);
    } else if (exception != null) {
      _logger.e(message, error: exception);
      Sentry.captureException(exception);
    } else {
      _logger.e(message);
    }
  }

  static void debug(String message) {
    _logger.d(message);
  }

  static void warning(String message) {
    _logger.w(message);
  }
}
```

**EH-2/EH-3 (High) — `main.dart` 关键路径防护**:

```dart
Future<void> _runApp() async {
  try {
    await RustLib.init();
  } catch (e, stack) {
    Logging.error('RustLib 初始化失败', exception: e, stackTrace: stack);
    runApp(const _FatalErrorApp(message: '核心引擎加载失败, 请重启应用'));
    return;
  }

  try {
    final appDir = await getApplicationDocumentsDirectory();
    await initStorage(dataDir: '${appDir.path}/zephyr_reader/data');
  } catch (e, stack) {
    Logging.error('存储初始化失败', exception: e, stackTrace: stack);
    runApp(const _FatalErrorApp(message: '存储初始化失败, 请检查磁盘空间'));
    return;
  }
  // ... rest
}
```

**EH-4/EH-5 (High) — Platform 和 Zone 错误上报**:

```dart
PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
  Logging.error('未捕获的平台错误', exception: error, stackTrace: stack);
  Sentry.captureException(error, stackTrace: stack);
  return true;
};

runZonedGuarded(() => runApp(const MyApp()), (Object error, StackTrace stack) {
  Logging.error('Zone 未捕获错误', exception: error, stackTrace: stack);
  Sentry.captureException(error, stackTrace: stack);
});
```

---

## 维度 5: Mock 模式与测试隔离

### 问题清单

| ID | 级别 | 文件:行号 | 问题 |
|----|------|-----------|------|
| MP-1 | **Critical** | `test_helper.dart:1` | `import 'package:fake_async/fake_async.dart'` — **此包不在 pubspec.yaml 依赖中**, 编译失败 |
| MP-2 | **High** | `home_view_model_test.dart:12` | `_MockBookApi extends Mock` — 缺少 `implements` 子句, mocktail 的 Mock 无类型约束, 任何方法调用都会返回 null |
| MP-3 | **Medium** | `reader_view_model_test.dart:64` | `TestWidgetsFlutterBinding.ensureInitialized()` 调用于 setUp 前, 但对纯 Dart 单元测试无效且误导 |
| MP-4 | **Medium** | `reader_view_model_test.dart:88-101` | `_MockSharedPreferences` Mock 配置了 10 个方法, 但 `ReaderViewModel` 可能只用了其中 3 个 — 过度设置 |
| MP-5 | **Medium** | `sync_view_model_test.dart:25` | `TestWidgetsFlutterBinding` 在纯 Dart 测试中无必要 |
| MP-6 | **Medium** | `test_helper.dart:86-94` | `setupNullReturn` 使用 `dynamic Function()` 泛型绕过类型安全, 调用方无法编译期校验 |
| MP-7 | **Low** | `reader_view_model_test.dart:21-38` | 8 个 Mock class + 52 行 `when()...thenAnswer()` 配置, 单个 `setUp` 过长 (290 行), 应拆分为辅助函数 |

### 修复方案

**MP-1 (Critical)**:

```dart
// test_helper.dart:1 — 移除 fake_async 导入, 或添加到 pubspec.yaml
// pubspec.yaml dev_dependencies:
//   fake_async: ^1.3.1
```

**MP-2 (High)**:

```dart
// home_view_model_test.dart:12
// 如果 BookApi 是一个实际 class, mocktail 需要 implements:
class _MockBookApi extends Mock implements BookApi {}
```

**MP-6 (Medium)**:

```dart
// 避免 dynamic Function() 绕过类型检查
// 改为直接使用泛型方法:
static void setupNullReturn<T>() {
  when<T>(() => any<T>()).thenAnswer((_) => null);
}
```

---

## 维度 6: 测试覆盖率与边界条件

### 缺失的测试类别

| 类别 | 现状 | 建议 |
|------|------|------|
| **Widget 测试 (HookBuilder)** | 0 个, 所有 `useSignal`/`useSignalEffect` 未覆盖 | 每个 page 至少 1 个 smoke test |
| **集成测试** | `integration_test/` 目录为空 | 至少添加 app 启动 + 主题切换的集成测试 |
| **错误状态测试** | 仅 `article_view_model_test.dart:82-89` | 每个 ViewModel 需覆盖: 网络失败、空数据、超时 |
| **并发测试** | 仅 `home_view_model_test.dart:193-200` (性能组) | 关键路径如书籍导入、页码计算需并发安全测试 |
| **Dispose 清理验证** | 部分测试有 `tearDown(() => vm.dispose())` 但无人验证 dispose 后信号状态 | 需断言 dispose 后信号访问行为 |
| **Rust FFI 兼容性** | `vocabulary_marker_service_test.dart:71` 直接调用 | 集成测试中验证 Dart/Rust 交叉结果一致性 |
| **Golden 测试** | 0 | 关键 UI 组件的视觉回归测试 |
| **Accessibility 测试** | 0 | 语义标签、屏幕阅读器兼容性 |
| **边界条件** | 部分 (webdav 有边界测试) | reader 无: 负数页码、零宽高容器、极端字体大小 |

### 关键缺失

| ID | 级别 | 问题 |
|----|------|------|
| CV-1 | **High** | `integration_test/` 空目录 — 零端到端验证, 无 app 启动、导航、FFI 初始化测试 |
| CV-2 | **High** | 零个 Widget/HookBuilder 测试 — 124 处 hooks 使用未经测试 |
| CV-3 | **Medium** | `vocabulary_view_model_test.dart` — 无错误状态测试 (如 Rust FFI 调用失败) |
| CV-4 | **Medium** | `bookshelf_view_model_test.dart` — 仅测了初始状态, 未测书籍加载、删除、分类筛选 |
| CV-5 | **Medium** | `search_view_model_test.dart` — `searchBook()` 仅测空关键词场景, 未测正常搜索流程 |
| CV-6 | **Medium** | `reading_stats_service_test.dart:73` — `updateProgress` 无活动 session 时只断言 `isNull`, 未断言不抛异常 |

---

## 维度 7: 代码质量与 Effective Dart 合规

### 问题清单

| ID | 级别 | 文件:行号 | 问题 | 规范来源 |
|----|------|-----------|------|----------|
| CQ-1 | **Medium** | 全部 `test/**/*.dart` | `library;` 声明缺少库名 | Effective Dart: `library uri;` |
| CQ-2 | **Medium** | `test_helper.dart:171-178` | `extension on AsyncValue<Object?>` — 类型名应为 `AsyncState<T>`, `AsyncValue` 可能在项目中不存在 | 静态类型安全 |
| CQ-3 | **Medium** | `test_helper.dart:122-126` | `findWidget<T>` 使用 `evaluate()` 后再次 `find.byType(T)` — 重复查询, 应该缓存 |
| CQ-4 | **Medium** | `test_helper.dart:130-147` | `measure()` 中 `print` 违反 `analysis_options.yaml` 的 `avoid_print: error` 规则 |
| CQ-5 | **Medium** | `test_helper.dart:149-166` | `benchmark()` 同样 `print` 违规 |
| CQ-6 | **Medium** | `test/` 全局 | 缺少 `dart_test.yaml` 统一配置 (超时、标签、并发) |
| CQ-7 | **Low** | `vocabulary_marker_service_test.dart:80-88` | Map 的 `$1`/`$2`/`$3` 字段访问 — 是 record 解构, 可读性差, 建议用命名模式 |
| CQ-8 | **Low** | `webdav_sync_service_test.dart:22` | `setUp` 中调用 `TestWidgetsFlutterBinding.ensureInitialized()` — 每次 `setUp` 重复调用, 应移到 `setUpAll` |

### 修复方案

**CQ-2**:

```dart
// test_helper.dart:171-178
// 使用项目中存在的类型 (AsyncState):
extension AsyncStateExtension<T> on AsyncState<T> {
  String get errorMessage {
    if (this is AsyncError<T>) {
      return (this as AsyncError<T>).error.toString();
    }
    return '';
  }
}
```

**CQ-4/CQ-5 (print violation)**:

```dart
// 使用 debugPrint 代替 print
import 'package:flutter/foundation.dart';
// ...
debugPrint('⏱️ $testName: ${stopwatch.elapsedMilliseconds}ms');
```

**建议的 `dart_test.yaml`**:

```yaml
# test/dart_test.yaml
test_on: windows
timeout: 60s
concurrency: 4

tags:
  unit:
  integration:
  slow:
    timeout: 120s
  ffi:
```

---

## 优先级修复路线图

| 优先级 | 问题 ID | 行动 | 工作量 |
|--------|---------|------|--------|
| **P0 — 立即修复** | MP-1 | 修复 `fake_async` 导入 (移除或添加到 pubspec) | 5 min |
| **P0 — 立即修复** | FFI-1, FFI-2 | 创建 `flutter_test_config.dart` 统一初始化 FFI | 15 min |
| **P0 — 立即修复** | EH-1 | `Logging.error()` 集成 Sentry 上报 | 10 min |
| **P1 — 本周内** | EH-2, EH-3 | `_runApp()` 关键路径 try-catch 防护 | 20 min |
| **P1 — 本周内** | EH-4, EH-5 | Platform/Zone 错误上报 Sentry | 10 min |
| **P1 — 本周内** | SA-1~SA-4 | 修复假阳性测试 (vocabulary/home) | 30 min |
| **P1 — 本周内** | MP-2 | 修复 `_MockBookApi extends Mock` | 5 min |
| **P2 — 下个迭代** | HB-1, CV-2 | 新增 HookBuilder widget 测试框架 + 首批测试 | 4h |
| **P2 — 下个迭代** | CV-1 | 启用集成测试 (app 启动 + 基本导航) | 3h |
| **P2 — 下个迭代** | FFI-3~FFI-5 | FFI Mock 隔离方案 (abstract interface) | 3h |
| **P3 — 持续改进** | CQ-1~CQ-8 | 代码质量规范化 | 2h |
| **P3 — 持续改进** | CV-3~CV-6 | 边界条件与错误路径覆盖 | 4h |

---

**总计: 21 个问题 (3 Critical / 8 High / 10 Medium)**

| 严重级别 | 数量 | 关键风险 |
|---------|------|---------|
| Critical | 3 | FFI 测试必崩 + Sentry 空转 + 父件编译失败 |
| High | 8 | 全局错误空白洞 + 假阳性测试 + 全无 hooks widget 测试 |
| Medium | 10 | 代码质量违规 + 覆盖率缺口 |

**核心结论**: 零集成测试、零 widget 测试、Sentry 接入无效、FFI 测试未初始化、存在编译失败的父件 — 测试套件当前处于无法可靠运行的状态。
