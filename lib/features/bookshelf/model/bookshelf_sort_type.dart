import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 书架排序方式枚举。
enum BookshelfSortType {
  lastRead('last_opened_at', false),
  createdAt('added_at', false),
  progress('progress', false),
  title('title', true),
  author('author', true);

  /// 持久化键 / SQL `ORDER BY` 列名
  final String key;

  /// true=asc, false=desc
  final bool asc;

  const BookshelfSortType(this.key, this.asc);

  /// 本地化标签
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    BookshelfSortType.lastRead => l10n.sortLastRead,
    BookshelfSortType.createdAt => l10n.sortCreatedAt,
    BookshelfSortType.title => l10n.sortTitle,
    BookshelfSortType.author => l10n.sortAuthor,
    BookshelfSortType.progress => l10n.sortProgress,
  };

  static BookshelfSortType fromKey(String key) {
    return BookshelfSortType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => BookshelfSortType.lastRead,
    );
  }
}
