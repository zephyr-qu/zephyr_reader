# 核心阅读链路审计报告

> 初版日期: 2026-06-17 · 方法: 逐文件阅读 Rust + Dart 源码，交叉比对 plan 文档与 deviance 记录
> **复核日期: 2026-07-02** — 标注已修复项、更新存储架构变更、标注仍开放 bug

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

### ✅ 2. STREAMER_CACHE 容量=4 → 已修复（2026-07-02 确认）

原 `STREAMER_CACHE` (LruCache, capacity=4) 已在 Phase 2.5 合并为 `PaginationStore`，容量升级为 `PAGINATION_ENGINE_CACHE_CAPACITY = 16`（`rust/src/reading/pagination_store.rs:31`）。存储对象也从单一 `PageStreamer` 变为统一的 `PaginationEngine`（含 `Plain` / `Block` 两种引擎）。

**原竞争场景**（容量=4 时易 evict）已缓解。16 slot 可容纳主章 + staging + 跳章 + 配置变更共处。

### 3. 两套并行分页 API，路径不统一（部分改善）

| 路径 | API | Rust 状态 | 用途 |
|------|-----|----------|------|
| Path-based | `paginate_chapter` + `get_page_content` | engine in PaginationStore, handle-less | staging 预加载中取首页内容 |
| Handle-based | `create_pagination_session` + `get_session_page_content` | engine in SESSION_MAP + PaginationStore | 主阅读流程 |

**改善（2026-07-02）**: 存储层已统一为 `PaginationStore`，path-based 和 handle-based 共享同一 LRU，不再有双缓存层不一致问题。

**仍存在的问题点**:
- `preloadNextChapterStaging` 用 path-based `paginateChapter` + `getPageContent` 获取 staging 首页，不走 session
- `get_page_content` (path-based) **cache miss 时返回空字符串**，无错误信号

**建议**: staging 预加载也走 `create_pagination_session`，统一为 handle-based。

### 4. 滚动跨章接缝: 大部分已接入（2026-07-02 确认）

**已实现**:
- `ScrollChapterSegment` 数据模型 ✅
- `ScrollDocumentComposer` (append/prepend/trim 滑动窗口) ✅
- `ScrollModeRenderer._buildMultiSegmentPlainList` (多段 ListView) ✅
- `ScrollBoundaryCoordinator` (appendNext/prependPrev/onSegmentChanged) ✅
- 滚动边界检测触发 append/prepend — `reader_content.dart` 中 `onScrollAppendNext` / `onScrollPrependPrev` 已接入 coordinator ✅
- 滚动进度映射 — `reportScrollPosition` → `charOffsetAtOffset` → `(chapterIndex, charOffset)` ✅
- `onSegmentChanged` 自动触发章界切换 ✅

**仍待完善**:
- EPUB 富文本/竖排 segment 支持
- 预加载复用（staging 的 preloaded content 被 scroll 模式复用）
- 高亮 offset 跨章冲突（P1 bug #2）

**影响**: 滚动模式跨章基本功能已就绪，但 EPUB rich text 跨章和高亮偏移仍有缺口。

### ✅ 5. Dart 侧 `PaginationEngine.paginateApproximate` 后备路径 — 已移除

原 `@Deprecated` 的 `paginateApproximate` 方法已从代码库移除，`ReaderRepositoryInterface` 无此接口。Dart 侧不再有 `TextPainter` 后备分页路径，分页完全依赖 Rust `PageStreamer` + `PaginationSession`。

---

## 三、中等问题 (P2) — 2026-07-02 复核

### 6. Doc 注释与常量不一致（仍开放）

```rust
// pagination.rs:125-127
/// 懒加载模式字符数阈值（50K 字符）  ← 注释说 50K
const LAZY_PAGINATION_CHAR_THRESHOLD: usize = 200_000;  // 实际 200K
```

### 7. 多段滚动 + 高亮 char offset 语义冲突（仍开放）

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

### 9. Session 生命周期: dispose 后 PaginationStore 残留语义不精确（改善但仍存在）

```rust
// core.rs:333 — 2026-07-02 状态
PaginationStore::global().evict(&entry.cache_key());
SESSION_MAP.lock().remove(&handle.session_id);
```

旧 `STREAMER_CACHE.pop(&streamer_key)` → 新 `PaginationStore.evict(&entry.cache_key())`，使用 session entry 的具体 key 而非通用 streamer key，语义更精确。

