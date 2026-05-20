library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ReadingSessionsPage extends StatefulWidget {
  const ReadingSessionsPage({super.key});

  @override
  State<ReadingSessionsPage> createState() => _ReadingSessionsPageState();
}

class _ReadingSessionsPageState extends State<ReadingSessionsPage> {
  final _storage = getIt<RustStorageService>();
  List<ReadingSession> _sessions = [];
  Map<String, Book> _bookCache = {};
  bool _loaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _storage.getRecentSessions(100),
        _storage.getAllBooks(),
      ]);
      final sessions = results[0] as List<ReadingSession>;
      final books = results[1] as List<Book>;
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _bookCache = {for (final b in books) b.bookId: b};
          _loaded = true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteSessionsByBook(String bookId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除会话记录'),
        content: const Text('确定要删除本书的所有阅读会话记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storage.deleteSessionsByBook(bookId);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final grouped = <String, List<ReadingSession>>{};
    for (final s in _sessions) {
      grouped.putIfAbsent(s.bookId, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读会话'),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
              onPressed: _load,
              tooltip: '刷新',
            ),
        ],
      ),
      body: _buildBody(theme, grouped),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    Map<String, List<ReadingSession>> grouped,
  ) {
    if (!_loaded && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.clockCounterClockwise,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无阅读会话',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '开始阅读后会自动记录',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final totalDuration = _sessions.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final totalSessions = _sessions.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildOverview(theme, totalSessions, totalDuration),
        const SizedBox(height: 20),
        Text(
          '会话详情',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const Divider(height: 12),
        ...grouped.entries.map(
          (entry) => _buildBookSessionGroup(theme, entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildOverview(ThemeData theme, int totalSessions, int totalDuration) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDuration(totalDuration),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  '总阅读时长',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalSessions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                '次会话',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookSessionGroup(
    ThemeData theme,
    String bookId,
    List<ReadingSession> sessions,
  ) {
    final book = _bookCache[bookId];
    final bookTitle = book?.title ?? '未知书籍';
    final totalTime = sessions.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final totalChars = sessions.fold<int>(
      0,
      (sum, s) => sum + (s.endCharOffset - s.startCharOffset),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bookTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => _deleteSessionsByBook(bookId),
                child: Icon(
                  PhosphorIconsRegular.trash,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '共 ${sessions.length} 次 · ${_formatDuration(totalTime)} · 阅读 ${_formatChars(totalChars)}',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...sessions.map((s) => _buildSessionTile(theme, s, book)),
      ],
    );
  }

  Widget _buildSessionTile(
    ThemeData theme,
    ReadingSession session,
    Book? book,
  ) {
    final dateStr = DateFormat('MM/dd HH:mm').format(session.startedAt);
    final duration = _formatDuration(session.durationSeconds);
    final chars = session.endCharOffset - session.startCharOffset;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.playCircle,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '第 ${session.chapterIndex} 章 · ${_formatChars(chars)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            duration,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds < 3600) return '${seconds ~/ 60}分钟';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '$h小时$m分钟';
  }

  String _formatChars(int chars) {
    if (chars < 1000) return '$chars字';
    return '${(chars / 1000).toStringAsFixed(1)}千字';
  }
}
