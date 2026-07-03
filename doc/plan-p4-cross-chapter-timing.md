---
name: P4 跨章 Timing 日志
overview: 为 adjacent 跨章与 staging promote 路径补充统一 [Timing] 日志，便于真机验收 ADR-012（零 loading 前提是可观测）。
todos:
  - id: audit-points
    content: "列出 chapter_navigator / orchestrator / repository preload 现有 Stopwatch 点"
    status: pending
  - id: add-logs
    content: "在 promote / preload hit-miss / 章切换完成 补 [Timing] 行"
    status: pending
  - id: doc-runbook
    content: "在 plan 末尾写真机抓取与通过标准示例"
    status: pending
isProject: false
---

# T1 — 跨章 `[Timing]` 诊断日志

**参与者任务** · 估时 **0.5d** · ADR-012 配套 · **不改行为，只加观测**

---

## 目标

翻章时能在 logcat / IDE 控制台看到一条可读的耗时链，例如：

```
[Timing] cross-chapter forward: preload_hit=true promote_ms=12 total_ms=45
```

用于判断 staging 是否在用户翻到末页**之前**就已就绪。

---

## 范围

### 改这些文件

| 文件 | 动作 |
|------|------|
| `lib/features/reader/core/application/chapter_navigator.dart` | `nextChapter` / `previousChapter` 入口/出口计时 |
| `lib/features/reader/core/application/chapter_load_orchestrator.dart` | `_runStagingPromote` 前后；已有 `[Timing] gen=… intent=…` 可扩展 |
| `lib/features/reader/core/data/rust_chapter_content_repository.dart` | `preloadNextChapterStaging` / `preloadPreviousChapterStaging` hit/miss |
| `lib/features/reader/rendering/paginated_renderer.dart` | `_buildCrossChapterPage` HIT/MISS 时带 `staging_ready` 字段（可选） |

### 不改

- Rust 分页算法
- staging 业务逻辑（本任务 **不加** 阻塞/去 spinner，那是 T4）

---

## 实施步骤

### Step 1 — 审计（30min）

搜索现有日志：

```powershell
rg "\[Timing\]" lib/features/reader/
```

记录已有字段，避免重复命名。

### Step 2 — 统一日志格式（1h）

约定字段（JSON 不必，纯文本即可）：

| 字段 | 含义 |
|------|------|
| `direction` | `forward` / `backward` |
| `chapter_from` / `chapter_to` | int |
| `preload_hit` | bool |
| `intent` | `stagingPromoteForward` 等 |
| `promote_ms` | promote 路径耗时 |
| `total_ms` | 从导航触发到 `loadPhase==idle` |

使用 `Logging.info`（项目已有 `lib/core/utils/logging.dart`）。

### Step 3 — 关键埋点（1h）

1. **Navigator**：`nextChapter(adjacentCrossChapter)` 开始 `Stopwatch`
2. **Resolver**：`resolveChapterPaginationIntent` 返回后 log `intent` + staging hash 是否匹配（可在 orchestrator 已有处扩展）
3. **Repository**：preload 完成时 log `hit`（staging 非 null 且 chapterIndex 正确）
4. **Orchestrator**：`_runStagingPromote` finally 块 log `promote_ms`

### Step 4 — 真机 Runbook（30min）

在本文档末尾追加：

```markdown
## 真机验收
1. `flutter run --print-dtd` 打开含图 EPUB
2. pagination 模式连翻 3 章
3. 过滤 log：`adb logcat | rg Timing`
4. 期望：forward 时 `preload_hit=true` 占多数；`promote_ms < 50`（参考值，非硬门禁）
```

---

## 验收标准

- [ ] 至少 **4 个** 新 `[Timing]` 埋点，覆盖 forward + backward
- [ ] `dart analyze --fatal-infos` 0 error
- [ ] 不引入新依赖
- [ ] PR 描述粘贴 3 行示例 log

---

## 与主线程关系

- 与 P4-1 **无冲突**；可先做
- T4（去 spinner）合并后，用本任务日志验证预取是否够快
