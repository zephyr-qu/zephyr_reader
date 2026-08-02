# 审查重构后冗余代码并输出报告

## Goal

审查历次重构后遗留的冗余代码：死代码/未使用文件、未使用的依赖、重复/重叠实现、废弃封装层。输出：聊天摘要 + discuss/ 下 markdown 报告。

## Requirements

1. **死代码/未使用文件**：无 import 引用的 Dart 文件；无引用的类/函数/顶层变量（dart analyze 查不出的跨文件孤儿）；Rust 侧零调用 API 面与生成物残留。
2. **未使用的依赖**：pubspec.yaml 中在 lib/ 无实际 import 的包；`lib/src/**`（FRB 生成区）单独核对。
3. **重复/重叠实现**：多个模块各自实现同一逻辑（配置读取、错误处理、格式化、widget 样式等）；同一概念两套 API。
4. **废弃封装层**：重构后变成薄包装/透传的抽象层（service/repository/widget wrapper），尤其仅转发给 Readium 或 Rust 的层。

## Constraints

- 只读审查，不删除任何文件；删除建议写入报告，由用户后续裁决执行。
- 与历史报告 `discuss/REDUNDANCY_REPORT.md`（基线 c1932bfb，2026-08-02）对照：已执行项不再重复报告，重点报告基线之后（e30fec01/f5cef45c 及工作区未提交改动）的新增残留 + 旧报告遗留未执行项。
- 不修改 frb_generated.rs / frb_generated.h / lib/src/rust 下的生成代码（FRB 禁区），但可报告其冗余。

## Acceptance Criteria

- [ ] 输出 markdown 报告（建议 `discuss/REDUNDANCY_REPORT_V2.md`），按 A-D 四类列出现象、位置、估算规模、处置建议。
- [ ] 每项建议附验证方法（grep 命令 / dart analyze / 引用图证据），确保可复核。
- [ ] 聊天中给出摘要：Top 发现 + 关键风险 + 建议执行顺序。
- [ ] 报告只读：不修改任何生产代码；若发现需改代码才能确认的项，标注为"待确认"而非臆断。
