# ADR-016：分页装箱迁 Flutter（方案三 · 提案）

- **状态**：**提案**（explore 实现中；对比主线胜出后才 Accept）
- **日期**：2026-07-12
- **分支**：`explore/flutter-side-pagination`
- **计划**：方案三 T0–T5（见 `.trellis/tasks/07-12-flutter-side-pagination/`）

## 决策（提案）

| 层 | 负责 | 不负责 |
|----|------|--------|
| **Rust** | EPUB/TXT → IR；图解码；可选 Hint-only 粗估（默认不做） | **页装箱**、校准写回、正式 PageDescriptor |
| **Flutter** | TextPainter **精确装箱**；渲染；staging（同算法预装箱）；进度 | HTML 全引擎 |

硬契约：正式翻页/书签只认 Flutter 精确页；禁止 Flutter→Rust 校准环；staging 不得用粗页冒充。

## 对既有 ADR

| ADR | 关系 |
|-----|------|
| 006 | Accept 后部分取代（分页从 Rust 挪走） |
| 013 | Accept 后 Superseded |
| 003 / 001 | 保留（IR 看图；charOffset） |
| 004 / 012 | 保留保证；实现改为 Flutter 精确预装箱 |

## 毕业 / 合并门槛

1. T2 staging 跨章无 spinner  
2. T3 大章不 ANR  
3. 真机 S1–S3 + overflow  
4. 与主线对比报告，择优合并  
5. 合并后 Accept 本 ADR，关旧校准路径  

## 不做

- Phase 5 中途 silent 切主线  
- 长期双真理  
- T4 粗 hint 默认不做  
