import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/application/book_detail_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_dialogs.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_actions.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_bottom_actions.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_desc_section.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_hero.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_info_section.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_note_stats.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_progress_card.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_toc_section.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class BookDetailPage extends HookWidget {
  final String bookId;
  const BookDetailPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => BookDetailViewModel(bookId: bookId), [bookId]);
    useEffect(() {
      vm.loadData();
      return null;
    }, []);
    final AsyncState<Book?> book = useSignalValue(vm.book);
    final AsyncState<ReadingProgress?> progress = useSignalValue(vm.progress);
    final AsyncState<NoteStats?> noteStats = useSignalValue(vm.noteStats);
    final AsyncState<List<Chapter>> chapters = useSignalValue(vm.chapters);
    final AsyncState<List<Category>> categories = useSignalValue(vm.categories);
    final int sessionCount = useSignalValue(vm.sessionCount);
    final int vocabCount = useSignalValue(vm.vocabCount);
    final showAll = useSignal<bool>(false);
    final toggleShowAllChapters = useComputed(
      () => showAll.value = !showAll.value,
    );

    // Widget body;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsLight.caretLeft),
          onPressed: () => context.pop(),
          tooltip: l10n.back,
        ),
      ),
      body: SafeArea(
        child: book.map(
          data: (Book? book) {
            if (book == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.loadFailed,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => vm.loadData(),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            } else {
              final currentChapterIndex = progress.value?.chapterIndex ?? -1;
              final hasProgress =
                  progress.value != null && (progress.value!.progress) > 0;
              final chapterTitle =
                  hasProgress &&
                      currentChapterIndex >= 0 &&
                      currentChapterIndex < chapters.value!.length
                  ? chapters.value![currentChapterIndex].title
                  : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookDetailHero(book: book, categories: categories.value!),
                    BookDetailActions(
                      hasProgress: hasProgress,
                      currentChapterTitle: chapterTitle,
                      onContinueReading: () => context.pushNamed(
                        RouteNames.reader,
                        pathParameters: {
                          'bookId': book.bookId,
                          'chapterId': '${progress.value?.chapterIndex ?? 0}',
                        },
                      ),
                      onReadFromBeginning: () => context.pushNamed(
                        RouteNames.reader,
                        pathParameters: {
                          'bookId': book.bookId,
                          'chapterId': '0',
                        },
                      ),
                    ),
                    if (progress.value != null)
                      BookDetailProgressCard(
                        progress: progress.value!,
                        sessionCount: sessionCount,
                      ),
                    BookDetailNoteStats(
                      highlightCount: noteStats.value?.highlightCount ?? 0,
                      annotationCount: noteStats.value?.annotationCount ?? 0,
                      vocabCount: vocabCount,
                    ),
                    BookDetailTocSection(
                      chapters: chapters.value!,
                      showAll: showAll.value,
                      currentChapterIndex: currentChapterIndex,
                      onToggleExpand: () => toggleShowAllChapters(),
                      onChapterTap: (ci) => context.pushNamed(
                        RouteNames.reader,
                        pathParameters: {
                          'bookId': book.bookId,
                          'chapterId': '$ci',
                        },
                      ),
                    ),
                    BookDetailInfoSection(
                      book: book,
                      categories: categories.value!,
                    ),
                    if (book.description?.isNotEmpty == true)
                      BookDetailDescSection(description: book.description!),
                    BookDetailBottomActions(
                      onEditMetadata: () => _onEditMetadata(context, vm, book),
                      onExportNotes: () =>
                          context.pushNamed(RouteNames.learningNotes),
                      onDeleteBook: () async {
                        final ok = await showDeleteBookDialog(context, book);
                        if (ok && context.mounted) context.pop();
                      },
                    ),
                  ],
                ),
              );
            }
          },
          error: () {},
          loading: (() => const Center(child: CircularProgressIndicator())),
        ),
      ),
    );
  }

  Future<void> _onEditMetadata(
    BuildContext context,
    BookDetailViewModel vm,
    Book book,
  ) async {
    final result = await showEditMetadataDialog(context, book);
    if (result != null && context.mounted) {
      vm.book.value = AsyncState.data(
        book.copyWith(
          title: result['title'] ?? book.title,
          author: result['author']?.isNotEmpty == true
              ? result['author']
              : null,
          description: result['description']?.isNotEmpty == true
              ? result['description']
              : null,
          publisher: result['publisher']?.isNotEmpty == true
              ? result['publisher']
              : null,
          translator: result['translator']?.isNotEmpty == true
              ? result['translator']
              : null,
          isbn: result['isbn']?.isNotEmpty == true ? result['isbn'] : null,
        ),
      );
    }
  }
}
