# 核心阅读链路审计报告

> 审计日期: 2026-06-17 · 方法: 逐文件阅读 Rust + Dart 源码，交叉比对 plan 文档与 deviance 记录

## 审计范围

```
Rust pagination/layout → API core → FRB bridge →
Dart session/cache → orchestrator → view model → renderer
```

涉及文件: `rust/src/text/pagination.rs`, `rust/src/api/core.rs`, `rust/src/reading/streamer_cache.rs`,
`lib/features/reader/core/data/rust_pagination_session.dart`, `lib/features/reader/core/application/chapter_load_orchestrator.dart`,
`lib/features/reader/core/application/pagination_coordinator.dart`, `lib/features/reader/rendering/scroll_mode_renderer.dart`,
`lib/features/reader/page/widgets/reader_content.dart` 等 30+ 文件。

**xxh3_64 输出是全 64-bit 无符号整数，约 50% 的概率 MSB=1**。`BigInt.toInt()` 将 u64 截断为 signed 64 two's complement:
- `0x8000_0000_0000_0000` → `-9223372036854775808`
- `0xFFFF_FFFF_FFFF_FFFF` → `-1`

**当前影响评估**:
1. **同类比较安全**: Dart 端所有 hash 都经同一 `toInt()` 路径 → `sessionConfigHash == currentHash` 比较正确
2. **Rust 持久缓存不受影响**: `LayoutCacheKey.config_hash: u64` 全程在 Rust 侧，序列化为 `{:016x}` hex
3. **跨系统风险**: 若未来将 hash 序列化到 DB 或 Dart 侧构造 `LayoutCacheKey`，截断会导致 miss

**结论**: 当前**不是活跃 bug**，但属**代码异味**。`int?` 存储 64-bit 无符号值并依赖"两端同截断"是脆弱的。建议存储为 `BigInt` 或 Rust 侧降为 `i64` hash。

**代码**: `rust/src/reading/streamer_cache.rs:19` — `STREAMER_CACHE_CAPACITY = 4`

**竞争场景**:
| 时刻 | STREAMER_CACHE 中的 key |
|------|------------------------|
| 翻到第 5 章 | (book, ch5, hash) ← 主章 streamer |
| staging 预加载 ch6 | (book, ch6, hash) ← put by `paginateChapter` |
| staging 预加载 ch4 | (book, ch4, hash) ← put by `paginateChapter` |
| 同时后台预取 ch7 文本 | 触发 `get_or_create_provider` → **不占 STREAMER_CACHE** ✓ |
| 但若用户快速翻页到 ch3 | (book, ch3, hash) ← 可能 evict ch5 或 ch6 |

当 `paginate_chapter` 被 staging 调用时，它 put streamer 到 STREAMER_CACHE。当前章 + 前/后 staging + 手动跳章 = 极易达到 4。

**缓解**: staging 通过 `createPaginationSessionAdopt` 在 promote 时 adopt，miss 则回退 `createPaginationSession`。miss 场景下失去优化，但**不丢数据**。

**建议**: 增容到 8 或改为 per-book 独立 LRU segment。

### 3. 两套并行分页 API，路径不统一

| 路径 | API | Rust 状态 | 用途 |
|------|-----|----------|------|
| Path-based | `paginate_chapter` + `get_page_content` | streamer in STREAMER_CACHE, handle-less | staging 预加载中取首页内容 |
| Handle-based | `create_pagination_session` + `get_session_page_content` | streamer in SESSION_MAP + STREAMER_CACHE | 主阅读流程 |

**问题点**:
- `preloadNextChapterStaging` 用 path-based `paginateChapter` + `getPageContent` 获取 staging 首页，不走 session
- 主阅读用 `create_pagination_session_adopt` 试图从 STREAMER_CACHE adopt → 依赖 STREAMER_CACHE 未 evict
- `get_page_content` (path-based) **cache miss 时返回空字符串**，无错误信号 (`rust/src/api/core.rs:640-643`)

