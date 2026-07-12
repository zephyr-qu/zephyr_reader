# 阶段 6 详细设计：统一测量验收体系

> 前置：阶段 1–5（统一测量栈 / TypesetCalibration 扩展 / 本地缓存 / 测完再 paginate / Rust 去魔数）已在工作区落地。  
> 本文档定义**如何证明**该方案有效，以及如何防止回归。

---

## 1. 项目现状盘点

### 1.1 已落地（阶段 1–5）

| 组件 | 文件 | 行为 |
|------|------|------|
| 统一测量入口 | [`typeset_calibrator.dart`](../../../lib/features/reader/data/typeset_calibrator.dart) | `measureLayoutFingerprint()`：TextPainter + StrutStyle 测字宽、行宽比、行高 |
| 排版指纹 | `CalibrationData` | 新增 `effectiveLineWidthRatio`、`lineHeightDp`；JSON 序列化 |
| 缓存 | [`layout_calibration_store.dart`](../../../lib/features/reader/data/layout_calibration_store.dart) | SharedPreferences，`layout_calib_v1_{hash}` |
| 解析入口 | `resolveLayoutCalibration()` | cache hit → 跳过测量；miss → 测量 + 写入 |
| 加载时序 | [`chapter_load_orchestrator.dart`](../../../lib/features/reader/core/application/chapter_load_orchestrator.dart) L142 | `await resolveLayoutCalibration()` **先于** `_runQuickPaginateForIntent` |
| Rust 消费 | [`block_paginator.rs`](../../../rust/src/text/block_paginator.rs) | `full_line_w = page_w × ratio`；`line_h = measured_line_height_px \|\| font×lsp` |
| FRB 类型 | [`typeset.rs`](../../../rust/src/domain/types/typeset.rs) | `effective_line_width_ratio`、`measured_line_height_px`；`LAYOUT_ALGORITHM_VERSION = 7` |
| 单元测试（部分） | [`typeset_calibrator_test.dart`](../../../test/features/reader/typeset_calibrator_test.dart) | fingerprint 测量、JSON 往返、calibrationToRust 映射 |

### 1.2 已知缺口（阶段 6 必须补齐）

| # | 缺口 | 影响 |
|---|------|------|
| G1 | [`block_page_content.dart`](../../../lib/features/reader/rendering/block_page_content.dart) 诊断仍用默认 `kRustLineWidthSafetyRatio`，未传实测 ratio | `[LineBreak] rustEstLines` 不可信，无法作验收依据 |
| G2 | `ReaderRenderDataSource` 无 `calibration` 暴露；渲染层拿不到 fingerprint | G1 的根因：block 页无法读取 paginate 时用的 ratio |
| G3 | 无 `layout_calibration_store_test.dart` | 缓存读写未自动化验证 |
| G4 | 无跨层行数对齐测试 | Rust 估算 vs TextPainter 偏差无 CI 门禁 |
| G5 | 无 widget 级 overflow 测试 | 视口溢出无自动化捕获 |
| G6 | `chapter_load_orchestrator_test` 明确跳过 pagination pipeline | 时序「测完再 paginate」无单测 |
| G7 | Rust `block_paginator` 无 ratio/line_height 专项测试 | 阶段 5 行为无回归网 |
| G8 | Bug B：`normalLoad` metrics backfeed 不重 paginate | 验收须明确：首屏责任在 `resolveLayoutCalibration`，不在 backfeed |
| G9 | `check.jsonl` 仍为占位 | 无结构化手动验收记录 |

### 1.3 数据流（验收监测点）

```
resolveLayoutCalibration(params, prefs)
  ├─ [LayoutCalib] cache hit | measure complete
  └─ CalibrationData { ratio, lineHeightDp, cjkWidth, ... }
        ↓
buildTypesetConfig(calibration) → TypesetConfig.calibration
  ├─ [PageEstimate] buildTypesetConfig ... ratio= lineH=
  └─ FRB → Rust BlockLayoutMetrics
        ├─ [PageEstimate] BlockLayoutMetrics full_line_w= line_h=
        └─ BlockPaginator → page_blocks slice
              ↓
buildBlockPageContent(slice) → TextPainter 重排
  └─ [LineBreak] TOTAL overflow= flutLines= rustEstLines=   ← 阶段6主验收信号
```

