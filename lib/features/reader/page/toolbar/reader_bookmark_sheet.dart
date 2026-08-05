import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';

/// 当前书籍的书签面板。
class ReaderBookmarkSheet extends StatefulWidget {
  final List<Bookmark> bookmarks;
  final ReaderThemeExtension readerTheme;
  final bool isCurrentPageBookmarked;
  final Future<void> Function() onToggleCurrent;
  final ValueChanged<Bookmark> onSelect;
  final Future<void> Function(Bookmark) onDelete;

  const ReaderBookmarkSheet({
    super.key,
    required this.bookmarks,
    required this.readerTheme,
    required this.isCurrentPageBookmarked,
    required this.onToggleCurrent,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<ReaderBookmarkSheet> createState() => _ReaderBookmarkSheetState();
}

class _ReaderBookmarkSheetState extends State<ReaderBookmarkSheet> {
  bool _isTogglingCurrent = false;
  final Set<String> _deletingIds = <String>{};

  Future<void> _toggleCurrent() async {
    if (_isTogglingCurrent) return;
    setState(() => _isTogglingCurrent = true);
    try {
      await widget.onToggleCurrent();
    } finally {
      if (mounted) setState(() => _isTogglingCurrent = false);
    }
  }

  Future<void> _delete(Bookmark entry) async {
    if (_deletingIds.contains(entry.id)) return;
    setState(() => _deletingIds.add(entry.id));
    try {
      await widget.onDelete(entry);
    } finally {
      if (mounted) setState(() => _deletingIds.remove(entry.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final readerTheme = widget.readerTheme;

    return Container(
      decoration: BoxDecoration(
        color: readerTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: readerTheme.textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${l10n.bookmarks} (${widget.bookmarks.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: readerTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: readerTheme.accentColor.withValues(
                        alpha: 0.14,
                      ),
                      foregroundColor: readerTheme.accentColor,
                      disabledBackgroundColor: readerTheme.accentColor
                          .withValues(alpha: 0.08),
                      disabledForegroundColor: readerTheme.accentColor
                          .withValues(alpha: 0.6),
                    ),
                    onPressed: _isTogglingCurrent ? null : _toggleCurrent,
                    icon: _isTogglingCurrent
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: readerTheme.accentColor,
                            ),
                          )
                        : Icon(
                            widget.isCurrentPageBookmarked
                                ? PhosphorIconsFill.bookmarkSimple
                                : PhosphorIconsLight.bookmarkSimple,
                          ),
                    label: Text(
                      widget.isCurrentPageBookmarked
                          ? l10n.deleteBookmark
                          : l10n.addBookmark,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: widget.bookmarks.isEmpty
                  ? SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                        child: Column(
                          children: [
                            Icon(
                              PhosphorIconsLight.bookmarks,
                              size: 32,
                              color: readerTheme.textColor.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.addBookmark,
                              style: TextStyle(
                                color: readerTheme.textColor.withValues(
                                  alpha: 0.55,
                                ),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.bookmarks.length,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemBuilder: (context, index) {
                        final entry = widget.bookmarks[index];
                        final isDeleting = _deletingIds.contains(entry.id);
                        final title = entry.title.trim().isEmpty
                            ? '${l10n.bookmarks} ${index + 1}'
                            : entry.title;

                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            minTileHeight: 56,
                            leading: Icon(
                              PhosphorIconsLight.bookmarkSimple,
                              color: readerTheme.accentColor,
                              size: 20,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: readerTheme.textColor,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              _formatTimestamp(context, entry.createdAt),
                              style: TextStyle(
                                color: readerTheme.textColor.withValues(
                                  alpha: 0.55,
                                ),
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: l10n.deleteBookmark,
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              onPressed: isDeleting
                                  ? null
                                  : () => _delete(entry),
                              icon: isDeleting
                                  ? SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: readerTheme.accentColor,
                                      ),
                                    )
                                  : Icon(
                                      PhosphorIconsLight.trash,
                                      size: 20,
                                      color: readerTheme.textColor.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                            ),
                            onTap: isDeleting
                                ? null
                                : () => widget.onSelect(entry),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    if (DateUtils.isSameDay(now, date)) {
      return localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date));
    }
    return localizations.formatShortDate(date);
  }
}
