import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zephyr_reader/core/utils/format_utils.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书籍详情信息表格（格式/大小/出版社/译者等）
class BookDetailInfoSection extends StatelessWidget {
  final Book book;
  final List<Category> categories;
  const BookDetailInfoSection({
    super.key,
    required this.book,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _infoRow(theme, l10n.bookFormat, book.format.name.toUpperCase()),
          _infoRow(theme, l10n.fileSize, formatFileSize(book.fileSize.toInt())),
          if (book.publisher != null && book.publisher!.isNotEmpty)
            _infoRow(theme, l10n.publisher, book.publisher!),
          if (book.translator != null && book.translator!.isNotEmpty)
            _infoRow(theme, l10n.translator, book.translator!),
          if (book.isbn != null && book.isbn!.isNotEmpty)
            _infoRow(theme, l10n.isbn, book.isbn!),
          if (categories.isNotEmpty)
            _infoRow(
              theme,
              l10n.category,
              categories.map((c) => c.name).join(' / '),
            ),
          _infoRow(
            theme,
            l10n.addedTime,
            DateFormat('yyyy-MM-dd').format(book.addedAt.toLocal()),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              key,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
