# 核心阅读链状态与分页 Bug 记录

> 复核日期: 2026-06-17  
> 依据: 当前代码（非历史文档）  
> 关联: [CORE_PIPELINE_REVIEW.md](./CORE_PIPELINE_REVIEW.md)（部分条目已过时，以本文件为准）

---

## 开发版前提（2026-06-17）

**当前为开发版本，不考虑旧数据与脏数据：**

- 书籍均通过**重新导入**写入 DB；`chapters.start_index` / `end_index` 为唯一边界来源。
- EPUB 大章在**导入阶段**按 `MAX_SPINE_ITEMS_PER_CHAPTER=20` 拆章（`toc.rs`）；阅读侧**不再**运行时重算 TOC、不再做 20-spine safety cap、不做 legacy reconcile。
- 若目录与内容不一致，**清库重导**即可，不做迁移脚本或兼容分支。

---

## 分页翻页问题（用户反馈：空白页、第二页重复行、章内来回翻内容不变）

### 根因 1：partial → full 重分页后页缓存未失效（P0，已修）

**现象：** 首屏用 `maxChars=2000` 快速分页，后台 `paginateSessionFull` 扩展全章后，翻页出现空白或内容与页码不对应。

**机制：**

```
createPaginationSession(maxChars=2000)  → descriptors_A + PageContentCache 写入页 0..4
paginateSessionFull()                   → descriptors_B（页界变化）
PageContentCache 仍保留 descriptors_A 的页文本  → 用新页码读旧文本
```

**代码位置：**

- [`lib/features/reader/core/data/rust_pagination_session.dart`](../lib/features/reader/core/data/rust_pagination_session.dart) — `_applyPaginateResult` 原先不清理 `_contentCache`
- `expandToFullChapter` 只预加载 `oldLength..5`，全章重排后页 0 也可能变化却未重拉

**修复（2026-06-17）：**

- `_applyPaginateResult`：descriptors / isPartial / configHash 变化时 `_contentCache.clear()`
- `expandToFullChapter` / `repaginateInPlace`：统一 `_preloadPageRange(5)` 从页 0 重拉

---

### 根因 2：分页模式用 RichParagraph 整段渲染（P0，已修）

**现象：** 第 2 页及之后重复出现第 1 页末尾整段；章内来回翻感觉「一直在同一段」。

**机制：**

Rust `PageStreamer` 按**行**分页，`PageDescriptor.firstParagraphIndex/lastParagraphIndex` 标记的是 plain 文本的段落编号。长段落常跨多页：

```
页 0: 行 0-19  → first_para=0, last_para=0
页 1: 行 20-39 → first_para=0, last_para=0  （仍属同一段落）
```

旧逻辑 [`paginated_renderer.dart`](../lib/features/reader/rendering/paginated_renderer.dart) 用 `richParagraphs.sublist(firstIdx, lastIdx+1)` **整段渲染**，两页都画出完整段落 → 重复。

**修复（2026-06-17）：**

- 分页 / 仿真翻页 **统一走 Rust `getSessionPageContent` 的行切分 plain text**
- 移除 `_buildRichPageContent` 分页路径（滚动模式仍保留 rich）

**后续（未做）：** 若要在分页保留 EPUB 样式/图片，需按 byte offset 对 RichParagraph 做子串切分，不能按段落 index 整段取。

---

### 根因 3：缓存未命中显示空白占位（P1，已修）

**现象：** 快速滑动到未预加载页 → `pageContent == null` → 600px 空白 `SizedBox`。

**位置：** `paginated_renderer.dart` `_buildPageContent`

**修复（2026-06-17）：**

- `ReaderRepository.ensurePageWindow` 完成后递增 `preloadGeneration`，触发 `AnimatedBuilder` 重建
- 缓存 miss 路径显示 `CircularProgressIndicator` + 后帧 `dataSource.ensureWindow` 触发拉取
- `buildSinglePageContent`（仿真翻页）同步处理：spinner 替代纯色背景
- `ReaderRenderDataSource` 新增 `ensureWindow` 抽象方法
---

## 其他核心链路项状态（2026-06-17 复核）

| 条目 | 状态 | 说明 |
|------|------|------|
| EPUB 导入/阅读 spine 边界 | **已统一** | 导入拆章 20 spine；阅读侧 `open_from_bounds` 全量信任 DB |
| 分页高亮错位 | **已修复** | `paintPlain` + `contentStart` |
| 分页选区回调 | **已修复** | `reader_content_area` 已接入 |
| latinExtWidth / padding | **已修复** | `typeset_calibrator.dart` |
| EPUB 阅读重算 TOC、不读 DB 边界 | **已修复** | provider / rich / first_spine 均走 `get_chapter_bounds` |
| Lazy 分页 ≥50K 质量断崖 | **仍开放** | 断页与屏幕渲染偏差 |
| Dart fallback 分页 | **仍开放** | Rust 失败时页数跳变 |
| Sync FFI 取页 | **仍开放** | 冷缓存可能卡顿 |

---

## 验证清单（分页）

- [ ] 打开长章 EPUB，等全章分页完成（日志 `paginateSessionFull`）后翻页 0→1→2，无重复段落
- [ ] 快速首屏后立刻翻页，扩展全章前后页 0 文本一致（不空白、不重复）
- [ ] 纯 TXT 章节翻页，monotonic offset（见 `core_pagination_test.dart`）
- [ ] 仿真翻页模式与左右分页行为一致

---

## 相关测试

- [`test/features/reader/core_pagination_test.dart`](../test/features/reader/core_pagination_test.dart) — `partial session upgrades via paginateSessionFull`
- 建议补充：Dart 层 `expandToFullChapter` 后 cache miss 不返回 stale 文本的 widget/集成测试
