# P0 修复计划：paragraphSpacing + Scroll 分页白跑

> 基于 [分模式审查报告] 的 P0 项

---

## Fix 1: paragraphSpacing 双重乘法

### 1.1 问题

**链路**:

```
用户 paragraphSpacing=16dp, fontSize=16dp, lineHeight=1.6
  → Dart buildTypesetConfig: 16/16 = 1.0      (dp → font-size 倍率)
  → Rust new_eager L266: (1.0 * 1.6).round() = 2 个空白行   ← BUG!
  → line_height = 16*1.6 = 25.6px, gap = 2*25.6 = 51.2px
  → 用户期望 ~16dp (≈16px), 实际 51.2px = 3.2× 过量
```

**根因**: `new_eager` L266 `(config.paragraph_spacing * line_spacing).round()` — Dart 侧已经把 dp 转为 font-size 倍率，Rust 不该再乘 `line_spacing`。

### 1.2 修复

**单文件单行修改** `rust/src/text/pagination.rs:266`:

```rust
// 当前（错误）
let spacer_lines = (config.paragraph_spacing * line_spacing).round() as usize;

// 修复
let spacer_lines = config.paragraph_spacing.round() as usize;
```

### 1.3 修复后效果 (默认值)

| 阶段 | 公式 | 结果 | 物理 px | 逻辑 dp |
|------|------|------|---------|---------|
| 修复前 | `(1.0 * 1.6).round()` | 2 空行 | 51.2 | 25.6 |
| 修复后 | `1.0.round()` | 1 空行 | 25.6 | 12.8 |

⚠️ 修复后 gap=25.6px 仍略大于用户意图的 16dp (=32px @2x → gap=25.6px vs 期望 32px)，因为段落间距只能以**整行**为单位。未来可升级为像素级间距，当前这是正确且保守的 1 行间距。

### 1.4 影响面

- **仅影响 `PageStreamer::new_eager`** 中的段落间距计算
- `new_lazy` 不做行拆分，不受影响
- `paginate_all` 使用 `PageStreamer::new`，**一并修复**
- `TypesetConfig` 结构体不变，字段语义不变，config_hash 不变
- KV cache 兼容（config_hash 相同，缓存未失效）

### 1.5 未改动文件

- `lib/features/reader/data/typeset_calibrator.dart` — `buildTypesetConfig` 保持 `(paragraphSpacing / fontSize).clamp(0.0, 10.0)`
- `rust/src/domain/types/typeset.rs` — `TypesetConfig` struct 不变
- `lib/features/reader/domain/config/reader_config.dart` — 默认值 16dp 不变

### 1.6 验证

1. `cargo test -p zephyr_reader pagination` — 确认全量测试通过
2. 手动：打开任意 TXT/EPUB 章节，默认配置下段间距应显著缩小（从~2行降至~1行）

---

## Fix 2: Scroll / Bilingual 模式首屏分页白跑

### 2.1 问题

`ChapterLoadOrchestrator.run()` 对所有 readingMode 执行完整分页 pipeline：

```
scroll 模式加载单章:
  1. resolveIntent() → normalLoad (无 session, 始终如此)
  2. _runFirstSpine
     → loadChapterFirstSpine (提取首 spine, ~10ms)
     → paginateFirstScreen(chapterIndex)  ← FFI: create session + paginate 2000 chars, ~50-100ms
  3. expandToFullChapter                  ← FFI: 全文排版, ~100-500ms (大章)
  4. _runFinalize                         ← 写 totalPages/pageIndex (scroll 不使用)
  5. _contentRepo.ensurePageWindow         ← 缓存 pageContent (scroll 不使用)

总计白费: ~150-600ms + Rust CPU + 内存分配
```

Bilingual 模式同理。这些结果全被丢弃 — scroll 用 `ScrollDocumentComposer`（按 `\n\n` 分段落），bilingual 用 `BilingualAlignment`。

