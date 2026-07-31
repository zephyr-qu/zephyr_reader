import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/reader/epub/readium_reader_shell.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;

/// Readium EPUB reader page entry.
class ReaderPage extends HookWidget {
  final String bookId;

  const ReaderPage({
    super.key,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    final filePath = useState<String?>(null);
    final error = useState<String?>(null);

    useEffect(() {
      book_api.getBook(bookId: bookId).then((book) {
        if (book == null) {
          error.value = 'Book not found';
        } else {
          filePath.value = book.filePath;
        }
      }).catchError((Object e) {
        error.value = 'Failed to load: $e';
      });
      return null;
    }, [bookId]);

    if (error.value != null) {
      return Scaffold(
        body: Center(child: Text(error.value!, style: const TextStyle(color: Colors.red))),
      );
    }
    if (filePath.value == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ReadiumReaderShell(filePath: filePath.value!, bookId: bookId);
  }
}
