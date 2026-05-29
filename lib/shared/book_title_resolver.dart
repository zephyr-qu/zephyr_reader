import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;

Future<Map<String, String>> loadBookTitles() async {
  try {
    final allBooks = await book_api.listBooks();
    return {for (final b in allBooks) b.bookId: b.title};
  } catch (e) {
    Logging.error('加载书籍标题失败', exception: e);
    return {};
  }
}
