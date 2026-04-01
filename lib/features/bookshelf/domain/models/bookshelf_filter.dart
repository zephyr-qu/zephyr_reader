/// 书架筛选状
class BookshelfFilter {
  /// 搜索关键
  final String? keyword;

  /// 书籍状态筛
  final String? status;

  /// 文件格式筛
  final String? format;

  /// 排序方式
  final BookshelfSortType sortType;

  /// 是否倒序
  final bool ascending;

  const BookshelfFilter({
    this.keyword,
    this.status,
    this.format,
    this.sortType = BookshelfSortType.lastRead,
    this.ascending = false,
  });

  BookshelfFilter copyWith({
    String? keyword,
    String? status,
    String? format,
    BookshelfSortType? sortType,
    bool? ascending,
  }) {
    return BookshelfFilter(
      keyword: keyword ?? this.keyword,
      status: status ?? this.status,
      format: format ?? this.format,
      sortType: sortType ?? this.sortType,
      ascending: ascending ?? this.ascending,
    );
  }
}

/// 书架视图模式
enum BookshelfViewMode {
  /// 网格视图
  grid,

  /// 列表视图
  list,
}

/// 书架排序方式
enum BookshelfSortType {
  /// 最后阅读时
  lastRead,

  /// 添加时间
  createdAt,

  /// 书名
  title,

  /// 作
  author,

  /// 阅读进度
  progress,
}
