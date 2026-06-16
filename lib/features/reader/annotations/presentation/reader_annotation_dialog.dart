import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 笔记添加/编辑对话框。
///
/// `initialContent` 为空时为创建模式，非空时为编辑模式（标题显示「编辑笔记」）。
class ReaderAnnotationDialog extends HookWidget {
  final String selectedText;
  final String? initialContent;
  final ValueChanged<String> onSave;

  const ReaderAnnotationDialog({
    super.key,
    required this.selectedText,
    this.initialContent,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialContent ?? '');
    final isEditing = initialContent != null;
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(isEditing ? l10n.editNote : l10n.addNote),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(Spacing.sm.value),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(RadiusSize.md.value),
              ),
              child: Text(
                selectedText,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.noteHintText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            onSave(controller.text);
            Navigator.of(context).pop();
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
