/// 方案三总开关：Flutter 精确分页（页边界真理在 Flutter）。
///
/// - `false`（默认）：现网 Rust `BlockPaginator` + 校准环。
/// - `true`：本分支方案三路径 — IR only + Flutter 装箱 + 精确 staging。
///
/// 改此常量后需热重启（DI 启动时创建 session）。
const bool kFlutterPaginationSpike = false;
