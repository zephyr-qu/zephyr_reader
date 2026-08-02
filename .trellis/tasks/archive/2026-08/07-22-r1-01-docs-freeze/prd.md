# R1: 冻结正式架构

## Goal

ADR-019 状态改为 Accepted，所有相关文档完成正式声明。不允许再做 PoC、AB 测试、逐步试验等描述。

## Requirements

1. ADR-019 状态改为 Accepted，移除 PoC/实验性描述
2. READING_BOUNDARIES.md 声明：允许封装后的 Readium EPUB Navigator；禁止 UI 层直接依赖 WebView/Readium
3. DOMAIN_MODEL.md 增加 `ReadingBackend`、`ReadingSnapshot`、`EnginePositionHint`、`ReadingCapabilities`
4. ROADMAP.md 更新 Phase R1 为 15 阶段计划
5. 声明正式规则：
   - TXT 默认 Builtin
   - EPUB 默认 Readium
   - Builtin EPUB 是兼容回退
   - 不要求排版结果一致

## Acceptance Criteria

- [ ] ADR-019 不再保留 PoC、AB 测试、逐步试验等描述
- [ ] seam、位置语义、回退策略无歧义
- [ ] 检查点：`docs: accept readium as the primary epub backend`