**建议**: staging 预加载也走 `create_pagination_session`，统一为 handle-based；或在 staging 中直接用 session 的 `getPage` 而非独立 `paginateChapter`。

### 4. 滚动跨章接缝: composer/renderer 就绪，导航/预加载/进度未接入

**已实现** (planf Phase 1 ✅):
- `ScrollChapterSegment` 数据模型
- `ScrollDocumentComposer` (append/prepend/trim 滑动窗口)
- `ScrollModeRenderer._buildMultiSegmentPlainList` (多段 ListView)
- `ScrollBoundaryCoordinator` (appendNext/prependPrev/onSegmentChanged)

**未接入** (planf Phase 2 待做):
- 滚动边界检测触发 append/prepend (reader_content.dart 已有 `onScrollAppendNext`/`onScrollPrependPrev` 回调，但 coordinator 的边界检测逻辑未完整)
- 滚动进度映射 (`scrollOffset` → `(chapterIndex, charOffset)`)
- EPUB 富文本/竖排 segment 支持
- 预加载复用

**影响**: scroll 模式下章末仍有硬底/跳顶，滚动体验不如分页模式流畅。

### 5. Dart 侧 `PaginationEngine.paginateApproximate` 后备路径未清理

**代码**: `lib/features/reader/data/pagination_engine.dart` — 标记 `@Deprecated`，但仍在 `ReaderRepositoryInterface` 接口中

Dart 的 `TextPainter` 宽度计算与 Rust `CharWidthTable` 使用不同的字体度量模型。若 Rust 分页失败触发 Dart 后备，页边界会漂移。当前生产路径不经过此代码，但接口未删除，存在被误调用的风险。

---

## 三、中等问题 (P2)

### 6. Doc 注释与常量不一致

```rust
// pagination.rs:125-127
/// 懒加载模式字符数阈值（50K 字符）  ← 注释说 50K
const LAZY_PAGINATION_CHAR_THRESHOLD: usize = 200_000;  // 实际 200K
```

### 7. 多段滚动 + 高亮 char offset 语义冲突

`ScrollModeRenderer` 在 multi-segment 模式下将多章段落拼接为一个 `ListView`。`HighlightPainter` 使用 per-chapter 的 char offset 定位高亮。当 chN 的 segment 后紧跟 chN+1 的 segment 时，若 chN+1 也有高亮，其 char offset 会错误地指向 chN 的内容位置。

**代码位置**: `scroll_mode_renderer.dart` — segment 无 highlight 字段，`HighlightPainter` 按全局 offset 绘制

**影响**: 仅当用户跨章滚动且相邻章都有高亮时出现。当前多段滚动主要在 plain text 场景，EPUB 高亮暂时仅作用于当前章。

### 8. `PageStreamer.from_pages()` 永久设 `is_partial = false`

```rust
// pagination.rs:167
pub fn from_pages(pages: Vec<PageContent>) -> Self {
    Self {
        // ...
        is_partial: false,  // 硬编码
    }
}
```

KV cache 只保存 `!is_partial` 的全章内容，所以此值正确。但接口语义上，调用方无法表达 "这些 pages 来自 partial 内容"。若未来有 partial-from-cache 场景 (如分段缓存)，会误导。

### 9. Session 生命周期: dispose 后 STREAMER_CACHE 残留

```rust
// core.rs:850-863
pub fn dispose_pagination_session(handle) {
    // pop from STREAMER_CACHE
    STREAMER_CACHE.lock().pop(&streamer_key);
    // remove from SESSION_MAP
    SESSION_MAP.lock().remove(&session_id);
}
```

但如果 `create_pagination_session` 之后、`dispose` 之前，STREAMER_CACHE 中的同一 key 被新请求覆盖 (capacity=4)，dispose 时 pop 的对象已不是原来的 streamer。这不会造成内存泄漏 (原来的已因 LRU evict 被 drop)，但**语义不精确**。

---

