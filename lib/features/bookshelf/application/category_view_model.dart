import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/category.dart' as category_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class CategoryViewModel {
  /// 所有分类
  final categories = asyncSignal<List<Category>>(AsyncState.loading());

  /// 当前选中的分类
  final selectedCategory = signal<Category?>(null);

  CategoryViewModel();

  /// 加载所有分类列表。
  Future<void> loadCategories() async {
    try {
      final data = await category_api.listCategories();
      categories.value = AsyncState.data(data);
    } catch (e, stack) {
      Logging.error(
        'CategoryViewModel.loadCategories error',
        exception: e,
        stackTrace: stack,
      );
      categories.value = AsyncState.error(e);
    }
  }

  /// 切换分类。
  void selectCategory(Category? category) {
    selectedCategory.value = category;
  }

  /// 获取指定书籍关联的分类 ID 集合。
  Future<Set<String>> getCategoryIds(String bookId) async {
    try {
      final cats = await category_api.listCategoriesByBook(bookId: bookId);
      return cats.map((c) => c.id).toSet();
    } catch (_) {
      return {};
    }
  }

  // ==================== CRUD ====================

  Future<bool> _safeAction(
    String label,
    Future<bool> Function() action, {
    Future<void> Function()? onSuccess,
  }) async {
    try {
      final ok = await action();
      if (!ok) return false;
      if (onSuccess != null) await onSuccess();
      return true;
    } catch (e, stack) {
      Logging.error(
        'CategoryViewModel.$label error',
        exception: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// 添加新分类。
  Future<bool> addCategory({
    required String name,
    String color = '#FF5722',
    int sortOrder = 0,
  }) => _safeAction('addCategory', () async {
    await category_api.upsertCategory(
      name: name,
      color: color,
      sortOrder: sortOrder,
    );
    return true;
  }, onSuccess: loadCategories);

  /// 更新分类
  Future<bool> updateCategory(Category category) =>
      _safeAction('updateCategory', () async {
        await category_api.upsertCategory(
          name: category.name,
          color: category.color,
          sortOrder: category.sortOrder,
          description: category.description,
        );
        return true;
      }, onSuccess: loadCategories);

  /// 批量重排分类顺序（原子操作）
  Future<void> reorderCategories(List<Category> categories) =>
      category_api.reorderCategories(categories: categories);

  /// 删除分类
  Future<bool> removeCategory(String id) => _safeAction(
    'removeCategory',
    () async {
      await category_api.deleteCategory(categoryId: id);
      return true;
    },
    onSuccess: () async {
      await loadCategories();
      if (selectedCategory.value?.id == id) {
        selectedCategory.value = (categories.value.value ?? []).isEmpty
            ? null
            : (categories.value.value ?? []).first;
      }
    },
  );

  /// 释放所有 signal 资源。
  void dispose() {
    categories.dispose();
    selectedCategory.dispose();
  }
}
