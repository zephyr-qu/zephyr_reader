# 代码过度复杂化审计报告

> 生成日期: 2026-06-11\
> 范围: lib/ (Dart) + rust/src/ + rust/tests/ (Rust)\
> 排除: 自动生成文件 (`frb_generated.rs`, `service_locator.config.dart`)

***

## 严重度分级

| 级别   | 含义              | 数量 |
| ---- | --------------- | -- |
| 🔴 高 | 严重影响可维护性，建议优先处理 | 14 |
| 🟡 中 | 增加认知负担但可渐进改进    | 22 |
| 🟢 低 | 小瑕疵，顺手改即可       | 12 |

***

## 🔴 高严重度 — 建议优先改

<br />

***

### 6. ReaderPage 550 行 build() (Dart)

**文件**: `lib/features/reader/page/reader_page.dart` (550 行)

**问题**: `build()` 方法内定义 4 个闭包 builder (`buildContentArea`, `buildBottomArea`, `buildTopToolbar`, `buildSelectionToolbar`)，每次 rebuild 重建所有闭包。5 种面板状态通过独立 `useState`/`useSignal` 管理。

**收益**: 拆分 builder 为独立 Widget，合并面板状态。

***

### 7. reader\_settings\_overlay 950 行单文件 (Dart)

**文件**: `lib/features/reader/page/widgets/reader_settings_overlay.dart`

**问题**: 一个文件包含 4 个大型 section builder，每个内部重复实现 sectionHeader/sliderTile/toggle 等子组件。接受 35+ 个独立 callback 参数。

**收益**: 拆分为 4 个独立文件，传配置对象代替 callback 爆炸。

***

### 8. 3 条并行分页路径 (Dart)

**文件**: `lib/features/reader/page/widgets/paginated_renderer.dart` (532 行)

**问题**: Rust descriptor 分页 + PageInfo 缓存回退 + Dart 纯估算回退，三套路径并存。回退路径用硬编码 400×600 估算尺寸。

**收益**: 只保留 Rust 分页路径，失败显示错误。

***

### 12. ResourceConfig dispose/resetToDefault 展开调用 (Dart)

**文件**: `lib/core/reader/reader_config.dart` (254 行)

**问题**: 14 个 PersistedSignal 字段，`dispose()` 展开写 14 次 `x.dispose()`，`resetToDefault()` 展开写 13 次 `x.reset()`。`followSystemFontScale` 在 dispose 里但不在 reset 里（不对称 bug）。

```dart
// 简化：用列表来管理
final _signals = <PersistedSignal>[];
void dispose() { for (final s in _signals) s.dispose(); }
void resetToDefault() { for (final s in _signals) s.reset(); }
```

**收益**: 删除 \~50 行并提供内置对称性保证。

***

### 13. reader\_page\_bindings 两套钩子重复 (Dart)

**文件**: `lib/features/reader/page/widgets/reader_page_bindings.dart`

**问题**: `useReaderBindings` (27 信号) 和 `useReaderContentBindings` (23 信号) 是两套几乎相同的钩子，仅字段略有不同。共 \~200 行，大量重复。

**收益**: 合并为一个带可选字段的钩子，或直接内联消费信号。

***

### 14. 测试 mock ReaderConfig 130 行 (Dart)

**文件**: `test/widget/reader_page_bindings_test.dart` (35-173 行)

**问题**: `_MockReaderConfig` 实现 14 个 `PersistedSignal` 的 `late final` 字段，每个都包含 `persistedEnum/Xxx(prefs, '', ...)` 初始化。130 行样板只为一个 mock。

**收益**: ReaderConfig 改为可接受 mock SharedPreferences 后可删除整个 mock 类。

***

## 🟡 中严重度

### 22. cache\_utils 重复递归逻辑 (Dart)

**文件**: `lib/core/utils/cache_utils.dart`

`_deleteDirectoryContents` 和 `_calculateDirectorySize` 共享相同的 `.list(recursive: true)` 迭代逻辑，仅 per-item 动作不同。提取 `_walkDir` 辅助函数。

#

### 24. reader\_content 6 个竞争 useEffect (Dart)

**文件**: `lib/features/reader/page/widgets/reader_content.dart` (562 行)

6 个 useEffect (page sync, bilingual, auto-scroll, scroll listener, jump, vertical writing) 管理复杂生命周期。按渲染模式拆分 Widget。
