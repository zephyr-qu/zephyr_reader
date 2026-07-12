# Implement — 方案三执行单

## 门控原则

- **上一步绿再往下**；T0 已由方案 2 交付（Conditional Go）。
- Phase 5 期间：只允许 explore / flag；**禁止**默认开、禁止删生产 Rust 分页。
- T4 可跳过；不影响 T1–T3 → T5。

## 阶段总览

| 阶段 | 目标 | 依赖 | 产出 |
|------|------|------|------|
| **T0** | 精确分页可行 | — | ✅ [方案 2](../07-12-flutter-side-pagination/prd.md) |
| **T1** | 产品核：session 升格 + 渲染 + 图 | T0 | 正式 Flutter session（仍 flag） |
| **T2** | Staging 精确预装箱 | T1 | ADR-012 路径 |
| **T3** | 大章 isolate / 首屏优先 | T1（可与 T2 并行设计） | S1 性能 |
| **T4** | Rust 粗 Hint（可选） | T1+ | 装饰性页数；默认可跳过 |
| **T5** | ADR-016 接受 + 收敛 | T2+T3+真机 | 主路径切换；废校准 |

---

### T0 — 基线（已完成）

- [x] 方案 2 spike：TXT / 进度 / EPUB 图竖切
- [x] Conditional Go + ADR-016 提案
- [x] flag 默认关

**验证**：`flutter test test/features/reader/flutter_pagination/`

---

### T1 — 产品核（下一实现任务）

- [ ] 1. `spike/` → `lib/features/reader/...` 正式命名（或保留 spike 至 T2 再升格，二选一写进子任务）
- [ ] 2. `FlutterPaginationSession` 对齐现有 `PaginationSession` 接口（orchestrator 可切换）
- [ ] 3. PageView / `paginated_renderer` 绑正式 session
- [ ] 4. Image InlineContain / FullPage 与现网语义对齐 + 测试
- [ ] 5. 字号变更重装箱 + charOffset 恢复（自动化）

**验证**

```bash
flutter test test/features/reader/flutter_pagination/
# 升格后改为正式目录测试
flutter test test/features/reader/core/
```

**Go**：AC 书签 + 图 + flag 关回归。  
**No-Go**：接口缠死 orchestrator，无法灰度为由停。

---

### T2 — Staging

- [ ] 6. 预取相邻章 IR（复用现有 preload 触发点）
- [ ] 7. 后台精确 `paginate`；缓存下一章首页 / 上一章末页
- [ ] 8. promote 接到 Flutter session（不走 Rust adopt）
- [ ] 9. miss 时阻塞手势、不 spinner；打 telemetry

**验证**：真机 forward/backward 跨章无可见 loading；开发 assert miss。

**Go**：ADR-012 行为等价。  
**Conditional**：仅部分机型时延不够 → 加宽预取，不降级粗页。

---

### T3 — 大章

- [ ] 10. 装箱进 `compute` / isolate
- [ ] 11. 首屏优先（覆盖当前 charOffset）再 expand
- [ ] 12. generation 取消过期任务

**验证**：百万字 TXT 样本；订 p95（签退时写死）。

---

### T4 — 粗 Hint（可选，默认跳过）

- [ ] 13. 若需要「约 N 页」UI：Rust 或 Dart 字数估页；标 Hint
- [ ] 14. 契约测试：Hint 不得进入正式 descriptors

**跳过条件**：精确页数装完后展示即可满足 UI。

---

### T5 — 收敛

- [ ] 15. 真机签退清单（TXT + 含图 EPUB + 跨章 + 改字号）
- [ ] 16. ADR-016 → **已接受**；更新 006/013 状态与 `READING_BOUNDARIES`
- [ ] 17. 灰度：默认开 flag → 监控
- [ ] 18. 删除/冻结 `create_pagination_session` / calibration / `store_line_breaks` 生产路径

**验证**：主路径零校准 FFI；flag 关路径可暂留一个版本再删。

---

## 本任务（计划）检查项

- [x] 写 `prd.md` Verdict
- [x] 写 `design.md`
- [x] 写本 `implement.md`
- [x] 回链方案 2 / ADR-016

**下一步**：Phase 5 签退推进期间本任务保持 `planning`；开 T1 时 `task.py start` 或新建 `flutter-pagination-scheme3-t1` 子任务。

## 风险文件（T1+ 实现时）

| 文件 | 约束 |
|------|------|
| `chapter_load_orchestrator.dart` | 仅 session 切换 / staging 交接 |
| `next_chapter_staging.dart` | T2 改预装箱源；勿双真理 |
| `rust/.../block_paginator.rs` | T5 前禁止删；T1–T4 少动 |
| `spike/` | T1 升格前为唯一精确引擎实验源 |

## Rollback

- 任意 Tn：flag 关回 Rust 路径。
- 文档：ADR-016 保持提案/拒绝即可；不必 revert Phase 5 主线。
