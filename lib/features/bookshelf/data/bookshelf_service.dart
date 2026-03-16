import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import '../domain/bookshelf_repository.dart';
import '../domain/models/book_category.dart';

/// 书架服务实现
@LazySingleton(as: BookshelfRepository)
class BookshelfService implements BookshelfRepository {
  final AppDatabase _database;

  BookshelfService(this._database);

  @override
  Future<List<Novel>> getAllBooks() async {
    return await _database.getAllNovels();
  }

  @override
  Future<List<Novel>> getBooksByCategory(BookCategory category) async {
    if (category == BookCategory.all) {
      return await getAllBooks();
    }
    return await (_database.select(
      _database.novels,
    )..where((tbl) => tbl.status.equals(category.name))).get();
  }

  @override
  Future<Novel?> getBookById(int id) async {
    return await _database.getNovelById(id);
  }

  @override
  Future<int> addBook(NovelsCompanion book) async {
    return await _database.into(_database.novels).insert(book);
  }

  @override
  Future<bool> updateBook(Novel book) async {
    return await (_database.update(
          _database.novels,
        )..where((tbl) => tbl.id.equals(book.id))).write(
          NovelsCompanion(
            title: Value(book.title),
            author: Value(book.author),
            coverPath: Value(book.coverPath),
            description: Value(book.description),
            totalChapters: Value(book.totalChapters),
            status: Value(book.status),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;
  }

  @override
  Future<bool> deleteBook(int id) async {
    return await (_database.delete(
          _database.novels,
        )..where((tbl) => tbl.id.equals(id))).go() >
        0;
  }

  @override
  Future<List<Novel>> searchBooks(String keyword) async {
    return await _database.searchNovels(keyword);
  }
}