但仍存在边缘场景：若 `create_pagination_session` 之后、`dispose` 之前，PaginationStore 中的同一 key 被新请求覆盖 (LRU evict)，dispose 时 evict 的对象可能已不是原 engine。这不会造成内存泄漏（原来的已因 LRU evict 被 drop），但**语义不精确**。

---

## 四、已修复 (2026-07-02 确认)

| 问题 | 修复方式 | 验证状态 |
|------|---------|---------|
| Bug A — 跨章错误重试覆盖信号 | stagingPromote 路径跳过冗余 `loadChapterContent`；catch 块增加保护 | ✅ dart analyze |
| Bug B — 翻页排版跳变 | `_syncPaginationSignalsAfterRepaginate` 使用当前 charOffset | ✅ dart analyze |
| EPUB full paginate 用 spine index 当 byte offset | `paginate_chapter` 中 EPUB 路径改为 `read_text_range(0, content_len)` | ✅ 182 tests pass |
| EPUB partial 字符语义 (byte→char) | `get_chapter_partial` EPUB 分支统一 char-take | ✅ 182 tests pass |
| `enableHyphenation` 死代码 | 删除 signal + dispose + rust 桥接 | ✅ dart analyze 0 |
| TOC href fallback → 全部 collapse 到 0 | 按 spine 长度顺序分布 | ✅ |
| 超大单 spine 无检测 | 新增 `ChapterTooLarge` / `StaleBookData` error variant | ✅ |
| `stagingReady` 门控防止空白跨章页 | `extendedTotal` 基于 `stagingReady` 而非 `hasNext` | ✅ |
| EPUB 导入 `file_size: 0` | `parse_book` 现使用 `std::fs::metadata` 获取真实大小 | ✅ |
| STREAMER_CACHE 容量=4 | `PaginationStore` 容量升为 16 | ✅ cargo check |
| `PaginationEngine.paginateApproximate` 后备 | 从代码库移除 | ✅ |
| `dispose_pagination_session` async → sync | 添加 `#[frb(sync)]` | ✅ FRB 重新生成 |
| 模式切换 session 未 dispose | `setReadingMode` 非 pagination 前调 `disposePagination()` | ✅ |

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

### 双缓存层: Rust LRU + Dart PageContentCache（改善）

- **Rust** `PaginationStore` (LruCache, capacity=16): 按 (path, chapter, config_hash) 缓存 `PaginationEngine`（含 Plain streamer / Block state）
- **Dart** `PageContentCache` (per-session, capacity ~7 by `trimAround`): 按 page_index 缓存单页 `String`
- Session dispose 时两处都清理，`PaginationStore.evict(&entry.cache_key())` 比旧 `pop` 更精确

**风险**: 切换书籍时，旧书的 engine 仍在 PaginationStore 中，直到被新书 evict。若旧书是大文件 (100MB+)，内存占用持续到 LRU 驱逐。

---

## 六、验证清单

- [ ] `u64 config_hash` 全程使用 — 搜索 `toInt()` 调用，确认无跨系统持久化截断
- [ ] STREAMER_CACHE 容量压力测试 — 快速翻页 10+ 章，确认无空白页
- [ ] 滚动模式跨章 — 两章 TXT 来回滚动，确认无硬底/跳顶、高亮不偏移
- [ ] pageTurn 后退 — prevChapterStaging 末页渲染
- [ ] PDF 阅读 UI — Dart 侧接线 (Rust `get_pdf_page` 已完成)
- [ ] 排版重载后 `is_partial` 更新 — config 变更 → repaginate → descriptors 更新 → partial flag 正确

---

## 七、总结（2026-07-02 复核）

核心阅读链路**功能完整** (覆盖率 ~90%)，Bug A/B 已修复，存储层统一升级，Dart 后备分页已移除，滚动跨章基本功能已接入。当前仍开放的风险集中在:

1. **u64 hash 截断** (P3 — 当前安全但脆弱)
2. **两套 API 路径存储层已统一但路径仍双轨** (P3 — 维护负担)
3. **滚动跨章高亮 offset 冲突** (P1 — 多章拼接场景)
4. **Block Paginator chunk 边界不考虑图片** (P3 — 大图跨 chunk)

P2 项 (docstring 不一致、WidgetSpan infinity、HighlightPainter stale cache) 不阻塞发布，建议在后续 cleanup 阶段集中处理。