---

## 2. 验收目标与量化阈值

### 2.1 主指标

**定义**

```
overflowDp = max(0, totalTpHeight - bodyHeight)
```

- `totalTpHeight`：页内所有 text slice 的 TextPainter 高度 + blockPadding + paragraphSpacing（与 [`block_page_content.dart`](../../../lib/features/reader/rendering/block_page_content.dart) L82–140 一致）
- `bodyHeight`：`PaginatedPageViewport.maxHeight`（已扣 vPad）

**通过条件**

| 指标 | 阈值 | 说明 |
|------|------|------|
| `overflowDp` | **≤ 0.5 dp** | 允许亚像素误差；>0.5 视为 FAIL |
| `\|flutLines - rustEstLines\|` | **≤ 1** | 断行算法差 1 行可接受 |
| `effectiveLineWidthRatio` | **[0.85, 1.0]** | 测量异常时 fallback 0.97 |
| `lineHeightDp / fontSize` | **[1.0, 3.0]** | 与 lineHeight 设置合理 |
| 页内垂直滚动 | **不可发生** | 无 ScrollView；Column 不超出 SizedBox |

### 2.2 辅指标

| 指标 | 阈值 | 日志关键字 |
|------|------|------------|
| 缓存命中 | 同配置二次启动有 hit | `[LayoutCalib] cache hit` |
| 测量耗时 | 全量测量 < 5ms（目标） | `[LayoutCalib] measure complete` |
| config_hash 变更 | 改字号后 hash 变、重 paginate | `[PageEstimate]` + 页数变化 |
| Rust 行宽 | `full_line_w ≈ page_w × ratio` | `[PageEstimate] BlockLayoutMetrics` |

### 2.3 明确不在阶段 6 范围

- ICU vs Rust 贪心**断行点完全一致**（不可达，只验 overflow）
- 底部 Chrome 遮挡（UI 叠加，单独 UX 项）
- 换设备云端同步（无账户，仅本地缓存）

---

## 3. 阶段 6.1：诊断对齐（G1/G2 修复规格）

### 3.1 目标

使 `[LineBreak]` / `[LineWidth]` 日志使用**与 Rust paginate 相同的 fingerprint**，否则阶段 6 自动化与手动验收无效。

### 3.2 方案：经 PaginationCoordinator 向渲染层传递 fingerprint

**改动 A** — [`pagination_coordinator.dart`](../../../lib/features/reader/core/application/pagination_coordinator.dart)

- 已有 `Signal<CalibrationData?> calibration`
- 在 `resolveLayoutCalibration` 完成后写入（orchestrator L509 已写）
- 无需新类型

**改动 B** — [`reader_render_data_source.dart`](../../../lib/features/reader/core/data/reader_render_data_source.dart) 或渲染调用链

推荐**最小侵入**：不扩展 `ReaderRenderDataSource` 接口，而在 `buildBlockPageContent` 增加可选参数：

```dart
Widget buildBlockPageContent({
  // ... existing ...
  CalibrationData? layoutCalibration,  // 新增，nullable
})
```

调用方 [`paginated_renderer.dart`](../../../lib/features/reader/rendering/paginated_renderer.dart) `buildSinglePageContent` 从 `PaginationCoordinator` / ViewModel 传入 `calibration.value`。

**改动 C** — [`block_page_content.dart`](../../../lib/features/reader/rendering/block_page_content.dart) L52–150

