# Implement — 方案三 T0–T5

## T0 基线（方案 2 spike）— 已完成代码

- [x] Flag + spike session + orchestrator 旁路  
- [x] TextPainter 装箱、进度、EPUB 图  
- [x] 单测 `test/features/reader/spike/`  
- [ ] 真机 TXT overflow / 书签抽样（对比清单，不阻塞 T1）

**门控**：单测不过 → 停。真机抽样记入对比报告。

## T1 产品核

- [x] `FlutterPaginationSession` 正式命名导出  
- [x] Flag/注释改为方案三  
- [x] Image / PageView 路径（contentBlocks）  
- [x] 文档与导出整理  

## T2 staging（精确预装箱）

- [x] `SpikeStagingStore`：next/prev 持 ir+pages+filePath  
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

- [ ] 对比报告  
- [ ] 胜出则 Accept ADR-016 + 关校准路径；否则归档本分支  

## 验证命令

```bash
flutter test test/features/reader/spike/
flutter test test/features/reader/core/application/chapter_load_orchestrator_test.dart
```

## 风险文件

| 文件 | 允许 |
|------|------|
| `spike/*` | 自由 |
| `chapter_load_orchestrator.dart` | flag + promote + 首屏/expand |
| `rust_chapter_content_repository.dart` | flag 时 staging 旁路 |
| `block_paginator.rs` | 禁止改（对比前保留） |
