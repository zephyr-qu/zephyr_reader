/// 阅读模式
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 仿真翻页
  pageTurn,

  /// 左右分页
  pagination,

  /// 双语对照
  bilingual,
}

/// 书写方向
enum WritingDirection {
  /// 横排
  horizontal,

  /// 竖排 (top-to-bottom, right-to-left)
  vertical,
}
