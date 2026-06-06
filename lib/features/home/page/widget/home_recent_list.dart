import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/home/page/widget/home_recent_book_card.dart';

class HomeRecentList extends StatelessWidget {
  final List<Book> books;

  const HomeRecentList({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentReading,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: books.isEmpty
              ? Center(
                  child: Text(
                    l10n.noReadingRecord,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return HomeRecentBookCard(book: books[index]);
                  },
                ),
        ),
      ],
    );
  }
}