### 2.2 修复

**在 `ChapterLoadOrchestrator.run()` 中，`resolveIntent` 之后插入模式守卫**:

```dart
// resolveIntent 之后（line 96）
if (!_needsPagination(request.readingMode)) {
  await _runScrollOrBilingualMode(gen, request, contentFuture);
  return;
}
```

**新增方法 `_needsPagination`**:

```dart
static bool _needsPagination(ReadingMode mode) =>
    mode == ReadingMode.pagination || mode == ReadingMode.pageTurn;
```

**新增方法 `_runScrollOrBilingualMode`**:

```dart
Future<void> _runScrollOrBilingualMode(
  int gen,
  ChapterLoadRequest request,
  Future<String> contentFuture,
) async {
  _setPhase(gen, ChapterLoadPhase.starting);

  final content = await contentFuture;
  if (_isStale(gen)) {
    _setPhase(gen, ChapterLoadPhase.cancelled);
    return;
  }

  _applyIfCurrent(gen, () {
    _chapterVM.chapterContent.value = AsyncState.data(content);
    _chapterVM.chapterIndex.value = request.chapterIndex;
    _chapterVM.currentCharOffset.value =
        request.initialCharOffset.clamp(0, content.length);
    _totalPages.value = 1; // scroll/bilingual 无分页页数
    _pageIndex.value = 0;
    _error.value = null;
    _isLoading.value = false;
  });

  _setPhase(gen, ChapterLoadPhase.completed);
  _applyIfCurrent(gen, () {
    _loadPhase.value = ChapterLoadPhase.idle;
  });
}
```

### 2.3 影响面

**涉及文件**:

| 文件 | 改动 | 类型 |
|------|------|------|
| `lib/features/reader/core/application/chapter_load_orchestrator.dart` | +模式守卫 +新方法 | 核心 |

**不**影响 pagination/pageTurn 模式的任何行为。

**节省** (滚动模式每章加载):
- `loadChapterFirstSpine` FFI call (~10ms)
- `paginateFirstScreen` FFI call (~50-100ms)
- `calibrateSafely` (~20-50ms)
- `expandToFullChapter` FFI call (~100-500ms)
- `ensurePageWindow` pageContent 缓存分配
- Rust CPU 排版 (2000 chars 部分 + 全文)

### 2.4 不跳过但应保留的

- `loadChapterContent` — 全文加载，scroll 渲染需要
- Post-load tasks (search index) — `contentFuture.then(_postLoadTasks)` 保持不变

### 2.5 边界情况

| 场景 | 行为 |
|------|------|
| Scroll 模式加载首章 | 跳过 pagination，直接渲染 scroll segments |
| Scroll 模式下切换阅读模式为 pagination | `request.readingMode == pagination` → 走正常分页路径 |
| Scroll 模式加载失败 | contentFuture 异常 → catchError → error signal 更新 |
| Scroll 模式跨章预加载 | `preloadAdjacentFirstPages` 仍会被调用（通过 scroll boundary coordinator） |
| pageTurn 模式 | 走正常分页路径（pageTurn 需要 descriptors + pageContent） |

### 2.6 验证

1. `dart analyze lib/features/reader/core/application/chapter_load_orchestrator.dart` — 0 errors
2. 手动：在 scroll 模式下打开章节，观察日志中不应出现 `paginateFirstScreen`/`expandToFullChapter` 的 timing 日志
3. 手动：在 pagination 模式下切换章节，行为不变（Timing 日志正常出现）
4. 手动：Scroll 模式下翻到章末 → trigger onReachEnd → 自动加载邻章 → 正常渲染

---

## 执行顺序

```
Phase 1: Fix 1 (paragraphSpacing) — 1 行 Rust 改动
Phase 2: Fix 2 (Scroll skip)       — 1 文件 Dart 改动
Phase 3: 验证 — cargo test + dart analyze + 手动冒烟
```
