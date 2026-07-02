# Phase 4 遗留已知 Bug（2026-06-27）

> 2026-06-27 代码审阅 + 动态分析确认。
> 两个 Bug 均不在 Phase 4 当前退出标准阻塞范围内，但影响阅读体验。

---

## Bug A — 跨章导航偶尔弹出「加载失败，重试」

### 现象

跨章节翻页（forward/backward）时，已正常显示的章节内容突然被 **「加载失败，重试」** 错误页覆盖。点击重试后章节恢复正常。

### 根因

**冗余 `loadChapterContent` 调用在后置阶段覆盖信号。**

`ChapterLoadOrchestrator.run()`（`chapter_load_orchestrator.dart`）的编排顺序：

```
line 123  chapterPlainFuture = _contentRepo.loadChapterContent(...)    ← 发起冗余加载
line 139  quickResult = _runQuickPaginateForIntent(...)                ← stagingPromote→UI显示
line 167  await Future.wait([chapterPlainFuture, calibFuture])         ← 等待冗余Future
line 262  catch(e) → _error.value = ... + chapterContent=AsyncState.error  ← 冗余加载失败→覆盖信号
```

**问题细节**：

1. 对于 `stagingPromoteForward/Backward` 意图，`_runStagingPromote` 已通过 Rust session adopt 完成分页并设置 `_error = null`、`_isLoading = false` —— **用户已看到新章内容**。
2. 但 line 123 发起的 `chapterPlainFuture`（`loadChapterContent` → Rust `getChapter`）仍在后台运行。
3. line 167 用 `Future.wait` 等待此冗余请求。若此时 `getChapter` 异常（文件 IO 错误、大章 OOM 等），catch 块**覆盖** `chapterContent` 和 `_error` 信号。
4. 同样是 stagingPromote 路径中，`_runFinalize` line 607-611 的 `isPaginationValid` 检查若因 content 为空而失败，也会触发错误覆盖。

### 影响范围

- 仅 Pagination 模式（`ReadingMode.pagination`）的跨章 adjacent 导航受此影响。
- Scroll/Bilingual 模式走 `_runScrollOrBilingualMode`，其流程无此冗余问题。
- 复现条件：后台 `getChapter` 调用抛异常时触发。在真机上可能因大章文件读取争用、系统 IO 压力大等场景出现。
- 即使冗余调用成功，也存在**不必要的双重 IO**（一次是 session paginate，一次是 getChapter）。

### 关键代码

| 位置 | 行 | 说明 |
|------|----|------|
| `chapter_load_orchestrator.dart` | 123 | 冗余 `loadChapterContent` 发起 |
| `chapter_load_orchestrator.dart` | 139 | stagingPromote 立即成功→用户见内容 |
| `chapter_load_orchestrator.dart` | 167 | 冗余 future 完成（或失败） |
| `chapter_load_orchestrator.dart` | 261-267 | catch 块覆盖 error 信号 |
| `chapter_load_orchestrator.dart` | 607-611 | pagination 验证失败→错误覆盖 |

---

## Bug B — 翻页后当前页排版跳变

### 现象

打开章节阅读后，翻几页（1-5 页），当前页的文本排版突然 **「跳变」**—— 字体大小、行高、每行字数发生变化，页面布局产生可见突变。

### 根因

**分页 `expandToFullChapter` / `repaginateAfterMetricsBackfeed` 在用户可见内容后修改 session 页边界。**

`ChapterLoadOrchestrator.run()` 的时序：

```
line 139  _runCalibratedPartialPaginate → paginateFirstScreen(maxChars=2000)    ← 仅分页前2000字符
          → _isLoading = false, _pageIndex = 0, user sees page 0
line 167  await Future.wait([chapterPlainFuture, calibFuture])                ← 等待内容+校准
line 178   backfeedFuture → _captureMetricsBackfeed                            ← TextPainter采样
line 192   expandToFullChapter (if partial)                                    ← ⚠️ 全章分页
line 215   repaginateAfterMetricsBackfeed (if calibration refined)             ← ⚠️ 用新校准重分页
```

**问题细节**：

1. **首屏快速分页**（line 139）仅分前 2000 字符。`_runCalibratedPartialPaginate` 设置 signals 后用户即看到第 0 页，此时 page descriptors 只覆盖章节开头部分。
2. line 167-168 的 `Future.wait` 是 await 点，**Dart 在此 yield 给事件循环**。若内容加载耗时较长（大章 EPUB rich 转换、DB 读取等），用户可以在这段时间内翻页操作（因为 UI 线程未被 `run()` 完全占用）。
3. line 192 `expandToFullChapter` 调用 `paginate_session_full` 对**整个章节**重新分页。新分页的字符密度/页边界与初始的 2000-char 局部分页不同，导致已渲染页的文本内容改变。
4. line 215 `repaginateAfterMetricsBackfeed` 在 `applySessionCalibration` 后重新分页。校准的 CJK 字符宽度变化使每一页的字符数变化，所有页边界偏移——**排版跳变**。

### 触发条件

- **分页模式**（`ReadingMode.pagination`）下 `normalLoad` 意图（新章打开、进度恢复）。
- 初始分页为 `isPartial = true`（首屏 < 2000 字符）时最明显。
- 若 `_captureMetricsBackfeed` 检测到校准漂移（`calibrationDriftExceeds`），`repaginateAfterMetricsBackfeed` 会改变所有页边界。

### 影响范围

- 分页模式下所有章节首次加载（`normalLoad`）。
- 配置变更（`configReload`）也会触发 backfeed + repaginate，但此时用户已主动感知设置变化。
- 同章内翻页（`expandOnly` intent）不受直接影响（backfeed 已通过 `shouldBackfeed` 门闸隔离）。

### 关键代码

| 位置 | 行 | 说明 |
|------|----|------|
| `chapter_load_orchestrator.dart` | 139 | 仅分页 2000 字符就让用户可见 |
| `chapter_load_orchestrator.dart` | 158 | 注释承认 expandOnly backfeed 导致 Bug B |
| `chapter_load_orchestrator.dart` | 159-164 | `shouldBackfeed` 门闸（已限 normalLoad/configReload） |
| `chapter_load_orchestrator.dart` | 192 | `expandToFullChapter` 全章重分页 |
| `chapter_load_orchestrator.dart` | 215 | `repaginateAfterMetricsBackfeed` 用新校准重分页 |
| `pagination_coordinator.dart` | 138-147 | `repaginateAfterMetricsBackfeed` 实现 |

---

## 修复方向（草案，不承诺实施）

### Bug A

**方案 A**：stagingPromote 路径跳过 `chapterPlainFuture`（或改为只用于搜索索引等非关键路径，且失败不覆盖 error）。

```dart
// 在 Future.wait 前判断：
if (intent == stagingPromoteForward || intent == stagingPromoteBackward) {
  // 不等待 chapterPlainFuture，仅等待 calibFuture
  // 内容已通过 session 可用
}
```

**方案 B**：catch 块增加 intent 判断，stagingPromote 路径忽略 `loadChapterContent` 失败。

### Bug B

**方案 A**：`expandToFullChapter` 和 `repaginateAfterMetricsBackfeed` 完成后保持当前页视觉稳定——记录当前的 `charOffset`，重新映射到新页编号，不做视觉跳跃。

**方案 B**：首屏分页后暂缓 repaginate，**首次翻页时**再进行全章分页+校准回传（此时用户已在翻页过渡中，跳变感知降低）。

**方案 C**：在 `normalLoad` 中先完成内容加载和校准，再做分页，但牺牲首屏速度（与 ADR-013 设计目标冲突）。
