# 真机对比清单（EPUB）

**前置**：TXT 真机已满意（Flutter 装箱优于 Rust）。  
**分支**：`explore/flutter-side-pagination` · `kFlutterPaginationSpike = true`（须冷启）

## Must

| # | 场景 | 结果 | 备注 |
|---|------|------|------|
| E1 | 打开带图 EPUB，正文出页、图能显示（非永久骨架） | ✅ | 用户确认 |
| E2 | 高图 FullPage 独占，无文字挤进同页，无黄条溢出 | ✅ | 用户确认优于主线 |
| E3 | 文+小图 InlineContain，无 RenderFlex overflow，底空不明显 | ✅ | 用户确认优于主线 |
| E4 | 跨章 staging / promote，无整页 spinner，下一章图正常 | ✅ | 抽样满意 |
| E5 | 改字号后进度/书签大致落在同句 | ✅ | 抽样满意 |

## 工程缺口

- [x] 内联图包装箱计入 ±4dp padding  
- [x] 占位高度与 `imageDisplayHeightDp` 对齐（勿用 16:9）  
- [x] 渲染侧 inline `maxHeight` 与装箱一致（读 IR intrinsic）  
- [x] staging 用 `PaginationViewportMetrics` + 图 prefetch  
- [x] session dispose 清 `epubBlockImageCache`  
- [x] 切片保留 EPUB spans  
- [x] spike 路径不传 layoutCalibration  

## 结论

- [x] **EPUB Conditional Go**（2026-07-12）：用户确认整体明显优于主线 Rust+校准  
- [ ] 有回归 → 修后再比  
