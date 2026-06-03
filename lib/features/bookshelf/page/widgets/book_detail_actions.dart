import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 继续阅读 / 从头开始 按钮行
class BookDetailActions extends StatelessWidget {
  final String? currentChapterTitle;
  final bool hasProgress;
  final VoidCallback onContinueReading;
  final VoidCallback onReadFromBeginning;

  const BookDetailActions({
    super.key,
    this.currentChapterTitle,
    required this.hasProgress,
    required this.onContinueReading,
    required this.onReadFromBeginning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: onContinueReading,
                child: Text(
                  hasProgress
                      ? '${l10n.continueReading}${currentChapterTitle != null ? ' · $currentChapterTitle' : ''}'
                      : l10n.startReading,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: theme.dividerColor),
                ),
                onPressed: onReadFromBeginning,
                child: Text(
                  l10n.readFromBeginning,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
