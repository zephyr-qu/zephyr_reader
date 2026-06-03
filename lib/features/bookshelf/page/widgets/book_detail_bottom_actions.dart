import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 底部操作按钮行：编辑元数据 / 导出笔记 / 删除书籍
class BookDetailBottomActions extends StatelessWidget {
  final VoidCallback onEditMetadata;
  final VoidCallback onExportNotes;
  final VoidCallback onDeleteBook;

  const BookDetailBottomActions({
    super.key,
    required this.onEditMetadata,
    required this.onExportNotes,
    required this.onDeleteBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onEditMetadata,
              icon: const Icon(PhosphorIconsRegular.pencilLine, size: 16),
              label: Text(
                l10n.editMetadata,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: theme.dividerColor),
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onExportNotes,
              icon: const Icon(PhosphorIconsRegular.fileArrowUp, size: 16),
              label: Text(
                l10n.exportNotes,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                foregroundColor: const Color(0xFFEF5350),
              ),
              onPressed: onDeleteBook,
              icon: const Icon(PhosphorIconsRegular.trash, size: 16),
              label: Text(
                l10n.deleteBook,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
