/// 书籍仓库
library;

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/local/rust_core_service.dart';
import 'package:zephyr_reader/core/local/rust_cover_service.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_bookmark_repository.dart';
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_chapter_repository.dart';
import 'package:zephyr_reader/features/search/application/services/full_text_search_service.dart';
import 'package:zephyr_reader/src/rust/domain/types.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable()
class BookRepository {
  final RustStorageService _storage;
  final ChapterRepository _chapterRepo;
  final BookmarkRepository _bookmarkRepo;
  final RustCoreService _core;
  final RustCoverService _coverService;
  final FullTextSearchService _searchService;
  BookRepository(
    this._storage,
    this._chapterRepo,
    this._bookmarkRepo,
    this._core,
    this._coverService,
    this._searchService,
  );

  Future<List<Book>> getAllBooks() async {
    return _storage.getAllBooks();
  }

  Future<List<Book>> getBooksByCategory(BookCategory category) async {
    final allBooks = await getAllBooks();
    final booksWithCategory = <Book>[];
    for (final book in allBooks) {
      final categories = await _storage.getCategoriesForBook(book.bookId);
      if (categories.any((c) => c.id == category.id)) {
        booksWithCategory.add(book);
      }
    }
    return booksWithCategory;
  }

  Future<Book?> getBookById(String id) async {
    final allBooks = await getAllBooks();
    return allBooks.where((b) => b.bookId == id).firstOrNull;
  }

  Future<void> addBook(Book book) async {
    await _storage.saveBook(book);
  }

  Future<void> updateBook(Book book) async {
    await _storage.saveBook(book);
  }

