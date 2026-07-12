/// 方案三总开关：Flutter 精确分页（页边界真理在 Flutter）。
///
/// - `false`：旧主线 Rust `BlockPaginator` + 校准环（对照用）。
/// - `true`：方案三路径 — IR only + Flutter 装箱 + 精确 staging。
///
/// **explore 分支默认 true**（TXT+EPUB 真机已 Conditional Go）。
/// 合主线后改为产品默认，并移除旁路命名。
/// 改此常量后必须 **冷启/重装**（DI 启动时创建 session，热重载无效）。
const bool kFlutterPaginationSpike = true;

/// expand 过程中推进 `_totalPages`（explore 临时候钩，避免改公共接口）。
void Function(int totalPages, bool isPartial)? spikePaginationProgressHook;
