# ADR-014：统一分页 API 路径 — 跨章预加载迁移至 handle-based

- **状态**：已提议（待 Phase 5 执行）
- **日期**：2026-07-02

## 背景

当前 Rust 侧存在两套并行的分页 API：

| 路径 | 入口 | 查页 | 存储 | 稳定性 |
|------|------|------|------|--------|
| **path-based** | `paginate_chapter(fp, chIdx, config, maxChars)` | `get_page_content(fp, chIdx, hash, pgIdx)` | 全局 LRU `PaginationStore`（容量 16） | 多章并发时 LRU 竞争驱逐 |
| **handle-based** | `create_pagination_session(fp, chIdx, config)` → `handle` | `get_session_page_content(handle, pgIdx)` | `SESSION_MAP` + LRU clone-back | session 独占 engine，不被驱逐 |

Dart 侧主链路（`RustPaginationSession`）已走 handle-based，但跨章预加载（`RustChapterContentRepository._buildStaging()`）仍走 path-based：

```dart
// 预加载：path-based
final result = await core_api.paginateChapter(filePath: ..., chapterIndex: ..., config: ..., maxChars: ...);
final pageContent = core_api.getPageContent(filePath: ..., chapterIndex: ..., configHash: ..., pageIndex: 0);
```

这导致预加载章的 engine 进入 LRU 后，可能被当前章翻页时的后续 preload 请求驱逐。staging promote 时若 LRU 已驱逐该 engine，需要重新全量分页，造成换章延迟。

## 决策

1. **跨章预加载迁移至 handle-based**：`preloadNextChapterStaging` / `preloadPreviousChapterStaging` 使用 `create_pagination_session` → `paginateSessionFull` → `get_session_page_content`。
2. **staging promote 复用 handle**：promote 时将预加载章的 session handle 交接给 `RustPaginationSession`，而非重新 `paginateChapter`。
3. **path-based API 标记 deprecated 但保留**：搜索、书签定位等轻量场景仍需要无 session 的单次查页能力，暂不移除。
4. **滚动多章 session 数量上限**：scroll 模式同时持有最多 3 个 session（前一章 + 当前章 + 后一章），`PaginationStore` 容量 16 足够支撑。

## 改动清单

### Rust 侧

| 改动 | 说明 |
|------|------|
| 新增 `adopt_session(file_path, chapter_index, config) → PaginationSessionHandle` | 创建 session 并执行 lazy paginate，供预加载路径使用 |
| `paginateSessionFull(handle, maxChars)` 已存在 | 无需改动 |
| `get_session_page_content(handle, pageIndex)` 已存在 | 无需改动 |
| `get_session_page_blocks(handle, pageIndex)` 已存在 | 无需改动 |
| `dispose_pagination_session(handle)` 已存在 | 无需改动 |

### Dart 侧

| 改动 | 说明 |
|------|------|
| `NextChapterStaging` 增加 `PaginationSessionHandle?` 字段 | 预加载章的 session handle |
| `RustChapterContentRepository._buildStaging()` | 从 `getPageContent` → `getSessionPageContent` |
| `preloadNextChapterStaging` / `preloadPreviousChapterStaging` | 改用 `createPaginationSession` + `paginateSessionFull` |
| `RustPaginationSession.promoteFromStaging(NextChapterStaging)` | 交接 handle，复用已有 engine，跳过重新分页 |
| staging 超时 / 失效清理 | 未被 promote 的 session handle 在 `_stagingGen` 变化或用户切换章节时 dispose |

### 搜索等轻量场景

| 场景 | 是否改用 handle | 说明 |
|------|----------------|------|
| 搜索结果定位到某页 | 不改 | 单次查页，创建 session 再 dispose 反而更重 |
| 书签定位 | 不改 | 同上 |
| scroll 预加载前后章 | **改** | 需稳定持有，避免 LRU 驱逐 |
| pageTurn staging 预加载 | **改** | 同上 |

## 理由

- LRU 驱逐是当前 staging promote 失败后需要重新分页的根因之一（ADR-012 §staging miss → hold frame）。
- handle-based 保证预加载章的 engine 不被驱逐，promote 交接零延迟。
- 统一路径消除 P3-13（两套分页 API 路径不统一）架构债务。
- 保留 path-based 用于轻量单次查询，避免所有场景都引入 session 生命周期管理开销。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| session 生命周期管理变复杂：promote 交接、超时清理、悬空 handle | `_stagingGen` generation 计数器 + `disposePaginationSession` 同步调用；promote 时 `RustPaginationSession` 接管 handle，原 staging 引用置空 |
| scroll 同时持有 3 个 session | `PaginationStore` 容量 16，3 个 session 仅各占 1 个 LRU 位 + 1 个 SESSION_MAP 位，远低于上限 |
| handle 交接时 configHash 不一致 | promote 前检查 `staging.configHash == pagination.computeConfigHash()`，不一致则 dispose 旧 handle 并走 normalLoad |
| Dart 侧 `PaginationSessionHandle` 需要 FRB 绑定传递 | 已有 FRB 绑定（`create_pagination_session` 返回 handle），无需新增 |

## 不做

- 不在本 Phase（Phase 4）执行，列入 Phase 5 架构统一任务。
- 不移除 path-based `paginateChapter` / `getPageContent`（搜索等场景仍需要）。
- 不改变 `PaginationStore` LRU 容量（16 足够）。

## 关联

- [ADR-004](./004-cross-chapter-staging.md)：跨章 staging 保留决策
- [ADR-012](./012-staging-prefetch-guarantee.md)：staging 零可见 loading 保证
- P3-13（[KNOWN_POSTPHASE4_BUGS.md](../../issue/KNOWN_POSTPHASE4_BUGS.md)）：两套分页 API 路径不统一
- [ROADMAP.md](../ROADMAP.md)：Phase 5 架构统一