  Future<bool> deleteBook(String id) async {
    try {
      final book = await getBookById(id);
      if (book == null) return false;

      await _storage.deleteBook(id);
      final bookIdInt = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      await _chapterRepo.deleteChaptersByBookId(bookIdInt);
      await _bookmarkRepo.deleteBookmarksByBookId(id);
      if (book.coverPath != null) {
        final coverFile = File(book.coverPath!);
        if (await coverFile.exists()) await coverFile.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Book>> searchBooks(String keyword) async {
    return _storage.searchBooks(keyword);
  }

  Future<List<Book>> getBooksByStatus(BookStatus status) async {
    final all = await _storage.getAllBooks();
    return all.where((b) => b.status == status).toList();
  }

  Future<List<BookCategory>> getAllCategories() async {
    return _storage.getAllCategories();
  }

  Future<BookCategory?> getCategoryById(String id) async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.id == id).firstOrNull;
  }

  Future<void> addCategory(BookCategory category) async {
    await _storage.saveCategory(category);
  }

  Future<void> updateCategory(BookCategory category) async {
    await _storage.saveCategory(category);
  }

  Future<void> deleteCategory(String id) async {
    await _storage.deleteCategory(id);
  }

  Future<void> updateBookCategories(
    String bookId,
    List<String> categoryIds,
  ) async {
    await _storage.setCategoriesForBook(bookId, categoryIds);
  }

  Future<Set<String>> getBookCategoryIds(String bookId) async {
    try {
      final cats = await _storage.getCategoriesForBook(bookId);
      return cats.map((c) => c.id).toSet();
    } catch (_) {
      return {};
    }
  }

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
  }) async {
    try {
      final existing = await getAllBooks();
      final exists = existing.any((b) => b.filePath == filePath);
      if (exists) {
        Logging.debug('书籍已存在：$filePath');
        return existing.firstWhere((b) => b.filePath == filePath);
      }
      final book = Book(
        bookId: 'book_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        author: author,
        filePath: filePath,
        format: _parseBookFormat(fileFormat),
        fileSize: fileSize,
        chapterCount: totalChapters,
        totalCharacters: totalCharacters,
        coverPath: coverPath,
        description: description,
        addedAt: DateTime.now(),
        status: BookStatus.planned,
        isPinned: false,
      );
      await addBook(book);
      return await getBookById(book.bookId);
    } catch (e) {
      Logging.debug('BookRepository.createBook error: $e');
      return null;
    }
  }

  Future<int> deleteBooks(List<String> bookIds) async {
    int deletedCount = 0;
    for (final bookId in bookIds) {
      if (await deleteBook(bookId)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<bool> updateBookTitle(String bookId, String newTitle) async {
    try {
      final book = await getBookById(bookId);
      if (book == null) return false;
      final updated = Book(
        bookId: book.bookId,
        filePath: book.filePath,
        fileSize: book.fileSize,
        title: newTitle,
        author: book.author,
        description: book.description,
        coverPath: book.coverPath,
        chapterCount: book.chapterCount,
        totalCharacters: book.totalCharacters,
        format: book.format,
        addedAt: book.addedAt,
        lastOpenedAt: book.lastOpenedAt,
        status: book.status,
        isPinned: book.isPinned,
      );
      await updateBook(updated);
      return true;
    } catch (e) {
      Logging.debug('BookRepository.updateBookTitle error: $e');
      return false;
    }
  }

  Future<bool> updateBookStatus(String bookId, String status) async {
    try {
      final book = await getBookById(bookId);
      if (book == null) return false;
      final bookStatus = BookStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => BookStatus.planned,
      );
      final updated = Book(
        bookId: book.bookId,
        filePath: book.filePath,
        fileSize: book.fileSize,
        title: book.title,
        author: book.author,
        description: book.description,
        coverPath: book.coverPath,
        chapterCount: book.chapterCount,
        totalCharacters: book.totalCharacters,
        format: book.format,
        addedAt: book.addedAt,
        lastOpenedAt: book.lastOpenedAt,
        status: bookStatus,
        isPinned: book.isPinned,
      );
      await updateBook(updated);
      return true;
    } catch (e) {
      Logging.debug('BookRepository.updateBookStatus error: $e');
      return false;
    }
  }

  // ===== From BookImportService =====

  Future<List<PlatformFile>?> selectFiles({
    bool allowMultiple = true,
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: allowMultiple,
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? ['txt', 'epub', 'pdf'],
      );
      return result?.files;
    } catch (e) {
      Logging.debug('BookImportService.selectFiles error: $e');
      return null;
    }
  }

  Future<String?> selectFolder() async {
    try {
      final folder = await FilePicker.getDirectoryPath();
      return folder;
    } catch (e) {
      Logging.debug('BookImportService.selectFolder error: $e');
      return null;
    }
  }

  Future<List<PlatformFile>> scanFolder(String folderPath) async {
    final files = <PlatformFile>[];
    final supportedFormats = {'txt', 'epub', 'pdf'};
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        Logging.debug('文件夹不存在folderPath');
        return files;
      }
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase().substring(1);
          if (supportedFormats.contains(ext)) {
            files.add(
              PlatformFile(
                name: p.basename(entity.path),
                path: entity.path,
                size: await entity.length(),
              ),
            );
          }
        }
      }
    } catch (e) {
      Logging.debug('BookImportService.scanFolder error: $e');
    }
    return files;
  }

  Future<Book?> importBook(PlatformFile file) async {
    final filePath = file.path;
    if (filePath == null || !await File(filePath).exists()) {
      Logging.error('文件不存在或无法访问: ${file.name}');
      return null;
    }

    try {
      final allBooks = await getAllBooks();
      final dup = allBooks.cast<Book?>().firstWhere(
        (b) => b!.filePath == filePath,
        orElse: () => null,
      );
      if (dup != null) return dup;

      final format = p.extension(file.name).toLowerCase().substring(1);
      final parseResult = await _parseBook(filePath, format);
      if (parseResult == null) return null;

      final bookInfo = parseResult.bookInfo;
      final rustChapters = parseResult.chapters;

      final parserCoverPath =
          bookInfo.coverPath != null && File(bookInfo.coverPath!).existsSync()
          ? bookInfo.coverPath
          : null;
      final book = Book(
        bookId: 'book_${DateTime.now().millisecondsSinceEpoch}',
        title: bookInfo.title,
        author: bookInfo.author ?? '未知作者',
        filePath: filePath,
        format: _parseBookFormat(format),
        fileSize: file.size,
        fileHash: bookInfo.fileHash,
        fileMtime: bookInfo.fileMtime,
        chapterCount: bookInfo.chapterCount,
        totalCharacters: bookInfo.totalCharacters,
        coverPath: parserCoverPath,
        description: bookInfo.description,
        addedAt: DateTime.now(),
        status: BookStatus.planned,
        isPinned: false,
      );
      await addBook(book);

      if (rustChapters.isNotEmpty) {
        final chapters = rustChapters
            .map(
              (ch) => Chapter(
                id: 'chapter_${ch.chapterIndex}',
                bookId: book.bookId,
                title: ch.title,
                contentFile: filePath,
                chapterIndex: ch.chapterIndex,
                wordCount: 0,
                cachedAt: DateTime.now(),
                startIndex: ch.startIndex.toInt(),
                endIndex: ch.endIndex.toInt(),
                contentLength: ch.contentLength.toInt(),
                level: ch.level,
              ),
            )
            .toList();
        await _chapterRepo.insertChapters(chapters);
      }

      // 后台完成封面提取和全文索引，不阻塞导入返回
      _indexAfterImport(book, filePath);

      return book;
    } catch (e, st) {
      Logging.error(
        'importBook异常: fileName=${file.name}',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<List<Book?>> importFiles(
    List<PlatformFile> files, {
    void Function(int current, int total, Book? book)? onProgress,
  }) async {
    final books = <Book?>[];
    for (int i = 0; i < files.length; i++) {
      final book = await importBook(files[i]);
      books.add(book);
      onProgress?.call(i + 1, files.length, book);
    }
    return books;
  }

  void _indexAfterImport(Book book, String filePath) {
    unawaited(_indexAfterImportAsync(book, filePath));
  }

  Future<void> _indexAfterImportAsync(Book book, String filePath) async {
    if (_coverService.supportsCoverExtraction(filePath)) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final coverDir = p.join(appDir.path, 'zephyr_reader', 'covers');
        final coverPath = await _coverService.extractBookCover(
          filePath: filePath,
          outputDir: coverDir,
        );
        if (coverPath.isNotEmpty) {
          final updated = Book(
            bookId: book.bookId,
            filePath: book.filePath,
            fileHash: book.fileHash,
            fileSize: book.fileSize,
            fileMtime: book.fileMtime,
            title: book.title,
            author: book.author,
            description: book.description,
            coverPath: coverPath,
            chapterCount: book.chapterCount,
            totalCharacters: book.totalCharacters,
            format: book.format,
            addedAt: book.addedAt,
            lastOpenedAt: book.lastOpenedAt,
            status: book.status,
            isPinned: book.isPinned,
          );
          await updateBook(updated);
        }
      } catch (e) {
        Logging.debug('_indexAfterImport cover extraction failed: $e');
      }
    }

    try {
      final bookIdInt =
          int.tryParse(book.bookId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final chapters = await _chapterRepo.getChaptersByBookId(bookIdInt);
      for (final ch in chapters) {
        try {
          final chapterContent = await _core.getChapter(
            filePath,
            ch.chapterIndex,
          );
          final text = chapterContent.when(
            raw: (t) => t,
            pages: (pages) => pages.map((p) => p.content).join(' '),
          );
          await _searchService.indexChapter(
            bookId: book.bookId,
            chapterId: ch.chapterIndex,
            chapterTitle: ch.title,
            content: text,
          );
        } catch (e) {
          Logging.error(
            '_indexAfterImport indexChapter失败: id=${ch.id}',
            exception: e,
          );
        }
      }
    } catch (e) {
      Logging.error('_indexAfterImport failed to get chapters', exception: e);
    }
  }

  Future<Map<String, dynamic>?> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final format = p.extension(filePath).toLowerCase().substring(1);
      return {
        'name': p.basename(filePath),
        'path': filePath,
        'format': format,
        'size': await file.length(),
      };
    } catch (e) {
      Logging.debug('BookImportService.getFileInfo error: $e');
      return null;
    }
  }

  List<String> getSupportedFormats() {
    return ['txt', 'epub', 'pdf'];
  }

  Future<ParseResult?> _parseBook(String filePath, String format) async {
    try {
      final result = await _core.parseBook(filePath);
      return result;
    } catch (e, st) {
      Logging.error(
        'Rust解析失败: filePath=$filePath',
        exception: e,
        stackTrace: st,
      );
      return null;
    }
  }

  BookFormat _parseBookFormat(String format) {
    switch (format.toLowerCase()) {
      case 'epub':
        return BookFormat.epub;
      case 'pdf':
        return BookFormat.pdf;
      default:
        return BookFormat.txt;
    }
  }
}
