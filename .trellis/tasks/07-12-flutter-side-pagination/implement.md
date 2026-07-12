# Implement — 方案三 T0–T5

## T0 基线（方案 2 spike）— 已完成代码

- [x] Flag + spike session + orchestrator 旁路  
- [x] TextPainter 装箱、进度、EPUB 图  
- [x] 单测 `test/features/reader/flutter_pagination/`  
- [ ] 真机 TXT overflow / 书签抽样（对比清单，不阻塞 T1）

**门控**：单测不过 → 停。真机抽样记入对比报告。

## T1 产品核

- [x] `FlutterPaginationSession` 正式命名导出  
- [x] Flag/注释改为方案三  
- [x] Image / PageView 路径（contentBlocks）  
- [x] 文档与导出整理  

## T2 staging（精确预装箱）

- [x] `PaginationStagingStore`：next/prev 持 ir+pages+filePath  
- [x] flag 开时 `preloadNext/PreviousChapterStaging` 走 Flutter 装箱  
- [x] 填充 `NextChapterStaging` 供虚拟页  
- [x] promote：`installFromReady`，不 Rust adopt  
- [x] 单测：installFromReady  
- [ ] 真机跨章无 spinner 抽样（对比清单）

## T3 大章

- [x] 主 isolate 分块 `paginateAsync`（`yieldEveryBlocks`）——TextPainter 不能进普通 `compute`
- [x] generation / `isCancelled` 取消（session + staging）
- [x] 首屏 `maxChars` → `isPartial` → `expandToFullChapter` 补全
- [x] orchestrator spike 路径：先首屏 finalize，再 expand
- [x] 单测：partial stop / cancel / async≡sync

## T4 粗 hint

- [ ] **默认跳过**  

## T5 收敛（对比合并后）

- [x] TXT 真机满意 → [compare-txt.md](./compare-txt.md) **TXT Go**
- [x] EPUB 真机满意 → [compare-epub.md](./compare-epub.md) **EPUB Go**
- [x] ADR-016 → **条件接受**（合主线后正式 Accept）
- [x] 合入 `phase/stage6-line-width-calib`：Flutter 为唯一分页主路径
- [x] 去掉 explore/spike 旁路命名 → `lib/features/reader/flutter_pagination/`
- [x] 关 Rust 装箱/校准写回主路径（DEAD PATH 保留至删除提交）
- [ ] 删除 Rust BlockPaginator / apply_session_calibration / RustPaginationSession
- [ ] 正式 Accept ADR-016

### EPUB 工程缺口

- [x] 内联图装箱计入 ±4dp padding
- [x] 占位高度与 `imageDisplayHeightDp` 对齐
- [x] 渲染侧 inline `maxHeight` 与 IR intrinsic 一致（`ActiveChapterIr`）
- [x] staging 用 `PaginationViewportMetrics` + 图 prefetch
- [x] session dispose 清 `epubBlockImageCache` + IR holder
- [x] 切片保留 EPUB spans
- [x] spike 路径不传 `layoutCalibration`（避免主线校准诊断噪声）

## 验证命令

```bash
flutter test test/features/reader/flutter_pagination/
flutter test test/features/reader/core/application/chapter_load_orchestrator_test.dart
```

## 风险文件

| 文件 | 允许 |
|------|------|
| `spike/*` | 自由 |
| `chapter_load_orchestrator.dart` | flag + promote + 首屏/expand |
| `rust_chapter_content_repository.dart` | flag 时 staging 旁路 |
| `block_paginator.rs` | 禁止改（对比前保留） |
