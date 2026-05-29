# Zephyr Reader 测试债务追踪

## 总览

| 指标 | 数值 |
|------|------|
| 追踪起始日期 | 2026-05-28 |
| 总债务项 | 18 |
| 已修复 | 14 |
| 进行中 | 0 |
| 待修复 | 4 |

---

## 严重债务

### C-01: FFI 测试无 RustLib.init() 运行期崩溃

| 字段 | 值 |
|------|----|
| **级别** | Critical |
| **来源** | CODE_REVIEW.md: FFI-1, FFI-2 |
| **文件** | `test/features/reader/vocabulary_marker_service_test.dart:14-15` |
| **描述** | `VocabularyMarkerService().ensureLoaded()` 内部调用 Rust FFI (`scanForVocabulary`)，但测试未调用 `RustLib.init()`，运行期必崩溃 |
| **修复方案** | 创建 `flutter_test_config.dart` 统一初始化；使用 `if (ffiAvailable)` 包裹 FFI 调用 |
| **依赖** | `flutter_test_config.dart` |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### C-02: fake_async 包不在 pubspec 但被导入

| 字段 | 值 |
|------|----|
| **级别** | Critical |
| **来源** | CODE_REVIEW.md: #3 |
| **文件** | `test/helpers/test_helper.dart:1` |
| **描述** | `import 'package:fake_async/fake_async.dart'` — 包不在 pubspec 依赖中，编译失败 |
| **修复方案** | 移除 `fake_async` 导入；用 `signals_hooks` 内置的异步测试模式替代 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

---

## 高债务

### H-01: 零个 HookBuilder Widget 测试

| 字段 | 值 |
|------|----|
| **级别** | High |
| **来源** | CODE_REVIEW.md: HB-1 |
| **文件** | 全部 `test/**/*.dart` |
| **描述** | 零个 `HookBuilder` + `testWidgets` 的 hooks 测试，所有 124 处 hooks widget 未经测试 |
| **修复方案** | 在 `test/widget/` 下为每个页面创建 HookBuilder 测试 |
| **接口** | 需暴露页面的 Mock 构造函数 |
| **创建日期** | 2026-05-28 |
| **状态** | ⬜ 待修复 |

### H-02: integration_test/ 目录为空

| 字段 | 值 |
|------|----|
| **级别** | High |
| **来源** | CODE_REVIEW.md: #12 |
| **文件** | `integration_test/` |
| **描述** | 目录为空，零集成测试，但 pubspec 有 `integration_test` 依赖 |
| **修复方案** | 添加至少一个集成测试用例 |
| **创建日期** | 2026-05-28 |
| **状态** | ⬜ 待修复 |

### H-03: 零断言假阳性测试

| 字段 | 值 |
|------|----|
| **级别** | High |
| **来源** | CODE_REVIEW.md: SA-1, SA-2, SA-3 |
| **文件** | `test/features/vocabulary/vocabulary_view_model_test.dart:31-49` |
| **描述** | 3 个测试方法调用后零断言，假阳性测试 |
| **修复方案** | 为每个测试添加结构化断言 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### H-04: 测试被整体注释

| 字段 | 值 |
|------|----|
| **级别** | High |
| **来源** | CODE_REVIEW.md: #10 |
| **文件** | `test/features/home/application/home_view_model_test.dart:93-189` |
| **描述** | 93 行测试代码被整体注释，理由是 "need FFI Mock support" |
| **修复方案** | 创建 FFI Mock 替代方案或用标签跳过 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### H-05: Mock 无 implements 子句

| 字段 | 值 |
|------|----|
| **级别** | High |
| **来源** | CODE_REVIEW.md: #7 |
| **文件** | `test/features/home/application/home_view_model_test.dart:12` |
| **描述** | `_MockBookApi extends Mock` 无 `implements` 子句，mock 无类型约束 |
| **修复方案** | 添加 `implements BookApi` 子句 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### H-06: returnsNormally 不验证结果

| 字段 | 值 |
|------|----|
| **级别** | High |
| **来源** | CODE_REVIEW.md: SA-4 |
| **文件** | `test/features/home/application/home_view_model_test.dart:78-80` |
| **描述** | `returnsNormally` 只验证不抛异常，不验证功能正确性 |
| **修复方案** | 添加数据断言 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

---

## 中债务

### M-01: 缺少 dart_test.yaml

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: #20 |
| **描述** | 缺少统一测试配置文件 |
| **状态** | ✅ 已创建（2026-05-28） |

