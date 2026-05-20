library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_book_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../helpers/fixtures.dart';

class _MockBookRepository implements BookRepository {
  final List<Book> _books = [];
  final List<BookCategory> _categories = [];

  Future<void> saveBook(Book book) async {
    final idx = _books.indexWhere((b) => b.bookId == book.bookId);
    if (idx >= 0) {
      _books[idx] = book;
    } else {
      _books.add(book);
    }
  }

  @override
  Future<void> addBook(Book book) async => _books.add(book);

  @override
  Future<void> updateBook(Book book) async {
    final idx = _books.indexWhere((b) => b.bookId == book.bookId);
    if (idx >= 0) _books[idx] = book;
  }

  @override
  Future<List<Book>> getAllBooks() async => List.from(_books);

  @override
  Future<List<Book>> searchBooks(String keyword) async =>
      _books.where((b) => b.title.contains(keyword)).toList();

  @override
  Future<List<Book>> getBooksByCategory(BookCategory category) async =>
      _books.where((b) {
        return _categories.where((c) => c.id == category.id).isNotEmpty;
      }).toList();

  @override
  Future<List<Book>> getBooksByStatus(BookStatus status) async =>
      _books.where((b) => b.status == status).toList();

  @override
  Future<Book?> getBookById(String id) async =>
      _books.where((b) => b.bookId == id).firstOrNull;

  @override
  Future<bool> deleteBook(String id) async {
    _books.removeWhere((b) => b.bookId == id);
    return true;
  }

  @override
  Future<List<BookCategory>> getAllCategories() async => List.from(_categories);

  @override
  Future<BookCategory?> getCategoryById(String id) async =>
      _categories.where((c) => c.id == id).firstOrNull;

  @override
  Future<void> addCategory(BookCategory category) async {
    _categories.add(category);
  }

