import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class StreakCard extends StatelessWidget {
  final int days;
  final int totalBooks;

  const StreakCard({super.key, required this.days, required this.totalBooks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.fire, size: 14, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                l10n.streakLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$days',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          Text(l10n.daysUnit, style: tt.labelLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.books,
                size: 10,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(l10n.booksRead(totalBooks), style: tt.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
