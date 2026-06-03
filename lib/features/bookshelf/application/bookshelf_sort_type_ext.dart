import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

extension BookshelfSortTypeX on BookshelfSortType {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    BookshelfSortType.lastRead => l10n.sortLastRead,
    BookshelfSortType.createdAt => l10n.sortCreatedAt,
    BookshelfSortType.title => l10n.sortTitle,
    BookshelfSortType.author => l10n.sortAuthor,
    BookshelfSortType.progress => l10n.sortProgress,
  };
}
