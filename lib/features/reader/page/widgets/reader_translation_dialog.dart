import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 译文输入对话框。
///
/// 支持手动粘贴和 API 翻译两种方式。
class ReaderTranslationDialog extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final bool translationConfigured;
  final VoidCallback? onTranslateWithApi;

  const ReaderTranslationDialog({
    super.key,
    required this.onChanged,
    this.translationConfigured = false,
    this.onTranslateWithApi,
  });

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
            if (translationConfigured && onTranslateWithApi != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTranslateWithApi,
                  icon: const Icon(Icons.translate),
                  label: Text(l10n.translationTranslateWithApi),
                ),
              ),
            ],
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
