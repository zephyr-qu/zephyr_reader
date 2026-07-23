import 'package:flureadium/flureadium.dart';
import '../../chapter/reading_chapter.dart';

/// Maps [Publication.readingOrder] and [Publication.tableOfContents]
/// to [ReadingChapter] instances and bidirectional lookups.
///
/// ## Usage
///
/// ```dart
/// final mapper = ReadiumChapterMapper(pub);
/// final chapters = mapper.chapters;            // All chapters
/// final idx = mapper.indexForHref('ch2.xhtml'); // 1
/// final href = mapper.hrefForIndex(2);           // 'ch3.xhtml'
/// ```
class ReadiumChapterMapper {
  final List<ReadingChapter> _chapters;
  final Map<int, String> _indexToHref = {};
  final Map<String, int> _hrefToIndex = {};

  /// Build the mapper from a publication's readingOrder.
  ReadiumChapterMapper(Publication pub) : _chapters = _buildChapters(pub) {
    for (final ch in _chapters) {
      if (ch.href.isNotEmpty) {
        _indexToHref[ch.index] = ch.href;
        _hrefToIndex[ch.href] = ch.index;
      }
    }
  }

  /// All chapters in reading order.
  List<ReadingChapter> get chapters => List.unmodifiable(_chapters);

  /// Resolve [href] to a chapter index, or null.
  int? indexForHref(String href) => _hrefToIndex[_normalizeHref(href)];

  /// Resolve [chapterIndex] to an href, or empty string.
  String hrefForIndex(int chapterIndex) => _indexToHref[chapterIndex] ?? '';

  /// Chapter count.
  int get length => _chapters.length;

  /// Build a flat list of chapters from the publication's reading order,
  /// using tableOfContents titles when available.
  static List<ReadingChapter> _buildChapters(Publication pub) {
    final order = pub.readingOrder;
    final toc = pub.tableOfContents;

    // Build a quick href → title map from the TOC (flat).
    final tocTitles = <String, String>{};
    _flattenToc(toc, tocTitles);

    final chapters = <ReadingChapter>[];
    for (var i = 0; i < order.length; i++) {
      final link = order[i];
      final href = _normalizeHref(link.href);
      // Prefer TOC title; fall back to link title; then empty.
      final title = tocTitles[href] ?? link.title ?? '';
      chapters.add(
        ReadingChapter(id: link.id ?? href, index: i, title: title, href: href),
      );
    }
    return chapters;
  }

  /// Recursively flatten TOC entries into an href → title map.
  static void _flattenToc(List<Link> entries, Map<String, String> out) {
    for (final entry in entries) {
      final href = _normalizeHref(entry.href);
      if (entry.title != null && href.isNotEmpty) {
        out[href] = entry.title!;
      }
      if (entry.children.isNotEmpty) {
        _flattenToc(entry.children, out);
      }
    }
  }

  /// Strip fragment and trailing slash for consistent matching.
  static String _normalizeHref(String href) {
    // Remove fragment (#...)
    final fragIdx = href.indexOf('#');
    if (fragIdx >= 0) {
      href = href.substring(0, fragIdx);
    }
    // Remove trailing slash
    if (href.endsWith('/')) {
      href = href.substring(0, href.length - 1);
    }
    return href;
  }
}
