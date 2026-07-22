import 'package:flureadium/flureadium.dart';

import 'reading_position.dart';
import 'position_precision.dart';

/// Result of a Locator → [ReadingPosition] mapping.
class PositionMappingResult {
  final ReadingPosition position;
  final PositionPrecision precision;

  const PositionMappingResult({
    required this.position,
    required this.precision,
  });
}

/// Bidirectional mapper between Readium [Locator] and domain [ReadingPosition].
///
/// ## Design
/// - **Locator → ReadingPosition**: href → chapterIndex → text match → charOffset
/// - **ReadingPosition → Locator**: chapterIndex → href → construct text Locator
///
/// ## Fallback chain
/// ```
/// exact text match → contextual match → progression estimate → chapter start
/// ```
///
/// ## Thread safety
/// This class is stateless and can be used by multiple sessions.
class ReadiumPositionMapper {
  /// Build a chapter index → href mapping from [Publication.readingOrder].
  ///
  /// Returns a map of `chapterIndex → href` using spine order.
  /// Returns empty map when reading order is empty.
  static Map<int, String> buildHrefMapping(Publication publication) {
    final map = <int, String>{};
    for (var i = 0; i < publication.readingOrder.length; i++) {
      final link = publication.readingOrder[i];
      if (link.href.isNotEmpty) {
        map[i] = link.href;
      }
    }
    return map;
  }

  /// Map a Locator href to a chapter index using the reading order mapping.
  ///
  /// Returns null if no match is found.
  static int? hrefToChapterIndex(String href, Map<int, String> hrefMapping) {
    // Remove fragment
    final base = href.contains('#') ? href.split('#').first : href;

    // 1. Exact match
    for (final entry in hrefMapping.entries) {
      if (entry.value == base) return entry.key;
    }

    // 2. Basename match (e.g. "chapter1.xhtml")
    final basename = base.split('/').last;
    for (final entry in hrefMapping.entries) {
      final entryBasename = entry.value.split('/').last;
      if (entryBasename == basename) return entry.key;
    }

    // 3. Suffix match (e.g. "OEBPS/chapter1.xhtml" matches ".../OEBPS/chapter1.xhtml")
    for (final entry in hrefMapping.entries) {
      if (entry.value.endsWith(base) || base.endsWith(entry.value)) {
        return entry.key;
      }
    }

    return null;
  }

  /// Map a Locator to a [ReadingPosition] using the chapter's plain text.
  ///
  /// [hrefMapping] maps chapterIndex → href (from [buildHrefMapping]).
  /// [getChapterPlainText] should return the chapter's plain text by index.
  /// Returns a [PositionMappingResult] with precision level.
  static PositionMappingResult locatorToPosition({
    required Locator locator,
    required Map<int, String> hrefMapping,
    required String Function(int chapterIndex) getChapterPlainText,
  }) {
    // Step 1: Map href → chapterIndex
    final href = locator.href;
    if (href.isEmpty) {
      return _fallbackPosition(0, 0.0);
    }

    final chapterIndex = hrefToChapterIndex(href, hrefMapping);
    if (chapterIndex == null) {
      // Unknown href — return approximate fallback
      return _fallbackPosition(0, locator.locations?.totalProgression ?? 0.0);
    }

    // Step 2: Try text-based mapping
    final text = locator.text;
    if (text != null) {
      final context = _buildSearchContext(text);
      if (context.isNotEmpty) {
        final plainText = getChapterPlainText(chapterIndex);
        if (plainText.isNotEmpty) {
          final result = _findInPlainText(context, plainText, chapterIndex);
          if (result != null) return result;
        }
      }
    }

    // Step 3: Fall back to progression within the chapter
    final progression =
        locator.locations?.progression ??
        locator.locations?.totalProgression ??
        0.0;
    return _fallbackPosition(chapterIndex, progression);
  }

  /// Build a search context string from [LocatorText].
  static String _buildSearchContext(LocatorText text) {
    final parts = <String>[];
    if (text.before != null && text.before!.isNotEmpty) {
      parts.add(text.before!);
    }
    if (text.highlight != null && text.highlight!.isNotEmpty) {
      parts.add(text.highlight!);
    }
    if (text.after != null && text.after!.isNotEmpty) {
      parts.add(text.after!);
    }
    return parts.join('');
  }

  /// Search for [context] in [plainText] and return the position.
  static PositionMappingResult? _findInPlainText(
    String context,
    String plainText,
    int chapterIndex,
  ) {
    final index = plainText.indexOf(context);
    if (index >= 0) {
      return PositionMappingResult(
        position: ReadingPosition(
          chapterIndex: chapterIndex,
          charOffsetUtf16: index,
        ),
        precision: PositionPrecision.exact,
      );
    }

    // Try with the highlight part only (if available)
    // (context may contain whitespace differences)
    final words = context.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length > 3) {
        final wordIndex = plainText.indexOf(word);
        if (wordIndex >= 0) {
          return PositionMappingResult(
            position: ReadingPosition(
              chapterIndex: chapterIndex,
              charOffsetUtf16: wordIndex,
            ),
            precision: PositionPrecision.contextual,
          );
        }
      }
    }

    return null;
  }

  /// Fallback position using progression within the chapter.
  static PositionMappingResult _fallbackPosition(
    int chapterIndex,
    double progression,
  ) {
    // Use progression as character offset estimate.
    // This is approximate but prevents returning charOffset=0.
    final estimatedOffset = (progression * 1000).round();
    return PositionMappingResult(
      position: ReadingPosition(
        chapterIndex: chapterIndex,
        charOffsetUtf16: estimatedOffset,
      ),
      precision: PositionPrecision.approximate,
    );
  }

  /// Build a Locator from a [ReadingPosition].
  ///
  /// Used for restoration when no Locator hint is available.
  static Locator positionToLocator({
    required ReadingPosition position,
    required Map<int, String> hrefMapping,
    required String Function(int chapterIndex) getChapterPlainText,
  }) {
    final href = hrefMapping[position.chapterIndex];
    if (href == null) {
      // Fallback: empty locator pointing to chapter start
      return const Locator(href: '', type: 'application/xhtml+xml');
    }

    // Try to get text context around the charOffset
    String? before;
    String? highlight;
    String? after;

    final plainText = getChapterPlainText(position.chapterIndex);
    if (plainText.isNotEmpty) {
      final offset = position.charOffsetUtf16;
      final beforeStart = (offset - 50).clamp(0, plainText.length);
      final highlightEnd = (offset + 20).clamp(0, plainText.length);
      final afterEnd = (offset + 100).clamp(0, plainText.length);

      before = plainText.substring(beforeStart, offset);
      highlight = plainText.substring(offset, highlightEnd);
      after = plainText.substring(highlightEnd, afterEnd);
    }

    return Locator(
      href: href,
      type: 'application/xhtml+xml',
      text: LocatorText(before: before, highlight: highlight, after: after),
      locations: Locations(
        totalProgression: position.chapterIndex > 0
            ? (position.chapterIndex /
                      (hrefMapping.length).clamp(1, hrefMapping.length))
                  .toDouble()
            : 0.0,
      ),
    );
  }
}
