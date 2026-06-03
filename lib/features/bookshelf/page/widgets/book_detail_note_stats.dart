import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 高亮 / 批注 / 生词 统计卡片行
class BookDetailNoteStats extends StatelessWidget {
  final int highlightCount;
  final int annotationCount;
  final int vocabCount;
  final VoidCallback? onHighlightsTap;
  final VoidCallback? onAnnotationsTap;
  final VoidCallback? onVocabularyTap;

  const BookDetailNoteStats({
    super.key,
    required this.highlightCount,
    required this.annotationCount,
    required this.vocabCount,
    this.onHighlightsTap,
    this.onAnnotationsTap,
    this.onVocabularyTap,
  });

  @override
  Widget build(BuildContext context) {
    if (highlightCount == 0 && annotationCount == 0 && vocabCount == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _noteStatCard(
            theme,
            '$highlightCount',
            l10n.highlightsCount,
            const Color(0xFFFFA726),
            Colors.orange.shade50,
            onHighlightsTap ?? () {},
          ),
          const SizedBox(width: 8),
          _noteStatCard(
            theme,
            '$annotationCount',
            l10n.notesCount,
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            onAnnotationsTap ?? () {},
          ),
          const SizedBox(width: 8),
          _noteStatCard(
            theme,
            '$vocabCount',
            l10n.vocabularyCount,
            const Color(0xFFAB47BC),
            Colors.purple.shade50,
            onVocabularyTap ?? () {},
          ),
        ],
      ),
    );
  }

  Widget _noteStatCard(
    ThemeData theme,
    String count,
    String label,
    Color color,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.light
                ? bgColor
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                count,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
