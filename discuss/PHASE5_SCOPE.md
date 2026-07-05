# Phase 5 范围 — 稳定性与工程化（2026-07-03）

> **状态**：进行中
> **绑定**：[READING_BOUNDARIES.md](./READING_BOUNDARIES.md) v1.3 · [ROADMAP.md](./ROADMAP.md) Phase 5
> **前置**：Phase 4 代码全部完成（P4-1～P4-5 + 所有 P1/P2 bug 修复 + P0 架构统一 + 精排 P1/P2 CSS 投射）

---

## 北极星

**Phase 4 已交付完整引擎；Phase 5 的唯一目标是让引擎在真机上可靠运行，并为长期维护打好基础。**

不做功能扩展。不扩 Won't 范围。

> **核心阅读链路真机零缺陷 + 代码可维护性达标。**

---

## 决策汇总

| ID | 问题 | 决策 | ADR |
|----|------|------|-----|
| D1 | Phase 5 主线 | **A** 稳定性+工程化，不做新功能 | — |
| D2 | P3-13 API 路径统一 | **B** Phase 5 执行（ADR-014） | [014](./adr/014-api-path-unification.md) |
| D3 | catch(_) 吞错 | **A** 全部改为 catch(e) + Logging | — |
| D4 | 真机测试策略 | **A** 手动真机验收 + 关键路径自动化测试补齐 | — |
| D5 | 纯文本书分页走 IR | ✅ Phase 4 P0 已完成 | — |
| D6 | sled 容量上限 | **B** 加 LRU 淘汰上限，非紧急 | — |
| D7 | chapterHasImageBlocks 废弃函数 | **A** Phase 5 清理删除 | — |

---

## Phase 5 backlog（按实施顺序）

### M1 — 可观测性与错误处理

| # | 项 | 验收 |
|---|-----|------|
| 5-1 | 22 处 `catch(_)` 改为 `catch(e) { Logging.error(...) }` | 所有异步 catch 有日志 |
| 5-2 | `scanFolder` 错误列表 push 详情 | 批量导入失败文件名可见 |
| 5-3 | `AnnotationViewModel` 高亮加载失败 → 错误状态提示 | 空列表 ≠ 加载成功 |

### M2 — API 路径统一（ADR-014）

| # | 项 | 验收 |
|---|-----|------|
| 5-4 | path-based → handle-based 统一 | `create_pagination_session(book_id, chapter_index, config)` 替代 `create_pagination_session(file_path, ...)` |
| 5-4a | `NextChapterStaging` 参数从 `file_path` 改为 `book_id` | staging 路径无 path-based pagination 调用 |
| 5-4b | `provider_cache.rs` CacheKey 从 `(path, format)` 改为 `(book_id, format)` | 缓存 key 不含文件路径 |
| 5-4c | 移除 `format_from_file_path` 在分页 API 中的使用 | `chapter_access.rs` 分页路径简化 |
| 5-5 | 删除 `chapterHasImageBlocks` 废弃函数 | 无遗留调用 |
| 5-6 | 删除 `paginate_all_content` / plain sled 残余 | Rust/Dart 两侧无 plain 分页路径 |

### M3 — 测试补齐

| # | 项 | 验收 |
|---|-----|------|
| 5-7 | `ChapterLoadOrchestrator` 单元测试 | expand/rebuild/dispose 并发场景有断言 |
| 5-7b | `NextChapterStaging` 单元测试 | M2 改 `book_id` 参数后 staging 预取/提升链路正常 |
| 5-8 | `PaginationCoordinator` 单元测试 | configHash 一致性 + generation gate 验证 |
| 5-9 | `RustPaginationSession` 生命周期测试 | create/expand/dispose 链路有断言 |
| 5-9b | `_Semaphore` 单元测试 | acquire/release 正反场景覆盖（M4 重构前建立基线） |
| 5-10 | `CharWidthTable` 独立测试 | CJK/Latin/标点宽度表验证 |

### M4 — 小清理

| # | 项 | 验收 |
|---|-----|------|
| 5-11 | `BookStatus` 默认值统一 | Rust Default = Planned，与 SQL DEFAULT 一致 |
| 5-12 | `paragraphSpacing` 语义标注 | Rust 字段文档标注 `倍数` vs Dart `dp` |
| 5-13 | `_Semaphore` 递归改循环 | `acquire` 不允许递归调用 |
| 5-14 | sled 容量上限 | `PROVIDER_CACHE` / `STREAMER_CACHE` 加 `nonzero_max` |

### M5 — 真机签退（收尾验收）

> Phase 5 所有改动完成后才执行真机验收，避免"验完又改"的循环。

| # | 项 | 验收 |
|---|-----|------|
| 5-0 | 真机验收跨章 forward/backward | 无可见 spinner/骨架屏闪烁 |
| 5-0b | 真机验收字号/行距调节→分页重建 | 内容不跳变 |
| 5-0c | 真机验收 EPUB 插图双模式 | scroll/pagination 图片正常 |
| 5-0d | 真机验收双语段落样式 | 缩进+段间距+对齐正确 |
| 5-0e | `cargo clippy -- -D warnings` + `dart analyze --fatal-infos` | 零报 |

---

## 不在 Phase 5

| 项 | 原因 |
|----|------|
| 新功能（进度条重建、多色高亮、翻页动画等） | 不扩 Won't；Phase 5 只做稳定性 |
| PDF 阅读 / Markdown 阅读 | Won't（READING_BOUNDARIES v1.2） |
| 账号/多端同步 | Won't |
| 章内搜索 UI | Won't |
| Rust CancellationToken | Won't |
| CJK 标点挤压引擎 | Won't |
| 竖排模式 / 自定义 CSS / 横屏双栏 | Should 但不阻塞，Phase 6 按需 |

---

## 不变量（Phase 5 新增）

在 [DOMAIN_MODEL.md](./DOMAIN_MODEL.md) §3 + Phase 4 I6/I7 基础上：

- **I8**：所有 `catch(_)` 必须有 `Logging` 输出；不得静默吞错。
- **I9**：分页 API 统一为 handle-based（ADR-014）；path-based 路径不得新增调用点。

---

## 退出标准

- [ ] 22 处 catch(_) → catch(e) + Logging 全完成（M1）
- [ ] ADR-014 执行完毕（M2）
- [ ] M3 六项测试全部通过（Orchestrator + NextChapterStaging + Coordinator + Session + _Semaphore + CharWidthTable）
- [ ] 废弃函数清理完成（M4）
- [ ] 真机验收全绿（M5 收尾）
- [ ] `cargo clippy -- -D warnings` + `dart analyze --fatal-infos` 零报
- [ ] 无遗留废弃函数（chapterHasImageBlocks、paginate_all_content）

---

## 相关文档

- [KNOWN_POSTPHASE4_BUGS.md](../issue/KNOWN_POSTPHASE4_BUGS.md) — Phase 4 遗留 bug 全部已修复
- [FINE_TYPESETTING_GAP.md](../issue/FINE_TYPESETTING_GAP.md) — P1/P2 已完成
- [READING_CORE_GAP_ANALYSIS.md](../issue/READING_CORE_GAP_ANALYSIS.md) — 功能差距全景（Phase 6 参考）
- [CORE_PIPELINE_REVIEW.md](../issue/CORE_PIPELINE_REVIEW.md) — 链路审查（MD/PDF 引用已清理）
