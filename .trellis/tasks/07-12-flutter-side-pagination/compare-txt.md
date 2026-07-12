# 真机对比清单（TXT only）

**范围**：TXT。EPUB 见 [compare-epub.md](./compare-epub.md)。  
**分支**：`explore/flutter-side-pagination`

## 结论（2026-07-12）

- [x] **TXT Go**：用户确认整体优于 Rust 分页；溢出已压到 ~2dp slack 内；flag 已开 Flutter 路径  
- [x] 继续推进 EPUB（不 Accept ADR-016 直至 EPUB Must 过）

## 关键记录摘要

| 项 | 结果 |
|----|------|
| 溢出/裁切 | 最终 ~1.8dp → 加 2dp slack |
| 大章首屏 | 实测视口重装后可接受 |
| 翻页卡死 | 已修（推进 totalPages） |
| 分章「一、」 | 已加 pattern；需重导 |
| 跨章 | 单章样本未充分测 |

## Flag

`kFlutterPaginationSpike = true`（explore）；**冷启**。