## 四、已修复 (之前版本的 bug，确认已解决)

| 问题 | 修复 PR | 验证状态 |
|------|--------|---------|
| EPUB full paginate 用 spine index 当 byte offset | `paginate_chapter` 中 EPUB 路径改为 `read_text_range(0, content_len)` | ✅ 182 tests pass |
| EPUB partial 字符语义 (byte→char) | `get_chapter_partial` EPUB 分支统一 char-take | ✅ 182 tests pass |
| `enableHyphenation` 死代码 | 删除 signal + dispose + rust 桥接 | ✅ dart analyze 0 |
| TOC href fallback → 全部 collapse 到 0 | 按 spine 长度顺序分布 | ✅ |
| 超大单 spine 无检测 | 新增 `ChapterTooLarge` / `StaleBookData` error variant | ✅ |
| `stagingReady` 门控防止空白跨章页 | `extendedTotal` 基于 `stagingReady` 而非 `hasNext` | ✅ |

---

## 五、架构债务

### 5 个子 VM 共享信号，隐式耦合未完全消除

当前状态 (per `READER_ARCH_GOVERNANCE_PHASES.md` Phase 3):

| VM 组件 | 状态 |
|--------|------|
| `ChapterViewModel` | 已独立 ✅ |
| `PaginationCoordinator` | 已独立 ✅ |
| `ChapterLoader` | 已独立 ✅ |
| `ChapterNavigator` | 已独立 ✅ |
| `ChapterLoadOrchestrator` | 编排层 ✅ |
| `ScrollBoundaryCoordinator` | 新增，与 navigator/orchestrator 并行 |

`ChapterViewModel` 仍暴露所有子组件的 signal (chapterIndex, totalPages, pageIndex, isLoading, error, scrollSegments...)，上层 `ReaderViewModel` 通过它代理访问。这不是 bug，但增加了 "谁拥有什么" 的心智负担。Phase 3 DI 注入计划可进一步解耦。

### 双缓存层: Rust LRU + Dart PageContentCache

- **Rust** `STREAMER_CACHE` (LruCache, capacity=4): 按 (path, chapter, config_hash) 缓存 PageStreamer (含完整 content String)
- **Dart** `PageContentCache` (per-session, capacity ~7 by `trimAround`): 按 page_index 缓存单页 `String`
- Session dispose 时两处都清理，但 STREAMER_CACHE 与 session 无绑定关系

**风险**: 切换书籍时，旧书的 streamer 仍在 STREAMER_CACHE 中，直到被新书 evict。若旧书是大文件 (100MB+)，内存占用持续到 LRU 驱逐。

---

## 六、验证清单

- [ ] `u64 config_hash` 全程使用 — 搜索 `toInt()` 调用，确认无跨系统持久化截断
- [ ] STREAMER_CACHE 容量压力测试 — 快速翻页 10+ 章，确认无空白页
- [ ] 滚动模式跨章 — 两章 TXT 来回滚动，确认无硬底/跳顶、高亮不偏移
- [ ] pageTurn 后退 — prevChapterStaging 末页渲染
- [ ] PDF 阅读 UI — Dart 侧接线 (Rust `get_pdf_page` 已完成)
- [ ] 排版重载后 `is_partial` 更新 — config 变更 → repaginate → descriptors 更新 → partial flag 正确

---

## 七、总结

核心阅读链路**功能完整** (覆盖率 ~87%)，近期修复了 EPUB partial char 语义、full paginate byte offset、TOC collapse、stale book detection 等关键 bug。当前主要风险集中在:

1. **u64 hash 截断** (P0 — 当前安全但脆弱)
2. **STREAMER_CACHE 过小** (P1 — 快速翻页时性能退化)
3. **两套 API 路径不统一** (P1 — 维护负担)
4. **滚动跨章未完成** (P1 — 用户体验缺口)

P2 项 (docstring 不一致、双缓存复杂度、API 清理) 不阻塞发布，但建议在滚动跨章完成后统一清理。
