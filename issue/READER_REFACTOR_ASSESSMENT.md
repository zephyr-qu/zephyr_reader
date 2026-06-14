# 阅读页与 ViewModel 重构评估

> 评估日期：2026-06-14 | 范围：`lib/features/reader/` + `lib/core/reader/`

---

## 当前架构拓扑

```
ReaderPage (552 lines)
  ├─ useReaderBindings(vm) → ReaderPageBindings (40 fields)
  ├─ ReaderContent (external widget)
  ├─ ReaderToolbar
  ├─ ReaderSettingsOverlay (950 lines — 4 panel types)
  ├─ TapZone / SelectionToolbar
  ├─ ReaderNavigationDrawer
  └─ ReaderNoteSidebar
        │
ReaderViewModel (415 lines) — Facade
  ├─ ChapterViewModel (582 lines) — 章节加载/分页/搜索索引/自动滚动
  ├─ ReadingSessionManager (162 lines) — 计时/自动保存
  ├─ BookmarkViewModel (93 lines)
  ├─ AnnotationViewModel (121 lines)
  └─ TranslationViewModel (166 lines)
        │
ReaderRepository (578 lines) — FFI + 缓存 + 3 种分页策略 + 预加载
  └─ PaginationEngine (166 lines) — 纯计算
```

---

## 重构潜力评分

| 模块 | 行数 | 复杂风险 | 重构收益 | 重构风险 | 结论 |
|------|------|----------|----------|----------|------|
| ChapterViewModel | 582 | ⚠️ 高 | 高 | **高** | **可行，需谨慎** |
| ReaderRepository | 578 | ⚠️ 高 | 中 | 中 | 可行 |
| ReaderSettingsOverlay | 950 | ⚠️ 高 | 中 | 低 | **可行** |
| ReaderPage | 552 | ⚠️ 中 | 低 | 中 | 观望（见下） |
| ReaderViewModel | 415 | ✅ 低 | 低 | 低 | **不建议** |
| BookmarkViewModel | 93 | ✅ 低 | — | — | 不动 |
| AnnotationViewModel | 121 | ✅ 低 | — | — | 不动 |
| TranslationViewModel | 166 | ✅ 低 | — | — | 不动 |

---

## 逐模块分析

### 1. ChapterViewModel (582 lines) — 收益高，风险高

**症状**：
- `loadChapter()` 方法 220+ 行，串行编排 5 个阶段：首屏 → 部分分页 → 全文分页 → 回退分页 → 搜索索引
- `_indexForSearch` (FTS5) 不属于章节管理器职责
- 自动滚动逻辑 (`startAutoScroll`/`stopAutoScroll`) 混入，仅用 `autoScrollTick` 信号跟 ReaderContent 通信
- `reset()` 重复清除 14 个信号（机械劳动）

**重构方向**（3 步，可独立提交）：

```
Step 1 — 方法提取（低风险，不改 API）
  loadChapter() 拆为：
    _loadFirstSpine → _loadPartialPagination → _loadFullPagination → _applyFallbackPagination
  每个阶段提为私有方法，参数从字段读取

Step 2 — FTS5 索引提取（中风险）
  _indexForSearch 移入搜索特征（lib/features/search/）
  通过 Repository 或 event bus 触发

Step 3 — AutoScrollController 提取（中风险）
  自动滚动是一个独立功能，应在 ReaderContent 内部管理
  或至少提取到单独的 AutoScrollController 类
```

**风险**：`loadChapter` 包含复杂时序依赖（firstSpine 加载后立即渲染，partial/full 分页并行跑），拆方法时要保证时序不变。建议 Step 1 仅做机械提取，不改变控制流。

**文件变更**：仅改 `chapter_view_model.dart`，不波及外部。

---

### 2. ReaderSettingsOverlay (950 lines) — 收益高，风险低

**症状**：
- 单个 StatelessWidget 根据 `ReaderPanelType` 枚举渲染 4 种完全不同的面板
- 935 行全在一个文件，`build` 方法内大 `switch`
- 参数列表 32 个构造参数（违反 4 参数直觉上限）

**重构方向**：
```
reader_settings_overlay.dart → 降级为 router/switch
typesetting_panel.dart    — 排版面板 (250 lines)
display_panel.dart        — 显示面板 (200 lines)
more_panel.dart           — 更多面板 (300 lines)
tts_panel.dart            — TTS 面板 (150 lines)
```

**风险**：极低。纯 Widget 提取，不涉及业务逻辑。唯一注意是跨面板状态（如 brightnessOverlay）使用 `ReaderConfig` 直接读写，不需要 parent callback 传递。

**文件变更**：新增 4 个文件，旧文件改为 switch-case 到子 widget。

---

### 3. ReaderRepository (578 lines) — 收益中等，风险中

**症状**：
- 5 个职责混合：FFI 加载、3 种分页策略、页面缓存、预加载、进度管理
- `paginateChapterPartial` / `paginateChapter` 各 30+ 参数（`TypesetConfig` 已经存在但未使用）
- `_pageCache` + `currentPages` + `_descriptors` 三套缓存路径，接口混乱

