import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/database/database.dart';
import '../domain/bookshelf_repository.dart';
import '../domain/models/book_category.dart';

/// 书架视图模型
@injectable
class BookshelfViewModel {
  final BookshelfRepository _repo;

  /// 所有书籍
  final books = asyncSignal<List<Novel>>(AsyncState.loading());

  /// 当前选中的分类
  final selectedCategory = signal<BookCategory>(BookCategory.all);

  /// 搜索关键词
  final searchKeyword = signal<String>('');

  /// 是否在搜索模式
  final isSearching = signal<bool>(false);

  BookshelfViewModel(this._repo) {
    effect(() {
      loadBooks();
    });
  }

  /// 加载书籍
  Future<void> loadBooks() async {
    books.value = AsyncState.loading();
    try {
      List<Novel> data;

      if (isSearching.value && searchKeyword.value.isNotEmpty) {
        data = await _repo.searchBooks(searchKeyword.value);
      } else {
        data = await _repo.getBooksByCategory(selectedCategory.value);
      }

      books.value = AsyncState.data(data);
    } catch (e) {
      books.value = AsyncState.error(e);
    }
  }

  /// 切换分类
  void selectCategory(BookCategory category) {
    selectedCategory.value = category;
    isSearching.value = false;
    searchKeyword.value = '';
  }

  /// 开始搜索
  void startSearch() {
    isSearching.value = true;
  }

  /// 停止搜索
  void stopSearch() {
    isSearching.value = false;
    searchKeyword.value = '';
  }

  /// 更新搜索关键词
  void updateSearchKeyword(String keyword) {
    searchKeyword.value = keyword;
  }

  /// 删除书籍
  Future<bool> deleteBook(int id) async {
    try {
      final success = await _repo.deleteBook(id);
      if (success) {
        await loadBooks();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 获取书籍详情
  Future<Novel?> getBookDetail(int id) async {
    return await _repo.getBookById(id);
  }
}