import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/book_detail_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_dialogs.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_actions.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_bottom_actions.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_hero.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_info_section.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_note_stats.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_progress_card.dart';
import 'package:zephyr_reader/features/bookshelf/page/detail/book_detail_toc_section.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
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
    final AsyncState<book_api.BookDetail> state = useSignalValue(vm.state);
    final showAll = useSignal<bool>(false);
    void toggleShowAllChapters() => showAll.value = !showAll.value;

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
        child: state.map(
          data: (detail) {
            final book = detail.book;
            final progress = detail.progress;
            final currentChapterIndex = progress?.chapterIndex ?? -1;
            final hasProgress = progress != null && progress.progress > 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookDetailHero(book: book, categories: detail.categories),
                  BookDetailActions(
                    hasProgress: hasProgress,
                    onContinueReading: () => context.pushNamed(
                      AppRoute.reader.name,
                      pathParameters: {
                        'bookId': book.bookId,
                        'chapterId': '${progress?.chapterIndex ?? 0}',
                      },
                    ),
                    onReadFromBeginning: () => context.pushNamed(
                      AppRoute.reader.name,
                      pathParameters: {'bookId': book.bookId, 'chapterId': '0'},
                    ),
                  ),
                  if (progress != null)
                    BookDetailProgressCard(
                      progress: progress,
                      sessionCount: detail.sessionCount,
                    ),
                  BookDetailNoteStats(
                    highlightCount: detail.noteStats.highlightCount,
                    annotationCount: detail.noteStats.annotationCount,
                    vocabCount: detail.vocabCount,
                  ),
                  BookDetailTocSection(
                    chapters: detail.chapters,
                    showAll: showAll.value,
                    currentChapterIndex: currentChapterIndex,
                    onToggleExpand: () => toggleShowAllChapters(),
                    onChapterTap: (ci) => context.pushNamed(
                      AppRoute.reader.name,
                      pathParameters: {
                        'bookId': book.bookId,
                        'chapterId': '$ci',
                      },
                    ),
                  ),
                  BookDetailInfoSection(
                    book: book,
                    categories: detail.categories,
                  ),
                  BookDetailBottomActions(
                    onEditMetadata: () => _onEditMetadata(context, vm, book),
                    onExportNotes: () =>
                        _onExportNotes(context, vm, book, l10n),
                    onDeleteBook: () async {
                      Logging.debug(
                        '[DetailPage] onDeleteBook start, bookId=${book.bookId}',
                      );
                      final ok = await showDeleteBookDialog(context, book);
                      Logging.debug(
                        '[DetailPage] showDeleteBookDialog returned ok=$ok',
                      );
                      if (ok) {
                        final bookshelfVm = getIt<BookshelfViewModel>();
                        Logging.debug(
                          '[DetailPage] got BookshelfVM instance, calling loadBooks()',
                        );
                        await bookshelfVm.loadBooks();
                        Logging.debug(
                          '[DetailPage] loadBooks completed, now popping',
                        );
                        if (context.mounted) context.pop();
                      }
                    },
                  ),
                ],
              ),
            );
          },
          error: (e) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: IconSize.hero,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.loadFailed,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => vm.loadData(),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
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
    final updated = await showEditMetadataDialog(context, book);
    if (updated == null || !context.mounted) return;
    final current = vm.state.value;
    if (current is AsyncData<book_api.BookDetail>) {
      vm.state.value = AsyncState.data(current.value.copyWith(book: updated));
    }
  }

  Future<void> _onExportNotes(
    BuildContext context,
    BookDetailViewModel vm,
    Book book,
    AppLocalizations l10n,
  ) async {
    try {
      final notes = await note_api.listNotesByBook(bookId: book.bookId);
      if (notes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.noNotes)));
        }
        return;
      }
      final markdown = note_api.renderNotesToString(
        notes: notes,
        bookTitle: book.title,
        format: 'markdown',
      );
      final dirPath = await FilePicker.getDirectoryPath(
        dialogTitle: l10n.exportNotes,
      );
      if (dirPath == null) return;
      final safeName = book.title
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final filePath = '$dirPath/${safeName}_读书笔记.md';
      await File(filePath).writeAsString(markdown);
      Logging.debug('[DetailPage] Notes exported to $filePath');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.exportNotes} ${l10n.success}: $filePath'),
          ),
        );
      }
    } catch (e) {
      Logging.error('Export notes failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.exportNotes} ${l10n.failed}: $e')),
        );
      }
    }
  }
}