**重构方向**（见 `issue/GOD_CLASS_REFACTOR_PLAN.md` 已有方案）：
```
ReaderRepository — 保持为 Facade
  ├─ 委托给 PaginationEngine（已提取，但方法签名需简化）
  ├─ PageCacheService（新） — 页面缓存
  └─ ChapterContentLoader（新） — 富文本加载/EPUB/MD
```

**API 兼容**：外部调用 `repo.xxx()` 路径不变。

---

### 4. ReaderViewModel (415 lines) — 不建议重构

**现状**：自述 "Facade / 轻量协调层"，实际已拆为 5 个子 VM。23 个 getter 是对子 VM 信号的逐字段暴露（Dart 无属性委托，这是必要的样板代码）。编排逻辑只包含 `initialize()`、`_debounceReloadChapter()`、`createBilingualHighlight()`。

**为什么不动**：
- 从 641 行已减至 415 行，减少 35%
- 样板 getter 无法进一步压缩（Dart 限制）
- 剩余编排逻辑是真正必要的协调

**未来可能**：如果 Dart 增加 property delegation，可减少 getter 样板。目前不建议。

---

### 5. ReaderPage (552 lines) — 建议观望

**症状**：
- `build()` 方法 ~450 行
- 7 处 `useMemoized`/`useState`/`useRef` 局部状态

**为什么不急**：
- 已按区域分解为 `buildContentArea()`、`buildTopToolbar()`、`buildBottomArea()`、`buildSelectionToolbar()`
- `useReaderBindings` 模式将 40 个信号统一成一次绑定调用
- 对比 Flutter 官方复杂页面（如 `flutter_gallery` 中 600+ 行 page），这个量级合理

**何时重构**：当新增功能导致明显增长（>700 行）时，可将 `buildContentArea` 提取为独立 `ReaderContentArea` widget。

---

## 信号暴露耦合评估

### 问题：ReaderViewModel 过度暴露信号 getter

当前模式：
```dart
// reader_view_model.dart
Signal<int> get chapterIndex => chapterManager.chapterIndex;
Signal<String> get bookId => chapterManager.bookId;
// ... 共 23 个 getter
```

所有子 VM 的信号通过 ReaderViewModel 透传。这导致：
1. 调用方知道 VM 内部有 ChapterManager（泄漏实现细节）
2. 每个 getter 增加 VM 的公共 API 表面积

**重构方向**：引入 `ReaderState` 只读聚合对象（类似 `ReaderPageBindings` 但无 UI 耦合）：
```dart
class ReaderState {
  final int chapterIndex;
  final int pageIndex;
  ...
}
// VM 只暴露一个 signal<ReaderState>
```

但需要 signals 的可观察粒度（每个字段独立响应）。现有 binding 模式已经是合理的中间方案——UI 层通过 `useReaderBindings` 批量消费，不需要逐字段绑定。

**结论**：当前模式本质上合理，成本在 Dart 语言的限制。不建议改变。

---

## 测试覆盖分析

| 模块 | 测试文件 | 行数 | 覆盖断言 | 质量 |
|------|----------|------|----------|------|
| ReaderViewModel | reader_view_model_test.dart | 220 | 5 个（翻页边界） | ❌ 严重不足 |
| ChapterViewModel | chapter_manager_test.dart | 741 | 详尽的 mock 注入 | ✅ 好 |
| ReadingSessionManager | reading_session_manager_test.dart | 200 | 各方法时序 | ✅ 好 |

**ReaderViewModel 测试缺口**：`initialize()`、`loadChapter()`、`setReadingMode`(双语模式)、`_debounceReloadChapter`、高亮/批注/书签的代理方法完全无测试。重构前必须补充。

---

## 推荐执行顺序

```
Phase 1（低风险，可独立提交）       Phase 2（中风险）            Phase 3（高风险）
├─ ReaderSettingsOverlay 拆分       ├─ ReaderRepository 拆分    └─ ChapterViewModel 重构
├─ PageCache/Params 提取            └─ 补充 VM 测试              
└─ 补 ReaderViewModel 测试          
```

---

## 总结

| 维度 | 评分 | 说明 |
|------|------|------|
| 架构清晰度 | ⚠️ 中 | Facade 模式正确但 getter 膨胀 |
| 模块化 | ✅ 好 | 5 个子 VM 职责单一 |
| 可测试性 | ⚠️ 中 | 测试覆盖不均衡 |
| 可维护性 | ⚠️ 中 | loadChapter + ReaderRepository 是维护热点 |
| 重构紧迫度 | 🟢 低 | 现有代码可工作，下次修改热点时顺便拆 |

**核心结论**：页面和 VM 已经历过一次大幅重构（从 641 行降至 415 行，提取 3 个子 VM，UI 信号移出）。**当前代码不是阻塞性问题**，但有 2-3 个可优化点。建议在下次修改热点功能时附带重构，不单独立项。
