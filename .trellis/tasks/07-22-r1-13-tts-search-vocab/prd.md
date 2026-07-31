# R13: TTS/搜索/生词

## Goal

TTS、搜索、生词功能保持应用层实现，Readium 只负责位置转换和 decoration 显示。不启用 Readium 原生能力以减少两套生命周期。

## Requirements

### TTS

- 继续使用现有应用层 TTS（统一 plainText）
- 保持一套播放状态
- TTS 位置仍使用 charOffset
- Readium viewport 只负责跟随跳转和可选 decoration
- **不启用** Readium 原生 TTS

### 搜索

- 继续使用现有全文索引（FTS）
- 搜索结果仍返回 `ReadingPosition`
- Readium Adapter 将位置转换为 Locator
- **不另建** Readium 搜索库

### 生词

- 如果可以构造稳定 range Locator → 映射成 decoration
- 否则 → Readium 首版禁用正文内生词标记
- 生词本管理功能仍保留

## Acceptance Criteria

- [ ] 搜索结果可跳转 Readium
- [ ] TTS 与阅读位置互不覆盖
- [ ] capability 控制不支持功能
- [ ] 没有第二套搜索和 TTS 状态真理
- [ ] 检查点：`feat: connect shared reader features to readium backend`
