# 修复测试代码：生产代码变更后测试未跟进

## Goal

全量扫描测试代码，修复所有因生产代码变更（P6-P8 + ADR-016 收口）导致测试未跟进的编译/运行错误。

## Rules

1. 编译失败 / 运行报错的测试 → 更新 mock、断言、测试逻辑以匹配当前生产代码
2. 发现生产代码 Bug → 仅记录到 TODO/文档，跳过不修
3. 测试覆盖已删功能的（如 Rust 分页 session）→ 删除
4. 最终目标：`flutter test` 全绿（允许 pre-existing 失败记录在案，不导致新破）

## Acceptance

- [ ] `dart analyze test/ --fatal-infos` 零报
- [ ] `flutter test` 无新增测试失败（记录 pre-existing）
- [ ] 每处生产 Bug 发现都已记录到 discuss/ 或 TODO
