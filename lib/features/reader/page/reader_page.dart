import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/reader/epub/readium_reader_shell.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/book/models.dart';

/// Readium EPUB reader page entry.
class ReaderPage extends HookWidget {
  final String bookId;
  final int initialChapterIndex;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final filePath = useState<String?>(null);
    final error = useState<String?>(null);
    final loadAttempt = useState(0);

    useEffect(() {
      var active = true;
      filePath.value = null;
      error.value = null;
      book_api
          .getBook(bookId: bookId)
          .then((book) {
            if (!active) return;
            if (book == null) {
              error.value = 'Book not found';
            } else if (book.format != BookFormat.epub) {
              error.value = '当前 MVP 仅支持 EPUB 阅读';
            } else {
              filePath.value = book.filePath;
            }
          })
          .catchError((Object e) {
            if (!active) return;
            error.value = 'Failed to load: $e';
          });
      return () => active = false;
    }, [bookId, loadAttempt.value]);

    if (error.value != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('EPUB 阅读')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.value!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => loadAttempt.value += 1,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (filePath.value == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ReadiumReaderShell(
      filePath: filePath.value!,
      bookId: bookId,
      initialChapterIndex: initialChapterIndex,
    );
  }
}
