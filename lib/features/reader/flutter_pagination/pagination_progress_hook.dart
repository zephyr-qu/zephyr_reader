/// expand 过程中推进 UI `_totalPages`（避免改公共 PaginationSession 接口）。
void Function(int totalPages, bool isPartial)? paginationProgressHook;
