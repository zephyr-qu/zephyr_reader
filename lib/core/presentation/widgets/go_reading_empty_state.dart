import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// An empty state guiding the user to start reading.
///
/// Shows a centered column with a large faded icon, title, optional
/// subtitle, and a [FilledButton.tonalIcon] labelled with [buttonLabel]
/// that navigates to [AppRoute.bookshelf.path].
///
/// Used by [vocabulary_page] and [note_list_widget] for their
/// respective empty states.
class GoReadingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String buttonLabel;

  const GoReadingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: IconSize.hero,
            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () => context.push(AppRoute.bookshelf.path),
            icon: const Icon(PhosphorIconsRegular.books, size: IconSize.inline),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
