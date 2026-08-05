# 修复阅读器滚动模式：章节内连续滚动 + 边界顺滑衔接

## Goal

修复 EPUB 阅读器滚动模式被实现成"上下翻页"的问题：当前每滑动一次就跳转一章，章节内部无法连续滚动。目标是把滚动模式恢复为"章节内原生连续滚动 + 章节边界顺滑衔接"，符合用户对滚动阅读（微信读书式）的预期，并严格遵守 Readium 原生 toolkit 的能力边界（跨 spine 不做无缝连续滚动，这是官方确认的限制）。

## 背景（诊断结论，2026-08）

1. **现象**：滚动模式下上滑/下滑一下直接跳到下一章/上一章，章节内内容滚不动 → 用户观感是"左右翻页换成了上下翻页"。
2. **已有正确部分**：`_applyPreferences()` 已把 `EPUBPreferences.scroll = readingMode == scroll` 传给原生，原生链路（FlutterEpubPreferences → EpubReaderFragment.updatePreferences → EpubNavigator.submitPreferences → InvalidateViewPager）完整。
3. **根因 A —— 原生初始化时序**：项目从不调用 `FlutterReadium.setDefaultPreferences()`，`ReadiumReaderWidget` 创建原生 WebView 时 `_scrollMode = _defaultPreferences?.scroll ?? false` → 原生先以**分页模式**创建并加载初始 Locator，viewport ready 后才通过 `setEPUBPreferences(scroll:true)` 切换。Readium 原生用 `InvalidateViewPager` 重建 pager（`EpubNavigatorViewModel.submitPreferences` 内 `needsInvalidation` 分支），重建时机与 Flutter 手势检测互相竞争。
4. **根因 B —— Flutter 手势 hack 喧宾夺主**：`readium_reader_content.dart` 的 `Listener` 在 scroll 模式下记录 pointer down/up，滑动 ≥48px 且 200ms 内 progression 未变就调用 `advanceFromScrollBoundary`/`retreatFromScrollBoundary` → `goToLocator(readingOrder[i±1])` 硬跳章。这个 hack 抢在原生滚动布局生效前把手势消费成跳章，导致章节内不能滚。
5. **硬约束**：Readium Kotlin/Swift 原生 toolkit 不支持跨章节无缝连续滚动（官方 issue #563 / discussion #561）；每个章节是独立可滚动 WebView。ADR-021 第 7 条已接受"章节边界处允许显式资源切换"。因此本任务目标是"章节内真滚动 + 边界顺滑"，不是"整本书一条长流"。

## Requirements

1. 滚动模式下，章节内部必须由原生 WebView 提供连续垂直滚动（`scroll:true` 生效）。
2. 原生 WebView 必须**从创建起就处于正确模式**（scroll 或 pagination），消除"先分页后切换"的时序竞争。
3. 移除/重构 Flutter 层手势跳章 hack（`Listener` + `advanceFromScrollBoundary`/`retreatFromScrollBoundary` + 200ms 检测），滚动边界处理改由原生驱动或更可靠的信号驱动。
4. 章节边界处保留"顺滑衔接"：滚到当前资源末尾，通过原生 `goForward()`/`goBackward()`（原生在 scroll 模式走 `goForwardVertical`/`goBackwardVertical`：滚到底才加载下一章，否则仅内部滚动）衔接，不再用 `goToLocator` 直接硬跳。
5. 分页模式行为不得回归（横向滑动翻页、左右边缘点击、tap 显隐控制栏等）。
6. 阅读进度/Locator 保存、TTS、书签等既有功能不回归。

## 非目标（Out of Scope）

- 整本书无缝连续滚动（跨 spine 一条长流）——原生 Readium 不支持，除非换渲染方案（成本高，另行决策）。
- 修改 `flutter_readium` 插件本身（除非确认插件 bug 必须 patch，需 ADR）。
- 分页模式逻辑重构。

## Acceptance Criteria

- [ ] 真机/模拟器：滚动模式下章节内可连续上下滚动，不会一滑就跳章。
- [ ] 滚动模式下滚到章节末尾，能顺滑进入下一章（原生 goForward 路径）；滚回开头能回上一章。
- [ ] 滚动模式与分页模式互相切换后，原生视图布局正确（不再出现"切过去是分页布局"）。
- [ ] 分页模式回归：左右滑动翻页、tap 显隐控制栏、边缘点击行为不变。
- [ ] 阅读位置恢复（Locator）在两种模式下均正确。
- [ ] `dart analyze --fatal-infos` 0 issue。
- [ ] `flutter test` 全绿（含 readium_view_model_test / readium_reader_content_test 现有用例）。
- [ ] ADR-021 补充滚动模式实现方式的修订记录（若行为契约有变）。

## Notes

- 测试纪律：发现生产代码 bug 只记录，不临时改生产逻辑凑测试。
- 涉及原生时序问题，修改后需在 Android 真机验证（模拟器 WebView 行为可能与真机有差异）。
- 分支：codex-migrate-flutter-readium。
