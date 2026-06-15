import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/statistics/application/reading_sessions_view_model.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/reading_session_book_group.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/reading_session_overview_card.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读会话列表页面。
///
/// 展示历史阅读会话记录，按日期分组显示每次阅读的时长和书籍。
/// 使用 [ReadingSessionsViewModel] 加载阅读会话数据。
class ReadingSessionsPage extends HookWidget {
  const ReadingSessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => ReadingSessionsViewModel());
    useEffect(() {
      unawaited(vm.load());
      return null;
    }, []);
    final AsyncState<List<ReadingSession>> sessionsState = useSignalValue(
      vm.sessions,
    );
    final Map<String, Book> bookCache = useSignalValue(vm.bookCache);

    Future<void> deleteSessionsByBook(String bookId) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.deleteSessionTitle),
          content: Text(l10n.deleteSessionConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await vm.deleteSessionsByBook(bookId);
      }
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.readingSessions),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: () => vm.load(),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _buildBody(
        l10n,
        cs,
        sessionsState,
        bookCache,
        deleteSessionsByBook,
        () => vm.load(),
        context,
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    ColorScheme cs,
    AsyncState<List<ReadingSession>> sessionsState,
    Map<String, Book> bookCache,
    Future<void> Function(String) deleteSessionsByBook,
    VoidCallback onRetry,
    BuildContext context,
  ) {
    return switch (sessionsState) {
      AsyncLoading() => const Center(child: CircularProgressIndicator()),
      AsyncError(:final error) => _buildError(
        l10n,
        cs,
        error,
        onRetry,
        context,
      ),
      AsyncData(:final value) => _buildSessionList(
        l10n,
        cs,
        value,
        bookCache,
        deleteSessionsByBook,
      ),
    };
  }

  Widget _buildError(
    AppLocalizations l10n,
    ColorScheme cs,
    Object error,
    VoidCallback onRetry,
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.warningCircle, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(
              l10n.loadFailed,
              style: TextStyle(fontSize: 16, color: cs.error),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionList(
    AppLocalizations l10n,
    ColorScheme cs,
    List<ReadingSession> sessions,
    Map<String, Book> bookCache,
    Future<void> Function(String) deleteSessionsByBook,
  ) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.clockCounterClockwise,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noSessions,
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.autoRecordHint,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<ReadingSession>>{};
    for (final s in sessions) {
      grouped.putIfAbsent(s.bookId, () => []).add(s);
    }

    final totalDuration = sessions.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final totalSessions = sessions.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ReadingSessionOverviewCard(
          totalSessions: totalSessions,
          totalDuration: totalDuration,
        ),
        const SizedBox(height: 20),
        Text(
          l10n.sessionDetails,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const Divider(height: 12),
        ...grouped.entries.map(
          (entry) => ReadingSessionBookGroup(
            bookId: entry.key,
            sessions: entry.value,
            bookCache: bookCache,
            onDelete: () => deleteSessionsByBook(entry.key),
          ),
        ),
      ],
    );
  }
}
