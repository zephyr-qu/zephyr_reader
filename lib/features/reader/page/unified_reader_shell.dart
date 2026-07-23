import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/reading/backend/reading_backend_kind.dart';
import 'package:zephyr_reader/core/reading/backend/reading_backend_policy.dart';
import 'package:zephyr_reader/features/reader/epub/readium_reader_shell.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_shell.dart'
    as builtin;
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;

/// Unified reading shell that routes to the appropriate backend shell.
///
/// This is the single entry point for all reading — TXT, builtin EPUB,
/// and Readium EPUB. It determines which backend to use based on book
/// format and the [ReadingBackendPolicy], then delegates to the correct
/// concrete shell.
///
/// Both shells share the same outer page transition because they enter
/// through the same [ReaderPage] route. Internal widget unification
/// (shared toolbar, drawer, etc.) happens in R10–R14.
class UnifiedReaderShell extends HookWidget {
  final String bookId;
  final int initialChapterId;

  const UnifiedReaderShell({
    super.key,
    required this.bookId,
    this.initialChapterId = 0,
  });

  @override
  Widget build(BuildContext context) {
    final tick = useState(0);
    final kind = useRef<ReadingBackendKind?>(null);
    final loading = useRef(true);
    final errorMsg = useRef<String?>(null);
    final bookPath = useRef<String?>(null);

    // Kick off backend determination once.
    useEffect(() {
      _determine(bookId, kind, loading, errorMsg, bookPath, tick);
      return null;
    }, [bookId]);

    // Loading
    if (loading.value) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Error
    if (errorMsg.value != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorMsg.value!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    // Route to the correct shell
    final bk = kind.value;
    if (bk == ReadingBackendKind.readium && bookPath.value != null) {
      return ReadiumReaderShell(filePath: bookPath.value!);
    }

    // Default to Builtin for TXT, fallback EPUB, or unknown
    return builtin.ReaderShell(
      bookId: bookId,
      initialChapterId: initialChapterId,
    );
  }

  static Future<void> _determine(
    String bookId,
    ObjectRef<ReadingBackendKind?> kindRef,
    ObjectRef<bool> loadingRef,
    ObjectRef<String?> errorRef,
    ObjectRef<String?> pathRef,
    ValueNotifier<int> tick,
  ) async {
    try {
      final book = await book_api.getBook(bookId: bookId);
      if (book == null) {
        errorRef.value = 'Book not found: $bookId';
        loadingRef.value = false;
        tick.value++;
        return;
      }

      final format = book.format.name; // 'txt' or 'epub'
      pathRef.value = book.filePath;
      final policy = ReadingBackendPolicy();
      kindRef.value = policy.select(format: format, bookId: bookId);
    } catch (e) {
      errorRef.value = 'Failed to open book: $e';
    }
    loadingRef.value = false;
    tick.value++;
  }
}
