import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 分类缓存服务
///
/// 提供分类的内存缓存，避免频繁查询数据库
class CategoryCacheService {
  /// 缓存的分类列表
  List<DbBookCategory> _categories = [];

  /// 缓存是否已初始化
  bool _isInitialized = false;

  /// 默认分类（硬编码）
  static final List<DbBookCategory> _defaultCategories = [
    DbBookCategory(
      id: '0',
      name: '全部',
      color: '#FF5722',
      sortOrder: 0,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DbBookCategory(
      id: '1',
      name: '阅读中',
      color: '#2196F3',
      sortOrder: 1,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DbBookCategory(
      id: '2',
      name: '已完结',
      color: '#4CAF50',
      sortOrder: 2,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DbBookCategory(
      id: '3',
      name: '已弃坑',
      color: '#9E9E9E',
      sortOrder: 3,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DbBookCategory(
      id: '4',
      name: '计划阅读',
      color: '#FF9800',
      sortOrder: 4,
      isSystem: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  /// 获取缓存的分类
  List<DbBookCategory> get categories => _isInitialized && _categories.isNotEmpty
      ? _categories
      : _defaultCategories;

  /// 获取缓存的分类（根据 ID）
  DbBookCategory? getCategoryById(String id) {
    if (_categories.isEmpty) {
      return _defaultCategories.cast<DbBookCategory?>().firstWhere(
        (c) => c?.id == id,
        orElse: () => null,
      );
    }
    return _categories.cast<DbBookCategory?>().firstWhere(
      (c) => c?.id == id,
      orElse: () => null,
    );
  }

  /// 更新缓存
  void updateCategories(List<DbBookCategory> categories) {
    _categories = List.from(categories)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _isInitialized = true;
  }

  /// 添加分类到缓存
  void addCategory(DbBookCategory category) {
    _categories.add(category);
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// 从缓存移除分类
  void removeCategory(String id) {
    _categories.removeWhere((c) => c.id == id);
  }

  /// 更新缓存中的分类
  void updateCategoryInCache(DbBookCategory category) {
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
  static List<DbBookCategory> getDefaultCategories() {
    return List.unmodifiable(_defaultCategories);
  }
}
