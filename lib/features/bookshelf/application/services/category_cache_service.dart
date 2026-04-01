import 'package:zephyr_reader/features/bookshelf/domain/models/book_category.dart';

/// 分类缓存服务
///
/// 提供分类的内存缓存，避免频繁查询数据库
class CategoryCacheService {
  /// 缓存的分类列表
  List<BookCategory> _categories = [];

  /// 缓存是否已初始化
  bool _isInitialized = false;

  /// 默认分类（硬编码）
  static final List<BookCategory> _defaultCategories = [
    const BookCategory(
      id: 0,
      name: '全部',
      color: '#FF5722',
      sortOrder: 0,
      isSystem: true,
      createdAt: null,
      updatedAt: null,
    ),
    const BookCategory(
      id: 1,
      name: '阅读中',
      color: '#2196F3',
      sortOrder: 1,
      isSystem: true,
      createdAt: null,
      updatedAt: null,
    ),
    const BookCategory(
      id: 2,
      name: '已完结',
      color: '#4CAF50',
      sortOrder: 2,
      isSystem: true,
      createdAt: null,
      updatedAt: null,
    ),
    const BookCategory(
      id: 3,
      name: '已弃坑',
      color: '#9E9E9E',
      sortOrder: 3,
      isSystem: true,
      createdAt: null,
      updatedAt: null,
    ),
    const BookCategory(
      id: 4,
      name: '计划阅读',
      color: '#FF9800',
      sortOrder: 4,
      isSystem: true,
      createdAt: null,
      updatedAt: null,
    ),
  ];

  /// 获取缓存的分类
  List<BookCategory> get categories =>
      _isInitialized && _categories.isNotEmpty
          ? _categories
          : _defaultCategories;

  /// 获取缓存的分类（根据 ID）
  BookCategory? getCategoryById(int id) {
    if (_categories.isEmpty) {
      return _defaultCategories.cast<BookCategory?>().firstWhere(
            (c) => c?.id == id,
            orElse: () => null,
          );
    }
    return _categories.cast<BookCategory?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
  }

  /// 更新缓存
  void updateCategories(List<BookCategory> categories) {
    _categories = List.from(categories)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _isInitialized = true;
  }

  /// 添加分类到缓存
  void addCategory(BookCategory category) {
    _categories.add(category);
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 从缓存移除分类
  void removeCategory(int id) {
    _categories.removeWhere((c) => c.id == id);
  }

  /// 更新缓存中的分类
  void updateCategoryInCache(BookCategory category) {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
    }
  }

  /// 清除缓存
  void clear() {
    _categories.clear();
    _isInitialized = false;
  }

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取默认分类
  static List<BookCategory> getDefaultCategories() {
    return List.unmodifiable(_defaultCategories);
  }
}