```dart
final ratio = layoutCalibration?.effectiveLineWidthRatio
    ?? kDefaultEffectiveLineWidthRatio;
final cjkWidthPx = layoutCalibration != null
    ? layoutCalibration.cjkWidth * dpr
    : flutCjkPx * kRustCharWidthScale;

final rustEstCharsPerLine = estimateRustCharsPerLine(
  cjkWidthPx: cjkWidthPx,
  pageWidthPx: pageWidthPx,
  fontSizePx: fontSizePx,
  effectiveLineWidthRatio: ratio,
);

final rustEstLines = estimateRustLinesForText(
  // ... 同上，传 ratio + cjkWidthPx ...
);
```

**日志字段变更**

| 旧 | 新 |
|----|-----|
| `safety=0.97` | `ratio=0.976`（实测） |
| `rustEstLines`（基于默认 ratio） | 基于 `layoutCalibration` |

### 3.3 验收（6.1 自身）

- 打开书籍后 `[LineWidth] ratio=` 与 `[PageEstimate] buildTypesetConfig ... ratio=` **数值一致**
- 改字号后 ratio 随新 fingerprint 变化

---

## 4. 阶段 6.2：自动化测试详细规格

### 4.1 Layer A — Dart 单元测试

#### 文件：`test/features/reader/data/layout_calibration_store_test.dart`（新建）

| 用例 ID | 名称 | 步骤 | 断言 |
|---------|------|------|------|
| A1 | save_load_roundtrip | mock Prefs，`save` → `load` | 字段完全一致 |
| A2 | cache_key_stable | 相同 `TypesetMeasureParams` 两次 | `cacheKey` 相等 |
| A3 | cache_key_font_change | 仅 `fontSize` 不同 | `cacheKey` 不等 |
| A4 | corrupt_json_returns_null | 存非法 JSON | `load` → null，不 throw |
| A5 | missing_fields_use_defaults | JSON 无 `effectiveLineWidthRatio` | `fromJson` → 0.97 |

Mock：复用 [`chapter_load_orchestrator_test.dart`](../../../test/features/reader/core/application/chapter_load_orchestrator_test.dart) 的 `_MockPrefs` 模式。

#### 文件：扩展 [`typeset_calibrator_test.dart`](../../../test/features/reader/typeset_calibrator_test.dart)

| 用例 ID | 名称 | 断言 |
|---------|------|------|
| A6 | resolveLayoutCalibration_cache_hit | 预写 Prefs，`resolve` 不调 measure（spy 或计数） |
| A7 | defaultCalibrationData_line_height | `lineHeightDp == fontSize * lineHeight` |
| A8 | estimateRustMaxLineWidth_uses_ratio | ratio=0.98 → width = pageW×0.98 |
| A9 | calibrationDrift_ratio | ratio 漂移 >3% → `calibrationDriftExceeds` true |

A6 实现提示：将 `measureLayoutFingerprint` 提取为 injectable 或仅在 cache miss 路径打 log；测试中 pref-seed 后断言无 `[LayoutCalib] measure complete`（或通过返回值 vs 预置值）。

---

### 4.2 Layer B — Rust 单元测试

#### 文件：[`block_paginator.rs`](../../../rust/src/text/block_paginator.rs) `mod tests`

| 用例 ID | 名称 | 设置 | 断言 |
|---------|------|------|------|
| B1 | effective_ratio_sets_line_width | `page_width=1000`, ratio=0.976 | `full_line_w=976`（通过 paginate 日志或 package-visible helper） |
| B2 | measured_line_height_overrides | `measured_line_height_px=72`, font=48, lsp=1.5 | 每页行数按 72px 计，非 72=48×1.5 |
| B3 | wider_ratio_more_chars_per_page | 同 IR，ratio 0.99 vs 0.97 | 0.99 配置的首页 `plain_len` ≥ 0.97（或总页数更少） |
| B4 | default_ratio_fallback | calibration=None | 等价于 ratio=0.97 |

实现提示：可新增 package 内测试 helper：

```rust
#[cfg(test)]
pub(crate) fn block_layout_metrics_for_test(config: &TypesetConfig) -> (f32, f32) {
    let m = BlockLayoutMetrics::from_config(config);
    (m.full_line_width_px, m.line_height_px)
}
```

