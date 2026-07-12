# Implement — 方案 2 Spike 执行单

## 顺序（门控：上一步绿再往下）

### P0 — 骨架与门控

- [ ] 1. 加 `kFlutterPaginationSpike`（或 ReaderConfig debug 开关），默认 `false`
- [ ] 2. 建 `lib/features/reader/spike/`：`flutter_block_paginator.dart`、`spike_page.dart`、`spike_pagination_session.dart`
- [ ] 3. Orchestrator / 加载入口：flag 开则旁路 `RustPaginationSession`，走 Spike Session；flag 关原路径

**验证**：flag 关，现有 `typeset_calibrator_test` + 一条章节加载烟测通过。

### P1 — TXT 装箱竖切

- [ ] 4. `getChapterContentIr` → Spike Session 持有 IR
- [ ] 5. `FlutterBlockPaginator.paginate(ir, measureParams)` → `List<SpikePage>`（仅 Text 块）
- [ ] 6. PageView / 现有 pagination shell 绑 Spike 页内容
- [ ] 7. 单元测试：固定文本+固定视口 → 页数稳定、拼接还原全文、无重叠区间

**验证**：AC1–AC2（TXT）；诊断日志 `ok`。

### P2 — 进度

- [ ] 8. `pageIndexAtCharOffset` / 翻页写回 charOffset
- [ ] 9. 字号变更 → 重装箱 → 书签附近恢复

**验证**：AC3。

### P3 — EPUB 图（可选第二刀）

- [ ] 10. Image 块高估 + 独占页
- [ ] 11. 复用现有 epub 图缓存解码

**验证**：一本含图 EPUB 翻页不崩、图可见。

### P4 — 结论

- [ ] 12. 更新 `prd.md` Acceptance + Go/No-Go
- [ ] 13. 若 Go：起草 ADR 草案（取代/修订 006/013）；若 No-Go：冻结分支说明

## 验证命令

```bash
flutter test test/features/reader/typeset_calibrator_test.dart
flutter test test/features/reader/spike/   # 新建后
# flag 关回归（择一现有金路径）
flutter test test/features/reader/core/
```

## 风险文件（少动）

| 文件 | 允许改动 |
|------|----------|
| `chapter_load_orchestrator.dart` | 仅 flag 早退分支 |
| `paginated_renderer.dart` | 仅 spike 数据源切换 |
| `rust/src/text/block_paginator.rs` | **禁止改** |
| `rust/src/reading/session.rs` | **禁止改** |

## Rollback

删 `spike/` + 去掉 flag 分支即可；stage6 基线不受影响。
