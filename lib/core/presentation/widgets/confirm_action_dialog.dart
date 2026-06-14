import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// Shows a confirmation dialog with warning icon, title, content text,
/// and cancel/confirm buttons.
///
/// After the user confirms, [onConfirm] is called. The cancel button text
/// is taken from [AppLocalizations.cancel].
Future<void> showConfirmActionDialog(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  required VoidCallback onConfirm,
  Color? confirmColor,
}) async {
  final cs = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(PhosphorIconsRegular.warning, size: IconSize.leading, color: cs.error),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18)),
        ],
      ),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            AppLocalizations.of(ctx)!.cancel,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor ?? cs.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    onConfirm();
  }
}
