---
name: P4 Staging Widget 单测
overview: 为 PaginatedModeRenderer 虚拟页/staging 路径补 Widget 测试，锁定 ADR-012 行为（T4 的前置或并行）。
todos:
  - id: read-existing
    content: "读 paginated_renderer_test.dart 与 mock dataSource 模式"
    status: pending
  - id: test-prev-hit
    content: "hasPreviousChapter + prevStaging 命中 → 非 spinner"
    status: pending
  - id: test-next-hit
    content: "nextStaging 虚拟页命中 → 非 spinner"
    status: pending
  - id: test-miss-contract
    content: "MISS 时断言：当前实现 spinner / T4 后改为 hold 帧"
    status: pending
isProject: false
---

# T5 — `PaginatedModeRenderer` Staging 单测

**参与者任务** · 估时 **1d** · **推荐在 T4 之前或同时开分支**

---

## 现有基础

- `test/features/reader/page/widgets/paginated_renderer_test.dart`
- `chapter_manager_test.dart` 已有 `prevChapterStaging` mock stubs

---

## 新增用例（建议 group 名 `staging virtual pages`）

### 1. `prev staging hit renders content`

- `hasPreviousChapter: true`
- `dataSource.prevChapterStaging` → `NextChapterStaging(chapterIndex: chapterId-1, descriptors: [...])`
- `itemBuilder` index 0（或 pageTurn physical 0）
- **断言**：`find.byType(CircularProgressIndicator)` ** findsNothing **（hit 路径）
- **断言**：存在 `Text` 或 staging 占位 key

### 2. `next staging hit on cross chapter page`

- `hasNextChapter: true`
- `nextChapterStaging` 匹配 `chapterId+1`
- 翻到 `descriptors.length` 虚拟 index
- 同上断言无 spinner

### 3. `staging miss documents current behavior`（T4 前）

- staging null
- **当前**：期望 `findsOneWidget` CircularProgressIndicator
- T4 合并后：**改断言**为 hold 帧（同章末页 Text）

> 用 `skip: 'pending T4'` 或注释标明，避免 T4 改实现后测试红一片。

---

## Mock 要点

```dart
class MockReaderRenderDataSource extends Mock implements ReaderRenderDataSource {}

when(() => dataSource.descriptors).thenReturn([...]);
when(() => dataSource.prevChapterStaging).thenReturn(staging);
when(() => dataSource.preloadGeneration).thenReturn(ValueNotifier(0));
```

参考现有 `paginated_renderer_test.dart` 的 `setUp`。

---

## 验收标准

- [ ] ≥3 个新 test case
- [ ] `flutter test test/features/reader/page/widgets/paginated_renderer_test.dart` 全绿
- [ ] 测试断言绑定**行为**（无 spinner / 有内容），非仅 `pump` 不抛错

---

## 技能参考

项目技能：`.agents/skills/flutter-add-widget-test/SKILL.md`（若需 WidgetTester 模式提醒）
