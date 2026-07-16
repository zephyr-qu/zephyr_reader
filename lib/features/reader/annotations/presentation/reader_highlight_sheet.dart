import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';


/// 高亮操作底部菜单。
class ReaderHighlightSheet extends StatelessWidget {
  final Note note;
  final VoidCallback? onEdit;
  final Future<void> Function() onDelete;

  const ReaderHighlightSheet({
    super.key,
    required this.note,
    this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.noteType == NoteType.annotation)
            ListTile(
              leading: const Icon(PhosphorIconsRegular.notePencil),
              title: Text(l10n.editNote),
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.trash, color: Colors.red),
            title: Text(
              l10n.deleteHighlight,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () async {
              Navigator.pop(context);
              await onDelete();
            },
          ),
        ],
      ),
    );
  }
}
