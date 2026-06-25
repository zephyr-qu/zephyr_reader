---
name: P4-3 Staging 零可见 Loading
overview: 实现 ADR-012 — adjacent 跨章时不得展示 CircularProgressIndicator；staging 未就绪则阻塞翻页或展示末页/首页 hold 帧。
todos:
  - id: inventory-spinners
    content: "枚举 paginated_renderer.dart 所有 staging 相关 spinner"
    status: pending
  - id: hold-frame
    content: "MISS 时复用当前章末页/首页 Widget 而非 spinner"
    status: pending
  - id: gate-gesture
    content: "PageView/PageCurl 在 staging 未就绪时禁止翻入虚拟页（可选加强）"
    status: pending
  - id: preload-earlier
    content: "chapter_navigator ensurePrev 阈值或 preload 时机微调"
    status: pending
  - id: tests
    content: "paginated_renderer_test：MISS 不返回 CircularProgressIndicator"
    status: pending
isProject: false
---

# T4 — Staging 零可见 Loading（P4-3）

**参与者任务** · 估时 **1–2d** · ADR [012](../discuss/adr/012-staging-prefetch-guarantee.md) · **与主线程可能碰 `paginated_renderer.dart`**

> 建议：先做 **T5 单测**，再改本任务；或与 Agent 协调合并顺序。

---

## 问题

`paginated_renderer.dart` 在 staging miss 时返回 spinner：

```233:247:lib/features/reader/rendering/paginated_renderer.dart
  Widget _buildPreviousChapterPage(BuildContext context) {
    final staging = dataSource.prevChapterStaging;
    if (staging != null && staging.chapterIndex == chapterId - 1) {
      // ... render staging page
    }
    return const Center(child: CircularProgressIndicator());
  }
```

`_buildCrossChapterPage` MISS 路径同理（约 176 行）。

**决策 D8-C**：用户不得看到上述 spinner。

---

## 策略（按优先级实施）

### 策略 1 — Hold 帧（推荐先做）

| 场景 | MISS 时显示 |
|------|-------------|
| forward 虚拟页（下一章首页） | **当前章最后一页** 的 Widget（冻结画面） |
| backward 虚拟页（上一章末页） | **当前章第一页** 的 Widget |

实现提示：

- 在 `PaginatedModeRenderer` 增加 `Widget? _holdPageWidget` 或在 MISS 分支调用 `_buildPageContent(context, lastRealIndex, …)`
- 后台 `unawaited` 触发 `preloadNextChapterStaging`（若尚未跑）

### 策略 2 — 手势门闸（加强）

- `PageView` / `PageCurlWidget`：`physics: NeverScrollableScrollPhysics()` 当 `!_stagingReadyForNext()` 且用户试图进入虚拟页
- 或 `onReachEnd` 仅在 `stagingReady` 为 true 时调用 `nextChapter`

### 策略 3 — 更早预取（减少 MISS）

文件：`chapter_navigator.dart`

- 确认 `preloadAdjacentFirstPages` 在 **进入章节后** 即调用（不仅 pageIndex≤1）
- `ensurePrevChapterStaging` 条件：当前 `pageIndex <= 2` 改为 `<= 3`（可调，需真机）

---

## 涉及文件

| 文件 | 改动 |
|------|------|
| `lib/features/reader/rendering/paginated_renderer.dart` | 主改动 |
| `lib/features/reader/rendering/page_turn_shell.dart` | pageTurn 皮肤同步 |
| `lib/features/reader/core/application/chapter_navigator.dart` | 预取时机（可选） |
| `test/features/reader/page/widgets/paginated_renderer_test.dart` | 见 T5 |

---

## 验收标准

- [ ] pagination + pageTurn：手动快速连翻 20 次，**无 spinner 闪现**（真机）
- [ ] staging 故意延迟（debug 断点）时显示 hold 帧，不白屏不转圈
- [ ] `dart analyze --fatal-infos` 0 error
- [ ] 现有 `chapter_manager_test` / `paginated_renderer_test` 通过
- [ ] 不违反 I4：promote 后进度仍走 charOffset

---

## 验证命令

```powershell
cd F:\App\zephyr_reader
dart analyze --fatal-infos lib/features/reader/rendering/
flutter test test/features/reader/page/widgets/paginated_renderer_test.dart
```

---

## 与 T1 配合

合并 T1 后，MISS 应极少；若 log 仍大量 `preload_hit=false`，优先调 Step 3 预取，再依赖 hold 帧兜底。