或将 `BlockLayoutMetrics::from_config` 改为 `pub(crate)` 仅供测试。

---

### 4.3 Layer C — 跨层行数对齐（核心 CI 门禁）

#### 文件：`test/features/reader/data/layout_fingerprint_alignment_test.dart`（新建）

**依赖**：`flutter_test` + `TestWidgetsFlutterBinding.ensureInitialized()`

**公共 fixture**

```dart
const _sampleCjk = '这是一段用于验收统一测量指纹的中文文本。'
    '包含足够长度以产生多行断行，用于对比 Rust 估算与 TextPainter 实际行数。'
    'End.';
const _viewportW = 328.0; // (360-32) dp
const _params = TypesetMeasureParams(
  width: 360, height: 640, pagePadding: 16,
  fontSize: 16, lineHeight: 1.5, letterSpacing: 0,
  fontFamily: 'Roboto', devicePixelRatio: 1.0,
  contentVerticalPadding: 20,
);
```

| 用例 ID | 名称 | 逻辑 | 断言 |
|---------|------|------|------|
| C1 | fingerprint_vs_textpainter_lines | `measureLayoutFingerprint` → `estimateRustLinesForText` vs `_measureSliceLayout` 同宽 | `\|delta\| ≤ 1` |
| C2 | ratio_affects_line_count | 人工设 ratio=0.97 vs 0.99 两个 CalibrationData | 0.99 时 `estimateRustLinesForText` 行数 ≤ 0.97 |
| C3 | indent_increases_lines | `applyFirstLineIndent: true/false` | indent 版行数 ≥ 无 indent |
| C4 | buildTypesetConfig_passes_ratio_to_rust | `buildTypesetConfig(calibration: fp)` | `config.calibration!.effectiveLineWidthRatio == fp.effectiveLineWidthRatio` |

**C1 详细算法**（复用 [`block_page_content.dart`](../../../lib/features/reader/rendering/block_page_content.dart) `_measureSliceLayout` — 建议提取到 `typeset_calibrator.dart` 或 `layout_measure_utils.dart` 供测试与诊断共用）：

```
rustLines = estimateRustLinesForText(
  text, applyFirstLineIndent: true,
  cjkWidthPx: fp.cjkWidth * dpr,
  pageWidthPx: pageWidthPx,
  fontSizePx: fontSizePx,
  effectiveLineWidthRatio: fp.effectiveLineWidthRatio,
)
flutLines = _measureSliceLayout(...).lines
expect((flutLines - rustLines).abs(), lessThanOrEqualTo(1))
```

---

### 4.4 Layer D — Widget overflow 测试

#### 文件：`test/features/reader/rendering/block_page_overflow_test.dart`（新建）

| 用例 ID | 名称 | 构造 | 断言 |
|---------|------|------|------|
| D1 | column_within_viewport | 3 个 `PageBlockSlice` 纯文本，`PaginatedPageViewport(maxHeight: 400)` | 外层 `RenderBox.size.height ≤ 400.5` |
| D2 | single_long_slice | 单 slice 500 字 CJK | 同上（验证 overflow 可检测 — 若 FAIL 则 height > max） |

**注意**：此测试验证**渲染几何**，不验证 Rust 分页正确性；与 C 层互补。

**探针实现**

```dart
final box = tester.renderObject(find.byType(PaginatedPageViewport)) as RenderBox;
expect(box.size.height, lessThanOrEqualTo(maxHeight + 0.5));
```

或使用 `tester.getSize(find.byType(Column))` 对比 viewport。

---

### 4.5 Layer E — Orchestrator 时序（G6）

#### 文件：扩展 [`chapter_load_orchestrator_test.dart`](../../../test/features/reader/core/application/chapter_load_orchestrator_test.dart)

当前文件注释 L8–9 说明完整 pipeline 难测。阶段 6 **不测完整 paginate**，只测调用顺序：

