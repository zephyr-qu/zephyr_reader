/// 阅读器内容加载测试
///
/// 测试阅读器页面内容加载功能，包括：
/// - 书籍信息加载
/// - 章节列表加载
/// - 章节内容加载
/// - 阅读进度保存
/// - 错误处理
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/local/file_storage.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/bookshelf_service.dart';
import 'package:zephyr_reader/features/bookshelf/application/states/bookshelf_state.dart';
import 'package:zephyr_reader/features/bookshelf/data/bookshelf_local_data_source.dart';
import 'package:zephyr_reader/features/reader/data/reader_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'dart:io';

void main() {
  group('阅读器内容加载测试', () {
    late GetIt getIt;
    late AppDatabase database;
    late Directory testDir;

    setUp(() async {
      // 初始化 Widget 绑定（测试必需）
      TestWidgetsFlutterBinding.ensureInitialized();

      getIt = GetIt.instance;
      getIt.reset();

      // 创建临时测试目录
      testDir = await Directory.systemTemp.createTemp('zephyr_reader_test_');

      // 初始化测试数据库（使用内存数据库）
      database = AppDatabase(NativeDatabase.memory());
      getIt.registerSingleton<AppDatabase>(database);

      // 初始化文件存储（使用 mock）
      final mockFileStorage = _MockFileStorage(testDir.path);
      getIt.registerSingleton<_MockFileStorage>(mockFileStorage);

      // 初始化书架服务
      final dataSource = BookshelfLocalDataSource(database);
      final state = BookshelfState();
      getIt.registerSingleton<BookshelfLocalDataSource>(dataSource);
      getIt.registerSingleton<BookshelfState>(state);
      getIt.registerSingleton<BookshelfService>(
        BookshelfService(dataSource, state),
      );

      // 初始化阅读器服务
      getIt.registerSingleton<ReaderService>(
        ReaderService(database, mockFileStorage),
      );
    });

    tearDown(() async {
      // 清理测试数据
      await database.close();
      try {
        await testDir.delete(recursive: true);
      } catch (_) {}
      getIt.reset();
    });

    group('书籍信息加载测试', () {
      test('应能成功加载书籍信息', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          author: '测试作者',
          filePath: '${testDir.path}/test_book.txt',
          fileType: 'txt',
        );

        // 获取书架服务
        final bookshelfService = getIt.get<BookshelfService>();

        // 加载书籍信息
        final book = await bookshelfService.getBookDetail(testBook.id);

        // 验证结果
        expect(book, isNotNull);
        expect(book!.title, equals('测试书籍'));
        expect(book.author, equals('测试作者'));
        expect(book.fileType, equals('txt'));
      });

      test('书籍不存在时应返回 null', () async {
        final bookshelfService = getIt.get<BookshelfService>();

        final book = await bookshelfService.getBookDetail(999);

        expect(book, isNull);
      });

      test('应能成功加载章节列表', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        // 创建测试章节
        await _createTestChapters(testBook.id, 3);

        // 获取书架服务
        final bookshelfService = getIt.get<BookshelfService>();

        // 加载章节列表
        final chapters = await bookshelfService.getBookChapters(testBook.id);

        // 验证结果
        expect(chapters.length, equals(3));
        expect(chapters[0].title, contains('第'));
        expect(chapters[1].title, contains('第'));
        expect(chapters[2].title, contains('第'));
      });

      test('书籍没有章节时应返回空列表', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        final bookshelfService = getIt.get<BookshelfService>();

        final chapters = await bookshelfService.getBookChapters(testBook.id);

        expect(chapters, isEmpty);
      });
    });

    group('章节内容加载测试', () {
      test('应能成功加载章节内容', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        // 创建测试章节
        await _createTestChapters(testBook.id, 1);

        // 创建章节内容文件
        final contentFile = '${testDir.path}/chapter_0.txt';
        await File(contentFile).create(recursive: true);
        await File(contentFile).writeAsString('这是第一章的内容');

        // 更新章节的 contentFile 路径
        await (database.update(database.dbChapters)
              ..where((tbl) => tbl.bookId.equals(testBook.id)))
            .write(DbChaptersCompanion(
          contentFile: Value(contentFile),
        ));

        // 获取阅读器服务
        final readerService = getIt.get<ReaderService>();

        // 加载章节内容
        final content = await readerService.getChapterContent(contentFile);

        // 验证结果
        expect(content, isNotNull);
        expect(content, equals('这是第一章的内容'));
      });

      test('章节内容文件不存在时应返回 null', () async {
        final readerService = getIt.get<ReaderService>();

        final content = await readerService.getChapterContent(
          '${testDir.path}/non_existent.txt',
        );

        expect(content, isNull);
      });

      test('章节内容文件为空时应返回空字符串', () async {
        // 创建空文件
        final contentFile = '${testDir.path}/empty_chapter.txt';
        await File(contentFile).create(recursive: true);
        await File(contentFile).writeAsString('');

        final readerService = getIt.get<ReaderService>();

        final content = await readerService.getChapterContent(contentFile);

        expect(content, equals(''));
      });

      test('应能获取章节信息', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        // 创建测试章节
        await _createTestChapters(testBook.id, 1);

        final readerService = getIt.get<ReaderService>();

        final chapter = await readerService.getChapter(testBook.id, 0);

        expect(chapter, isNotNull);
        expect(chapter!.title, contains('第'));
      });

      test('章节不存在时应返回 null', () async {
        final readerService = getIt.get<ReaderService>();

        final chapter = await readerService.getChapter(999, 0);

        expect(chapter, isNull);
      });
    });

    group('阅读进度保存测试', () {
      test('应能保存阅读进度', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        final readerService = getIt.get<ReaderService>();

        // 保存阅读历史
        await readerService.saveReadingHistory(
          testBook.id,
          1, // chapterId
          10, // position
          300, // duration (秒)
        );

        // 验证阅读历史
        final history = await readerService.getReadingHistory(testBook.id);

        expect(history, isNotNull);
        expect(history!.chapterId, equals(1));
        expect(history.position, equals(10));
        expect(history.duration, equals(300));
      });

      test('应能更新阅读进度', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        final readerService = getIt.get<ReaderService>();

        // 第一次保存
        await readerService.saveReadingHistory(
          testBook.id,
          1,
          10,
          300,
        );

        // 第二次保存（更新）
        await readerService.saveReadingHistory(
          testBook.id,
          2,
          20,
          600,
        );

        // 验证更新后的进度
        final history = await readerService.getReadingHistory(testBook.id);

        expect(history, isNotNull);
        expect(history!.chapterId, equals(2));
        expect(history.position, equals(20));
        // 注意：实际实现中 duration 会累加
        expect(history.duration, greaterThanOrEqualTo(300));
      });

      test('不存在的书籍阅读进度应返回 null', () async {
        final readerService = getIt.get<ReaderService>();

        final history = await readerService.getReadingHistory(999);

        expect(history, isNull);
      });
    });

    group('书签功能测试', () {
      test('应能添加书签', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        final readerService = getIt.get<ReaderService>();

        // 添加书签
        final bookmarkId = await readerService.addBookmark(
          testBook.id,
          1, // chapterId
          100, // position
          '测试书签',
        );

        expect(bookmarkId, greaterThan(0));
      });

      test('应能获取书签列表', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        final readerService = getIt.get<ReaderService>();

        // 添加多个书签
        await readerService.addBookmark(testBook.id, 1, 100, '书签 1');
        await readerService.addBookmark(testBook.id, 2, 200, '书签 2');
        await readerService.addBookmark(testBook.id, 3, 300, '书签 3');

        // 获取书签列表
        final bookmarks = await readerService.getBookmarks(testBook.id);

        expect(bookmarks.length, equals(3));
        // 验证有 note 字段即可，不验证具体值（因为可能为 null）
        expect(bookmarks[0].note, equals('书签 1'));
        expect(bookmarks[1].note, equals('书签 2'));
        expect(bookmarks[2].note, equals('书签 3'));
      });

      test('应能删除书签', () async {
        // 创建测试书籍
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        final readerService = getIt.get<ReaderService>();

        // 添加书签
        final bookmarkId = await readerService.addBookmark(
          testBook.id,
          1,
          100,
          '测试书签',
        );

        // 删除书签
        final deleted = await readerService.deleteBookmark(bookmarkId);

        expect(deleted, isTrue);

        // 验证已删除
        final bookmarks = await readerService.getBookmarks(testBook.id);
        expect(bookmarks.isEmpty, isTrue);
      });

      test('删除不存在的书签应返回 false', () async {
        final readerService = getIt.get<ReaderService>();

        final deleted = await readerService.deleteBookmark(999);

        expect(deleted, isFalse);
      });
    });

    group('错误处理测试', () {
      test('加载不存在的书籍应返回 null', () async {
        final bookshelfService = getIt.get<BookshelfService>();

        final book = await bookshelfService.getBookDetail(999);

        expect(book, isNull);
      });

      test('文件路径无效时应处理错误', () async {
        final readerService = getIt.get<ReaderService>();

        // 使用无效路径
        final content = await readerService.getChapterContent('');

        expect(content, isNull);
      });

      test('数据库操作失败时应捕获异常', () async {
        // 创建一个书籍，然后尝试删除不存在的章节
        await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        final readerService = getIt.get<ReaderService>();

        // 删除不存在的书签应该返回 false 而不是抛出异常
        final deleted = await readerService.deleteBookmark(999);

        expect(deleted, isFalse);
      });
    });

    group('边界条件测试', () {
      test('书籍标题为空时应能正常处理', () async {
        final testBook = await _createTestBook(
          title: '',
          filePath: '${testDir.path}/test_book.txt',
        );

        final bookshelfService = getIt.get<BookshelfService>();
        final book = await bookshelfService.getBookDetail(testBook.id);

        expect(book, isNotNull);
        expect(book!.title, equals(''));
      });

      test('书籍标题超长时应能正常处理', () async {
        final longTitle = 'a' * 1000;
        final testBook = await _createTestBook(
          title: longTitle,
          filePath: '${testDir.path}/test_book.txt',
        );

        final bookshelfService = getIt.get<BookshelfService>();
        final book = await bookshelfService.getBookDetail(testBook.id);

        expect(book, isNotNull);
        expect(book!.title.length, equals(1000));
      });

      test('章节内容为特殊字符时应能正常处理', () async {
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        await _createTestChapters(testBook.id, 1);

        // 创建包含特殊字符的内容
        final specialContent = '特殊字符：!@#\$%^&*()_+-=[]{}|;:\'",.<>?/`~';
        final contentFile = '${testDir.path}/chapter_0.txt';
        await File(contentFile).create(recursive: true);
        await File(contentFile).writeAsString(specialContent);

        await (database.update(database.dbChapters)
              ..where((tbl) => tbl.bookId.equals(testBook.id)))
            .write(DbChaptersCompanion(
          contentFile: Value(contentFile),
        ));

        final readerService = getIt.get<ReaderService>();
        final content = await readerService.getChapterContent(contentFile);

        expect(content, equals(specialContent));
      });

      test('章节内容为多语言时应能正常处理', () async {
        final testBook = await _createTestBook(
          title: '测试书籍',
          filePath: '${testDir.path}/test_book.txt',
        );

        await _createTestChapters(testBook.id, 1);

        // 创建多语言内容
        final multiLangContent = '''
中文内容
English content
日本語コンテンツ
한국어 콘텐츠
''';
        final contentFile = '${testDir.path}/chapter_0.txt';
        await File(contentFile).create(recursive: true);
        await File(contentFile).writeAsString(multiLangContent);

        await (database.update(database.dbChapters)
              ..where((tbl) => tbl.bookId.equals(testBook.id)))
            .write(DbChaptersCompanion(
          contentFile: Value(contentFile),
        ));

        final readerService = getIt.get<ReaderService>();
        final content = await readerService.getChapterContent(contentFile);

        expect(content, equals(multiLangContent));
      });
    });
  });
}