  @override
  Future<void> updateCategory(BookCategory category) async {
    final idx = _categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) _categories[idx] = category;
  }

  @override
  Future<void> deleteCategory(String id) async {
    _categories.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> updateBookCategories(
    String bookId,
    List<String> categoryIds,
  ) async {}

  @override
  Future<Set<String>> getBookCategoryIds(String bookId) async => {};

  @override
  Future<Book?> createBook({
    required String title,
    required String author,
    required String filePath,
    required String fileFormat,
    int fileSize = 0,
    int totalChapters = 0,
    int totalCharacters = 0,
    String? coverPath,
    String? description,
  }) async => null;

  @override
  Future<int> deleteBooks(List<String> bookIds) async {
    int count = 0;
    for (final id in bookIds) {
      if (await deleteBook(id)) count++;
    }
    return count;
  }

  @override
  Future<bool> updateBookTitle(String bookId, String newTitle) async => true;

  @override
  Future<bool> updateBookStatus(String bookId, String status) async => true;

  @override
  Future<Map<String, dynamic>?> getFileInfo(String filePath) async => null;

  @override
  List<String> getSupportedFormats() => ['txt', 'epub', 'pdf'];

  @override
  Future<Book?> importBook(PlatformFile file) async => null;

  @override
  Future<List<Book?>> importFiles(
    List<PlatformFile> files, {
    void Function(int current, int total, Book? book)? onProgress,
  }) async => [];

  @override
  Future<List<PlatformFile>> scanFolder(String folderPath) async => [];

  @override
  Future<List<PlatformFile>?> selectFiles({
    bool allowMultiple = true,
    List<String>? allowedExtensions,
  }) async => null;

  @override
  Future<String?> selectFolder() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfViewModel', () {
    late _MockBookRepository repo;
    late SharedPreferences prefs;
    late BookshelfViewModel vm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = _MockBookRepository();
      vm = BookshelfViewModel(repo, prefs);
    });

    tearDown(() {
      vm.dispose();
    });

    group('书籍加载', () {
      test('初始状态应加载书籍列表', () async {
        await repo.addBook(createTestBook(id: 'book_1', title: '三国演义'));
        await repo.addBook(createTestBook(id: 'book_2', title: '西游记'));

        await vm.loadBooks();

        expect(vm.books.value.value?.length, equals(2));
      });

      test('搜索模式应调用 searchBooks', () async {
        await repo.addBook(createTestBook(id: 'book_1', title: '三国演义'));
        await repo.addBook(createTestBook(id: 'book_2', title: '西游记'));

        vm.isSearching.value = true;
        vm.searchKeyword.value = '三国';
        await vm.loadBooks();

        expect(vm.books.value.value?.length, equals(1));
        expect(vm.books.value.value?.first.title, equals('三国演义'));
      });

      test('状态筛选应返回对应状态的书籍', () async {
        await repo.addBook(
          createTestBook(id: 'book_1', status: BookStatus.reading),
        );
        await repo.addBook(
          createTestBook(id: 'book_2', status: BookStatus.completed),
        );
        await repo.addBook(
          createTestBook(id: 'book_3', status: BookStatus.reading),
        );

        vm.selectedStatus.value = BookStatus.reading;
        await vm.loadBooks();

        expect(vm.books.value.value?.length, equals(2));
      });

      test('无书籍时应返回空列表', () async {
        await vm.loadBooks();

        expect(vm.books.value.value, isEmpty);
      });

      test('空搜索结果应返回空列表', () async {
        await repo.addBook(createTestBook(id: 'book_1', title: '三国演义'));

        vm.isSearching.value = true;
        vm.searchKeyword.value = '不存在的书';
        await vm.loadBooks();

        expect(vm.books.value.value, isEmpty);
      });

      test('状态筛选无匹配时应返回空列表', () async {
        await repo.addBook(
          createTestBook(id: 'book_1', status: BookStatus.reading),
        );

        vm.selectedStatus.value = BookStatus.completed;
        await vm.loadBooks();

        expect(vm.books.value.value, isEmpty);
      });

      test('关闭状态筛选后应返回全部书籍', () async {
        await repo.addBook(
          createTestBook(id: 'book_1', status: BookStatus.reading),
        );
        await repo.addBook(
          createTestBook(id: 'book_2', status: BookStatus.completed),
        );

        vm.selectedStatus.value = BookStatus.reading;
        await vm.loadBooks();
        expect(vm.books.value.value?.length, equals(1));

        vm.selectedStatus.value = null;
        await vm.loadBooks();
        expect(vm.books.value.value?.length, equals(2));
      });
    });

    group('搜索', () {
      test('startSearch 应进入搜索模式', () {
        expect(vm.isSearching.value, isFalse);
        vm.startSearch();
        expect(vm.isSearching.value, isTrue);
      });

      test('stopSearch 应退出搜索并清空关键词', () {
        vm.startSearch();
        vm.updateSearchKeyword('测试');
        vm.stopSearch();

        expect(vm.isSearching.value, isFalse);
        expect(vm.searchKeyword.value, isEmpty);
      });

      test('updateSearchKeyword 应更新关键词', () {
        vm.updateSearchKeyword('三国');
        expect(vm.searchKeyword.value, equals('三国'));
      });
    });

    group('分类管理', () {
      test('selectCategory 应切换分类筛选', () {
        final cat = createTestCategory();
        vm.selectCategory(cat);
        expect(vm.selectedCategory.value?.id, equals(cat.id));
        expect(vm.isSearching.value, isFalse);
      });

      test('selectCategory 设为 null 应清除筛选', () {
        vm.selectCategory(createTestCategory());
        vm.selectCategory(null);
        expect(vm.selectedCategory.value, isNull);
      });

      test('selectStatus 应切换状态筛选', () {
        vm.selectStatus(BookStatus.reading);
        expect(vm.selectedStatus.value, equals(BookStatus.reading));
      });

      test('addCategory 应添加分类', () async {
        await vm.addCategory(name: '科幻');
        expect(vm.categories.value.length, equals(1));
        expect(vm.categories.value.first.name, equals('科幻'));
      });

      test('deleteCategory 应删除分类', () async {
        await vm.addCategory(name: '科幻');
        expect(vm.categories.value.length, equals(1));

        final result = await vm.removeCategory(vm.categories.value.first.id);
        expect(result, isTrue);
        expect(vm.categories.value.length, equals(0));
      });

      test('updateBookCategories 应更新书籍分类', () async {
        final result = await vm.updateBookCategories('book_1', ['cat_1']);
        expect(result, isTrue);
      });
    });

    group('设置持久化', () {
      test('setShowReadingProgress 应持久化设置', () async {
        await vm.setShowReadingProgress(false);
        expect(vm.showReadingProgress.value, isFalse);

        final loaded = prefs.getBool('bookshelf.show_reading_progress');
        expect(loaded, isFalse);
      });

      test('setDefaultSortType 应持久化排序方式', () async {
        await vm.setDefaultSortType(BookshelfSortType.title);
        expect(vm.defaultSortType.value, equals(BookshelfSortType.title));

        final loaded = prefs.getString('bookshelf.default_sort_type');
        expect(loaded, equals('title'));
      });
    });

    group('删除书籍', () {
      test('deleteBook 应删除并重新加载', () async {
        await repo.addBook(createTestBook(id: 'book_1'));
        await vm.loadBooks();
        expect(vm.books.value.value?.length, equals(1));

        final result = await vm.deleteBook('book_1');

        expect(result, isTrue);
        expect(vm.books.value.value?.length, equals(0));
      });

      test('getBookDetail 应返回书籍详情', () async {
        await repo.addBook(createTestBook(id: 'book_1', title: '三国演义'));
        final book = await vm.getBookDetail('book_1');
        expect(book?.title, equals('三国演义'));
      });
    });
  });
}
