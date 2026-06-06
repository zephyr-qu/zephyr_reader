import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 译文输入对话框。
class ReaderTranslationDialog extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const ReaderTranslationDialog({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.setBilingualTranslation),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.pasteTranslationHint),
            const SizedBox(height: 12),
            TextField(
              maxLines: 8,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.pasteTranslationPlaceholder,
              ),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}