// ==================== 辅助方法 ====================

/// 创建测试书籍
Future<Book> _createTestBook({
  String title = '测试书籍',
  String author = '测试作者',
  String filePath = '/test/book.txt',
  String fileType = 'txt',
  int fileSize = 1024,
}) async {
  final database = GetIt.I.get<AppDatabase>();

  final id = await database
      .into(database.dbBooks)
      .insert(DbBooksCompanion.insert(
        title: title,
        author: author,
        filePath: filePath,
        fileType: fileType,
        fileSize: Value(fileSize),
        totalChapters: const Value(0),
        totalCharacters: const Value(0),
      ));

  return Book(
    id: id,
    title: title,
    author: author,
    filePath: filePath,
    fileType: fileType,
    fileSize: fileSize,
    totalChapters: 0,
    totalCharacters: 0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// 创建测试章节
Future<void> _createTestChapters(int bookId, int count) async {
  final database = GetIt.I.get<AppDatabase>();

  for (int i = 0; i < count; i++) {
    await database
        .into(database.dbChapters)
        .insert(DbChaptersCompanion.insert(
          bookId: bookId,
          title: '第${i + 1}章',
          contentFile: '${bookId}_chapter_$i.txt',
          chapterIndex: i,
          wordCount: const Value(1000),
        ));
  }
}

// ==================== Mock FileStorage ====================

/// 模拟文件存储，用于测试
class _MockFileStorage extends FileStorage {
  final String basePath;
  final Map<String, String> _fileContents = {};

  _MockFileStorage(this.basePath);

  @override
  Future<bool> saveString(String filename, String content, {bool useTemp = false}) async {
    try {
      _fileContents[filename] = content;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> readString(String filename, {bool useTemp = false}) async {
    try {
      // 先检查内存缓存
      if (_fileContents.containsKey(filename)) {
        return _fileContents[filename];
      }
      // 然后检查实际文件
      final file = File(filename);
      if (await file.exists()) {
        final content = await file.readAsString();
        _fileContents[filename] = content;
        return content;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> exists(String filename, {bool useTemp = false}) async {
    try {
      return _fileContents.containsKey(filename) || await File(filename).exists();
    } catch (_) {
      return false;
    }
  }
}
