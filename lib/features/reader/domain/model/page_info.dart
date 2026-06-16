/// 估算分页结果。
///
/// 用于无需 FFI 的快速分页场景（首屏渲染、预加载）。
class PageInfo {
  final int pageIndex;
  final String content;
  final int startOffset;
  final int endOffset;
  const PageInfo({
    required this.pageIndex,
    required this.content,
    required this.startOffset,
    required this.endOffset,
  });
}
