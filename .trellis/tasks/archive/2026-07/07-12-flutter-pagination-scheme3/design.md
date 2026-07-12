# Design — 方案三：Flutter 精确分页 + 性能兜底

## 目标架构

```
┌─────────────────────────────────────────────────────────┐
│  Rust                                                    │
│  EPUB/TXT → ChapterContentIr (+ 图路径/解码)              │
│  API: get_chapter_content_ir(...)                        │
│  （T4 可选）粗页数 / 粗 descriptor → Hint only            │
│  ✗ 不作为正式 PageDescriptor 真理                        │
│  ✗ 无 apply_session_calibration / metrics 写回分页        │
└──────────────────────────┬──────────────────────────────┘
                           │ IR + plainText
                           ▼
┌─────────────────────────────────────────────────────────┐
│  Flutter                                                 │
│  当前章：TextPainter 精确装箱 → PageDescriptor[] → 渲染   │
│  相邻章：同算法后台 isolate 预装箱 → staging 首/末屏      │
│  进度：charOffset ↔ pageIndex；改字号只重装箱本侧         │
└─────────────────────────────────────────────────────────┘
```

## 与方案 1 / 2 的差异

| | 方案 1（现网） | 方案 2（spike） | 方案 3（本设计） |
|---|---|---|---|
| 页真理 | Rust（+ 校准） | Flutter | Flutter |
| 校准环 | 有 | 无 | 无 |
| Staging | Rust session 预取 | 首轮不做 | **同算法精确预装箱** |
| 大章 | Rust 快 | 主 isolate 硬扛 | **isolate / 首屏优先** |
| 粗分页 | 即正式引擎 | 无 | **可选 Hint（T4）** |

方案 3 = 方案 2 真理 + T2/T3（及可选 T4）产品层。

## 硬契约

1. 用户翻到的第 N 页边界，只由 Flutter 精确装箱产生。
2. Rust 粗结果不得写入正式 `PaginationSession` / 不得驱动翻页。
3. 禁止 Flutter→Rust metrics 回传再改页界（ADR-013 路径在毕业后废弃）。
4. 进度持久化仍 ADR-001；staging 页码不持久化（ADR-004）。

## 模块划分

| 模块 | 职责 | 来源 / 路径建议 |
|------|------|-----------------|
| `FlutterBlockPaginator` | IR → pages | 升格自 `spike/flutter_block_paginator.dart` |
| `FlutterPaginationSession` | 持 IR、descriptors、按页切片、offset↔page | 升格自 `flutter_pagination_session.dart` |
| Staging 适配 | 预取相邻章 IR + 后台 `paginate`；缓存首/末屏 | 改 `NextChapterStaging` / orchestrator 交接 |
| Orchestrator | session 实现切换；intent 复用 | 最小侵入；flag → 日后默认 |
| 渲染 | `buildBlockPageContent` 等 | **复用**，不第二套 Widget 树 |
| Rust IR | `get_chapter_content_ir` | 保留；分页 FFI 灰度后删 |

### Flag 策略

| 阶段 | Flag |
|------|------|
| 现网 / Phase 5 | `kFlutterPaginationSpike` 默认 `false` |
| T1–T4 | 可改名 `flutterPaginationEngine`；仍可关回 Rust |
| T5 接受 ADR-016 后 | 默认开 → 删 Rust 分页路径 |

## Staging 设计（T2）

```
用户读章 N
  → 后台：拉 N±1 IR → isolate 精确 paginate
  → 只保留：下一章首页切片 / 上一章末页切片（+ 必要块数据）
到达章界
  → promote：把预装箱结果接到当前 session（非重新走 Rust session）
  → 若未就绪：短暂阻塞手势（ADR-012），不展示 spinner
```

**禁止**：用 Rust 粗页顶 staging 真页（双真理）。

## 大章设计（T3）

1. 装箱默认 `compute` / 专用 isolate。
2. **首屏优先**：先装到覆盖当前 `charOffset` 的页，再续装全章（或按需 expand）。
3. config / 章切换：取消上一代装箱（generation gate，对标现网 `_generation`）。
4. 验收：订设备档位的首屏 p95（真机签退时写死数字）。

## 粗分页 Hint（T4，可选）

| 用途 | 允许 | 禁止 |
|------|------|------|
| 进度条「约 N 页」装饰 | ✓ | 当作正式 pageCount 持久化依据 |
| 预取策略启发 | ✓ | 驱动 PageView 索引 |
| 与精确页差几页 | UI 可接受 | 覆盖精确 descriptors |

**默认建议：T1–T3 完成前不做 T4。** 页数展示可用「精确页数（装完后）」或「字数估算」，不必上 Rust 粗引擎。

## 进度与配置变更

- 持久化：`chapterIndex + charOffset`。
- 字号/行距/边距变：丢弃 session descriptors，重新精确装箱，用 charOffset 定位。
- 无 calibration apply。

## ADR 影响（毕业时）

与 [ADR-016](../../../discuss/adr/016-flutter-pagination-engine-proposed.md) 一致：

- 006：部分取代（分页引擎位置）
- 013：Superseded
- 003 / 004 / 012 / 001：保留语义，实现换皮

## 破损面（分阶段接受）

| 能力 | T1 | T2 | T3 | T5 |
|------|----|----|----|-----|
| TXT 精确翻页 | ✓ | ✓ | ✓ | ✓ |
| EPUB 图 | ✓ | ✓ | ✓ | ✓ |
| Staging 零 loading | — | ✓ | ✓ | ✓ |
| 百万字不卡 | — | — | ✓ | ✓ |
| 删 Rust 分页 | — | — | — | ✓ |
| 粗 Hint | — | — | — | 可选 |

## 成功 / 失败判据

**Go（接受 ADR-016）**：AC1–AC7（见 prd）全绿。  
**Conditional**：T1 绿但 T2/T3 未证 → 继续 explore，不合并。  
**No-Go**：装箱复杂度失控，或 staging 无法在到达章界前完成精确预装箱 → 停方案 3，回方案 1 + 校准；冻结分支。