| 用例 ID | 名称 | 方法 |
|---------|------|------|
| E1 | calibration_before_paginate | Mock：`resolveLayoutCalibration` 与 `paginateFirstScreen` 用 `CallOrder` 记录；或抽取 `_runCalibratedPartialPaginate` 为可测单元 |

**替代方案（推荐）**：新建纯函数测试文件 `test/features/reader/data/resolve_layout_calibration_test.dart`，只测 cache/store/measure 集成，orchestrator 时序靠 **日志审查清单**（§6.4）手动/集成验证。

---

## 5. 阶段 6.3：日志验收协议

### 5.1 首屏加载日志顺序（必须）

```
1. [LayoutCalib] cache hit | measure complete
2. [LineWidthCalib] single=... ratio=0.XXX        (仅 miss 时)
3. [FirstLoad] ... calibration ready calib=true
4. [PageEstimate] buildTypesetConfig ... ratio=0.XXX lineH=XXpx estLinesPerPage=XX
5. [PageEstimate] BlockLayoutMetrics ... full_line_w=XXXpx line_h=XX
6. [LineWidth] ... ratio=0.XXX                     (与 4 一致)
7. [LineBreak] TOTAL ... overflow=0.0 flutLines=XX rustEstLines=XX
```

### 5.2 二次冷启动（缓存）

```
1. [LayoutCalib] cache hit key=layout_calib_v1_XXXX
2. 无 [LayoutCalib] measure complete
3. 其余同 5.1
```

### 5.3 FAIL 日志模式

| 日志 | 含义 |
|------|------|
| `overflow=12.0` | 主 FAIL |
| `flutLines=25 rustEstLines=22` 且 overflow>0 | 诊断 ratio/字宽仍偏宽 |
| `flutLines=22 rustEstLines=25` 且 overflow>0 | 页高/行高问题 |
| `ratio=0.970` 但 measure 应得 0.976 | fingerprint 未传入 paginate（时序 FAIL） |
| `calibrateSafely: CJK width ratio out of range` | 字体未就绪，fallback default |

---

## 6. 阶段 6.4：手动回归矩阵

| ID | 场景 | 步骤 | 通过标准 | 记录字段 |
|----|------|------|----------|----------|
| M1 | 纯中文长章 | 默认设置，翻 20 页 | 无滚动；overflow=0 | `case=cjk_long` |
| M2 | 中英混排 | 找含 English 章节 | `\|flut-rust\|≤1` | `case=mixed` |
| M3 | 含图片 | EPUB 图文章 | 图片页+文本页 overflow=0 | `case=image` |
| M4 | 改字号 | 16→20，观察 repaginate | 新 ratio；overflow=0 | `case=font_size_change` |
| M5 | 换字体 | 系统→自定义 | 重测；cache miss | `case=font_family_change` |
| M6 | 短章 | 1–2 页 | 末页完整 | `case=short_chapter` |
| M7 | 跨章 staging | 末页→下一章首页 | 两页 overflow=0 | `case=staging` |
| M8 | 冷启动缓存 | 杀进程重开 | `cache hit` | `case=cold_start_cache` |

**设备矩阵**：至少 2 台 — DPR=2.0 与 DPR≥3.0。

### check.jsonl 记录格式

写入 [`.trellis/tasks/07-05-fix-page-estimation-overflow/check.jsonl`](check.jsonl)：

```json
{"case":"cjk_long","device":"Pixel_6","dpr":3.0,"fontSize":16,"ratio":0.976,"lineHeightDp":24.0,"overflow_dp":0.0,"flut_lines":22,"rust_est_lines":22,"cache_hit":true,"pass":true,"ts":"2026-07-07"}
```

---

## 7. 阶段 6.5：CI 门禁

### 7.1 合并前命令

