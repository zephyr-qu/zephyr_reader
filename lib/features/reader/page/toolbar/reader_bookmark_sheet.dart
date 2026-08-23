import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';

/// 当前书籍的书签侧栏。
class ReaderBookmarkDrawer extends StatefulWidget {
  final List<Bookmark> bookmarks;
  final ReaderThemeExtension readerTheme;
  final ValueChanged<Bookmark> onSelect;
  final Future<void> Function(Bookmark) onDelete;

  const ReaderBookmarkDrawer({
    super.key,
    required this.bookmarks,
    required this.readerTheme,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<ReaderBookmarkDrawer> createState() => _ReaderBookmarkDrawerState();
}

class _ReaderBookmarkDrawerState extends State<ReaderBookmarkDrawer> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _deletingIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final query = _searchController.text.trim().toLowerCase();
    final visibleBookmarks = query.isEmpty
        ? widget.bookmarks
        : widget.bookmarks
              .where((entry) => entry.title.toLowerCase().contains(query))
              .toList();

    return Drawer(
      backgroundColor: readerTheme.backgroundColor,
      child: Column(
        children: [
          Container(
            color: readerTheme.surfaceColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _isSearching
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: l10n.search,
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: TextStyle(
                                color: readerTheme.textColor,
                                fontSize: 16,
                              ),
                            )
                          : Text(
                              '${l10n.bookmarks} (${widget.bookmarks.length})',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: readerTheme.textColor,
                              ),
                            ),
                    ),
                    IconButton(
                      tooltip: _isSearching ? l10n.closeSearch : l10n.search,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: Icon(
                        _isSearching
                            ? PhosphorIconsLight.x
                            : PhosphorIconsLight.magnifyingGlass,
                        color: readerTheme.textColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) _searchController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: visibleBookmarks.isEmpty
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
                            query.isEmpty ? l10n.addBookmark : l10n.search,
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
                    itemCount: visibleBookmarks.length,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemBuilder: (context, index) {
                      final entry = visibleBookmarks[index];
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
                            onPressed: isDeleting ? null : () => _delete(entry),
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
