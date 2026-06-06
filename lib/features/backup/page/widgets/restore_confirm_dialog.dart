import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

/// 恢复确认对话框
Future<bool?> showRestoreConfirmDialog(
  BuildContext context,
  BackupManifest manifest,
) {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(PhosphorIconsRegular.warning, color: cs.error, size: 22),
          const SizedBox(width: 8),
          Text(l10n.restoreConfirmTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.restoreConfirmWarning,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow(ctx, l10n.restoreStatVersion, manifest.appVersion),
                _statRow(
                  ctx,
                  l10n.restoreStatExportedAt,
                  DateTime.fromMillisecondsSinceEpoch(
                    manifest.exportedAt * 1000,
                  ).toString().substring(0, 19),
                ),
                _statRow(ctx, l10n.restoreStatBooks, '${manifest.stats.books}'),
                _statRow(ctx, l10n.restoreStatNotes, '${manifest.stats.notes}'),
                _statRow(
                  ctx,
                  l10n.restoreStatBookmarks,
                  '${manifest.stats.bookmarks}',
                ),
                _statRow(
                  ctx,
                  l10n.restoreStatVocabulary,
                  '${manifest.stats.vocabularyWords}',
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.restoreConfirmAction),
        ),
      ],
    ),
  );
}

Widget _statRow(BuildContext context, String label, String value) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ],
    ),
  );
}
