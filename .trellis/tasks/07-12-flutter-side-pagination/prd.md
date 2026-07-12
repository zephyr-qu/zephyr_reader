# 方案三：Flutter 精确分页（North Star）

## Goal

**页边界真理在 Flutter**；Rust 只出 IR（+ 可选粗估 hint，默认不做）；用 isolate/预取满足 staging；**不做** metrics 回传环。

本分支 `explore/flutter-side-pagination` **完整实现方案三（T0–T3，T4 可选）**，完成后与主线对比，完成度更高且核心更稳的一方合并。

相对方案 2：同一真理；补上「相邻章精确预装箱 + 大章不卡」产品层。方案 2 = **T0**；方案 3 = **T0→T5**。

## Verdict 策略

| 阶段 | 主线关系 |
|------|----------|
| 开发中 | 仅 explore 分支；`kFlutterPaginationSpike` 默认关 |
| 对比后 | 与主线（Rust+校准）比：overflow、换章、大章、可维护性 |
| 合并 | 胜出方进主线；输方归档。**禁止长期双真理** |

## Hard Contracts

1. 正式翻页/书签只认 Flutter 精确页。  
2. Rust 粗结果若存在，不得写入正式 session。  
3. 测量与装箱同侧；禁止 Flutter→Rust 校准写回。  
4. Staging 预取必须用**同算法**精确装箱，禁止粗页冒充真页。

## Requirements

- R1：flag 门控；关 = 现网 Rust 路径。  
- R2：flag 开 = 零分页 session / calibration / store_line_breaks FFI。  
- R3：T0 精确分页（TXT + 进度 + 图）。  
- R4：T2 相邻章 staging，跨章无 spinner（ADR-012）。  
- R5：T3 大章主 isolate 分块 yield + 首屏优先（TextPainter 不能进 compute）。  
- R6：T5 前不删 Rust 引擎；对比后再收敛。  
- R7：T4 粗 hint 默认 Out of Scope。

## Acceptance（总）

- [x] T0：单测绿；flag 关回归绿（真机 overflow 抽样记入对比清单）  
- [ ] T1：正式 session 形态 + PageView/图路径稳定  
- [ ] T2：forward/backward staging promote 无可见 loading  
- [x] T3：大章装箱不在 UI isolate 阻塞（主 isolate 分块 yield）  
- [ ] 对比报告：相对主线的 Must 场景表  
- [ ] T5：ADR-016 Accept 或本方案归档（合并时二选一）

## Out of Scope（直到明确开闸）

- T4 Rust 粗 hint  
- WebView / 复杂 CSS  
- Phase 5 主线 silent 切换  
- 双语专项

## Decisions

| # | 决策 |
|---|------|
| D1 | 方案三 = 最终 explore 目标 |
| D2 | 与主线对比后合并，不提前 Accept ADR |
| D3 | Staging = 精确预装箱，不是粗页 |
| D4 | T4 可永久不做 |