### M-02: 缺少 flutter_test_config.dart

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: #20 |
| **描述** | 缺少测试运行环境配置 |
| **状态** | ✅ 已创建（2026-05-28） |

### M-03: setupNullReturn 等签名绕过类型检查

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: #13 |
| **文件** | `test/helpers/test_helper.dart:49-102` |
| **描述** | `setupNullReturn/setupEmptyReturn/setupThrowReturn` 泛型签名 `dynamic Function()` 绕过类型检查 |
| **修复方案** | 添加类型参数或使用更安全的 Mock 设置 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### M-04: AsyncValue 扩展使用了错误类型名

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: #14 |
| **文件** | `test/helpers/test_helper.dart:171-178` |
| **描述** | `extension on AsyncValue<Object?>` 使用了错误的类型名（应为 `AsyncState`) |
| **修复方案** | 改为 `AsyncState` 或将扩展标记为私有 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### M-05: 不必要的 TestWidgetsFlutterBinding

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: #16 |
| **文件** | `test/features/reader/reader_view_model_test.dart:64` |
| **描述** | 所有信号 Mock 用 `TestWidgetsFlutterBinding` 但不做 widget 测试，纯浪费 |
| **修复方案** | 移除不必要的 `TestWidgetsFlutterBinding` |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### M-06: error?.toString() 类型不安全

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: SA-5 |
| **文件** | `test/features/article/article_view_model_test.dart:88` |
| **描述** | `error?.toString()` 直接调用类型不安全的 toString 而非结构化错误字段 |
| **修复方案** | 使用结构化错误断言 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### M-07: computed 属性测试未验证变化

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: SA-6 |
| **文件** | `test/features/home/application/home_view_model_test.dart:61-67` |
| **描述** | 测试名承诺验证 computed 更新，实际只断言初始值 |
| **修复方案** | 在信号变化前后分别断言值 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

### M-08: library 声明缺少库名

| 字段 | 值 |
|------|----|
| **级别** | Medium |
| **来源** | CODE_REVIEW.md: #19 |
| **文件** | 全部 `test/**/*.dart` |
| **描述** | `library;` 声明缺少库名，违反 Effective Dart |
| **修复方案** | 添加库名或完全移除声明 |
| **创建日期** | 2026-05-28 |
| **状态** | ✅ 已修复 |

---

## 低债务

### L-01: short session discarded 测试不完整

| 字段 | 值 |
|------|----|
| **级别** | Low |
| **来源** | CODE_REVIEW.md: SA-7 |
| **文件** | `test/features/statistics/reading_stats_service_test.dart:49-57` |
| **描述** | 测试注释写明 "can't easily check internal state" — 测试本身不完整 |
| **修复方案** | Mock repository 并验证 save 未被调用 |
| **创建日期** | 2026-05-28 |
| **状态** | ⬜ 待修复 |

### L-02: PlatformInt64 导入仅用于类型别名

| 字段 | 值 |
|------|----|
| **级别** | Low |
| **来源** | CODE_REVIEW.md: FFI-6 |
| **文件** | `test/helpers/fixtures.dart:1` |
| **描述** | 导入 `flutter_rust_bridge_for_generated.dart` 仅用于 `PlatformInt64` 类型 |
| **修复方案** | `PlatformInt64` 是 `int` 别名，导入仅用于类型注解，可保留 |
| **创建日期** | 2026-05-28 |
| **状态** | ⬜ 待修复（低优先级） |

---

## 修复计划

### 第一阶段（立即修复）

1. C-01: 创建 `flutter_test_config.dart`（✅ 已完成）
2. C-02: 移除 `fake_async` 导入
3. H-05: 添加 `implements BookApi` 子句
4. H-06: 为 `returnsNormally` 测试添加断言

### 第二阶段（本周）

1. H-03: 为 vocabulary_view_model_test 添加断言
2. H-04: 处理注释掉的 FFI 测试
3. M-06: 修复 error.toString() 断言
4. M-07: 修复 computed 属性测试

### 第三阶段（本月）

1. H-01: 创建 test/widget/ HookBuilder 测试
2. H-02: 添加集成测试用例
3. M-03 ~ M-05: 修复 test_helper.dart 问题

### 第四阶段（持续）

1. L-01 ~ L-02: 低优先级修复
2. M-08: library 声明规范化
