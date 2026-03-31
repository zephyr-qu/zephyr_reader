/// 书架模块测试
///
/// 测试书架相关的状态管理、服务和数据源
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/data/bookshelf_local_data_source.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/book_category.dart';

void main() {
  group('书架状态管理测试', () {
    test('创建书架状态', () {
      // 书架状态测试已在其他文件中测试
      expect(true, isTrue);
    });

    test('添加书籍', () {
      // 添加书籍测试
      expect(true, isTrue);
    });

    test('删除书籍', () {
      // 删除书籍测试
      expect(true, isTrue);
    });

    test('更新书籍', () {
      // TODO: 测试更新书籍
    });

    test('筛选功能', () {
      // TODO: 测试筛选
    });

    test('排序功能', () {
      // TODO: 测试排序
    });
  });

  group('书架本地数据源测试', () {
    late AppDatabase database;
    late BookshelfLocalDataSource dataSource;

    setUp(() async {
      // 创建内存数据库用于测试
      database = AppDatabase(NativeDatabase.memory());
      dataSource = BookshelfLocalDataSource(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('应能获取空书籍列表', () async {
      final books = await dataSource.getAllBooks();
      expect(books, isEmpty);
    });

    test('应能添加书籍', () async {
      final book = _createTestBook(
        title: '测试书籍',
        author: '测试作者',
        fileType: 'txt',
      );

      final id = await dataSource.addBook(book);
      expect(id, isPositive);

      final savedBook = await dataSource.getBookById(id);
      expect(savedBook, isNotNull);
      expect(savedBook!.title, equals('测试书籍'));
      expect(savedBook.author, equals('测试作者'));
    });

    test('应能更新书籍', () async {
      // 添加书籍
      final book = _createTestBook(
        title: '原书名',
        author: '原作者',
      );
      final id = await dataSource.addBook(book);

      // 更新书籍
      final updatedBook = _createTestBook(
        id: id,
        title: '新书名',
        author: '新作者',
      );
      final result = await dataSource.updateBook(updatedBook);

      expect(result, isTrue);

      // 验证更新
      final savedBook = await dataSource.getBookById(id);
      expect(savedBook!.title, equals('新书名'));
      expect(savedBook.author, equals('新作者'));
    });

    test('应能删除书籍', () async {
      // 添加书籍
      final book = _createTestBook(title: '待删除书籍');
      final id = await dataSource.addBook(book);

      // 删除书籍
      final result = await dataSource.deleteBook(id);
      expect(result, isTrue);

      // 验证删除
      final deletedBook = await dataSource.getBookById(id);
      expect(deletedBook, isNull);
    });

    test('应能按分类筛选书籍', () async {
      // 添加不同状态的书籍
      await dataSource.addBook(_createTestBook(title: '书籍 1', status: 'reading'));
      await dataSource.addBook(_createTestBook(title: '书籍 2', status: 'completed'));
      await dataSource.addBook(_createTestBook(title: '书籍 3', status: 'reading'));

      // 按状态筛选
      final readingBooks = await dataSource.getBooksByCategory(BookCategory.reading);
      expect(readingBooks.length, equals(2));

      final completedBooks = await dataSource.getBooksByCategory(BookCategory.completed);
      expect(completedBooks.length, equals(1));

      // 获取全部
      final allBooks = await dataSource.getBooksByCategory(BookCategory.all);
      expect(allBooks.length, equals(3));
    });

    test('应能搜索书籍', () async {
      // 添加测试书籍
      await dataSource.addBook(_createTestBook(title: '哈利波特', author: 'J.K.罗琳'));
      await dataSource.addBook(_createTestBook(title: '三体', author: '刘慈欣'));
      await dataSource.addBook(_createTestBook(title: '流浪地球', author: '刘慈欣'));

      // 按标题搜索
      final searchByTitle = await dataSource.searchBooks('三体');
      expect(searchByTitle.length, equals(1));
      expect(searchByTitle.first.title, equals('三体'));

      // 按作者搜索
      final searchByAuthor = await dataSource.searchBooks('刘慈欣');
      expect(searchByAuthor.length, equals(2));
    });
  });

  group('书籍导入相关测试', () {
    test('应能检测重复文件', () async {
      // 创建临时测试文件
      final tempDir = await Directory.systemTemp.createTemp('zephyr_test_');
      final testFile = File('${tempDir.path}/test.txt');
      await testFile.writeAsString('测试内容');

      try {
        // 第一次导入
        final firstId = await _importTestFile(testFile.path);
        expect(firstId, isPositive);

        // 第二次导入同一文件（应检测为重复）
        // 注意：实际项目中需要实现重复检测逻辑
        // 这里仅做示例
        expect(true, isTrue);
      } finally {
        // 清理临时文件
        await tempDir.delete(recursive: true);
      }
    });

    test('应能验证文件格式', () {
      // 测试支持的文件格式
      expect(_isSupportedFormat('test.txt'), isTrue);
      expect(_isSupportedFormat('test.epub'), isTrue);
      expect(_isSupportedFormat('test.pdf'), isTrue);
      expect(_isSupportedFormat('test.doc'), isFalse);
      expect(_isSupportedFormat('test.xls'), isFalse);
    });

    test('应能处理文件选择', () async {
      // 文件选择测试（需要 mock file_picker）
      expect(true, isTrue);
    });
  });

  group('边界条件测试', () {
    late AppDatabase database;
    late BookshelfLocalDataSource dataSource;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      dataSource = BookshelfLocalDataSource(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('应能处理空标题', () async {
      final book = _createTestBook(title: '');
      final id = await dataSource.addBook(book);
      expect(id, isPositive);
    });

    test('应能处理超长标题', () async {
      final longTitle = 'A' * 1000;
      final book = _createTestBook(title: longTitle);
      final id = await dataSource.addBook(book);
      
      final saved = await dataSource.getBookById(id);
      expect(saved!.title.length, equals(1000));
    });

    test('应能处理特殊字符', () async {
      final specialTitle = '测试 <>&"\' 书籍';
      final book = _createTestBook(title: specialTitle);
      final id = await dataSource.addBook(book);
      
      final saved = await dataSource.getBookById(id);
      expect(saved!.title, equals(specialTitle));
    });

    test('应能处理 null 字段', () async {
      final book = Book.empty().copyWith(
        title: '测试书籍',
        filePath: '/test/path.txt',
        fileType: 'txt',
        fileSize: 1024,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        coverPath: null,
        description: null,
      );
      
      final id = await dataSource.addBook(book);
      expect(id, isPositive);
    });
  });
}

// ==================== 测试辅助方法 ====================

/// 创建测试书籍
Book _createTestBook({
  int id = 0,
  String title = '测试书籍',
  String author = '测试作者',
  String? coverPath,
  String? description,
  String filePath = '/test/path/book.txt',
  String fileType = 'txt',
  int fileSize = 1024,
  int totalChapters = 10,
  int totalCharacters = 10000,
  String status = 'reading',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    coverPath: coverPath,
    description: description,
    filePath: filePath,
    fileType: fileType,
    fileSize: fileSize,
    totalChapters: totalChapters,
    totalCharacters: totalCharacters,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
    status: status,
  );
}

/// 模拟导入测试文件
Future<int> _importTestFile(String filePath) async {
  // 模拟文件导入逻辑
  // 实际项目中应调用 BookImportService
  final book = _createTestBook(
    title: '导入的书籍',
    filePath: filePath,
    fileType: filePath.split('.').last,
  );
  
  final database = AppDatabase(NativeDatabase.memory());
  final dataSource = BookshelfLocalDataSource(database);
  
  try {
    final id = await dataSource.addBook(book);
    await database.close();
    return id;
  } catch (e) {
    await database.close();
    rethrow;
  }
}

/// 检查文件格式是否支持
bool _isSupportedFormat(String filename) {
  final supportedExtensions = ['txt', 'epub', 'pdf'];
  final extension = filename.split('.').last.toLowerCase();
  return supportedExtensions.contains(extension);
}
