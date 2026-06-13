import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/go_reading_empty_state.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_list_item_tile.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// Renders the word list body — loading, error, empty, or populated.
///
/// Encapsulates the four-state rendering logic previously inlined in
/// [VocabularyPage._buildWordList].
class VocabWordListView extends StatelessWidget {
  final AsyncState<List<Vocab>> words;

  final Map<String, String> bookTitles;
  final Future<void> Function(String id) onDeleteWord;
  final Future<void> Function(String id, VocabStatus status) onUpdateStatus;
  final VoidCallback onRetry;
  final bool hasWords;

  const VocabWordListView({
    super.key,
    required this.words,
    required this.bookTitles,
    required this.onDeleteWord,
    required this.onUpdateStatus,
    required this.onRetry,
    required this.hasWords,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return words.map(
      data: (List<Vocab> words) {
        if (words.isEmpty) {
          if (hasWords) {
            // 筛选空态：有生词但当前筛选无结果
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.funnel,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.vocabFilterEmptyHint,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          // 真实空态：数据库中无生词 → 引导去阅读
          return GoReadingEmptyState(
            icon: PhosphorIconsRegular.bookOpen,
            title: l10n.noWords,
            subtitle: l10n.vocabPageEmptyHint,
            buttonLabel: l10n.goReading,
          );
        }

        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing(Spacing.md),
          ),
          itemCount: words.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = words[index];
            return VocabListItemTile(
              item: item,
              bookTitles: bookTitles,
              index: index,
              onDismissed: () => onDeleteWord(item.id),
              onUpdateStatus: (s) => onUpdateStatus(item.id, s),
            );
          },
        );
      },
      error: (Error error) => _buildError(error, theme, l10n),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError(Object err, ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            AppErrorMapper.humanReadable(err),
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}
