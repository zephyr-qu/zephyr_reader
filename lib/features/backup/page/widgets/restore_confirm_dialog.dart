library;

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
      title: const Row(
        children: [
          Icon(PhosphorIconsRegular.warning, color: Colors.orange, size: 22),
          SizedBox(width: 8),
          Text('确认还原'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '此操作将覆盖当前所有数据。请确认该备份文件来源可信。',
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
                _statRow(ctx, '备份版本', manifest.appVersion),
                _statRow(ctx, '导出时间',
                    DateTime.fromMillisecondsSinceEpoch(manifest.exportedAt * 1000)
                        .toString()
                        .substring(0, 19)),
                _statRow(ctx, '书籍', '${manifest.stats.books} 本'),
                _statRow(ctx, '笔记', '${manifest.stats.notes} 条'),
                _statRow(ctx, '书签', '${manifest.stats.bookmarks} 个'),
                _statRow(ctx, '生词', '${manifest.stats.vocabularyWords} 个'),
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
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('确认还原'),
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
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
      ],
    ),
  );
}