```bash
# Rust
cd rust && cargo clippy -- -D warnings && cargo test

# Dart 静态
dart analyze --fatal-infos

# 阶段6测试套件
flutter test test/features/reader/typeset_calibrator_test.dart --print-dtd
flutter test test/features/reader/data/layout_calibration_store_test.dart --print-dtd
flutter test test/features/reader/data/layout_fingerprint_alignment_test.dart --print-dtd
flutter test test/features/reader/rendering/block_page_overflow_test.dart --print-dtd

# FRB（Rust 类型变更时）
flutter_rust_bridge_codegen generate
```

### 7.2 Sign-off 条件（全部满足）

- [ ] Layer A–D 测试全绿
- [ ] G1/G2 诊断对齐已合并
- [ ] 手动矩阵 M1–M8 至少 **8/8 pass**（两台设备合计可复用 case，但 M8 必须测）
- [ ] `check.jsonl` 有 ≥8 条 `pass:true` 记录
- [ ] 高 DPR 设备 `overflow_dp ≤ 0.5`

---

## 8. FAIL 分诊与回退

```
overflow > 0 ?
  ├─ flutLines > rustEstLines + 1
  │     → 行宽/字宽偏宽：查 buildTypesetConfig.calibration.ratio
  │     → 临时：min(ratio, 0.97)
  ├─ flutLines ≈ rustEstLines
  │     → 页高/行高：查 contentVerticalPadding、measuredLineHeightPx
  └─ 仅首章 FAIL
        → 查 resolveLayoutCalibration 是否在 paginate 前完成
        → 查 Bug B：首屏不应依赖 backfeed

ratio ∉ [0.85, 1.0] ?
  → 字体未就绪；resolveLayoutCalibration 应 fallback defaultCalibrationData

cache 不 hit？
  → 查 SharedPreferences key；查 fontSize 等是否每次变
```

**回退开关**（保留管道，禁用实测）：

```dart
// buildTypesetConfig 内一行兜底
final lineWidthRatio = min(measuredRatio, kDefaultEffectiveLineWidthRatio);
```

---

## 9. 实施顺序与工作量

| 步骤 | 内容 | 估时 | 依赖 |
|------|------|------|------|
| 6.1 | G1/G2 诊断对齐 | 2h | — |
| 6.2a | A: store + calibrator 扩展测试 | 2h | — |
| 6.2b | B: Rust ratio 测试 | 1.5h | — |
| 6.2c | C: alignment 测试 + 提取 `_measureSliceLayout` | 3h | 6.1 可选 |
| 6.2d | D: widget overflow 测试 | 2h | — |
| 6.3 | 日志协议 + 真机跑 M1–M8 | 3h | 6.1 |
| 6.4 | check.jsonl + sign-off | 1h | 6.3 |

**合计**：约 1–1.5 人日（不含 Layer E 集成测试）。

---

## 10. 与旧 implement.md 的关系

| 文档 | 范围 |
|------|------|
| [`implement.md`](implement.md) | 原「行宽 ratio 管道」方案（已被统一测量 supersede） |
| **本文 phase6-verification.md** | 统一测量阶段 1–5 的验收；**不重复**实现细节 |
| [`prd.md`](prd.md) | 页高 vPad 问题（已在 buildTypesetConfig 修复）；阶段 6 用 overflow 指标覆盖 |

阶段 6 完成后，更新 `task.json` status → `completed`，并在 `implement.md` 顶部加一行：`Superseded by unified measurement + phase6-verification.md`.

---

## 11. 附录：关键代码锚点

| 符号 | 位置 |
|------|------|
| `measureLayoutFingerprint` | `typeset_calibrator.dart` ~L215 |
| `resolveLayoutCalibration` | `typeset_calibrator.dart` ~L278 |
| `LayoutCalibrationStore.cacheKey` | `layout_calibration_store.dart` ~L12 |
| `calibration_line_height_px` | `block_paginator.rs` ~L21 |
| `full_line_width_px` | `block_paginator.rs` ~L70 |
| `[LineBreak] TOTAL` | `block_page_content.dart` ~L141 |
| `resolveLayoutCalibration` 调用 | `chapter_load_orchestrator.dart` ~L142 |
