import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 文本高亮绘制器。
///
/// 使用 TextPainter 在文本上绘制高亮背景，支持笔记高亮、搜索匹配和生词标记三种颜色。
/// 内置缓存机制，在输入不变时跳过重复绘制。
class HighlightPainter {
  HighlightPainter._();

  static int _paintVersion = 0;

  /// Call this when highlights, search query, or vocabulary words change
  static void invalidateCache() {
    _paintVersion++;
  }

  static int _lastPlainVersion = -1;
  static String _lastPlainContent = '';
  static List<Note> _lastPlainHighlights = [];
  static Set<String> _lastPlainVocab = const {};
  static int _lastPlainContentStart = 0;
  static TextSpan? _cachedPlainResult;

  static int _lastRichVersion = -1;
  static TextSpan? _lastRichSpan;
  static int _lastRichContentStart = 0;
  static List<Note> _lastRichHighlights = [];
  static Set<String> _lastRichVocab = const {};
  static TextSpan? _cachedRichResult;

  /// 给纯文本段落应用高亮背景色，可选搜索高亮和生词标记
  ///
  /// [contentStart] 是这段文本在章内的全局字符偏移（分页模式各页不同）。
  /// 未传入时（默认 0），行为与原来一致。
  static TextSpan paintPlain(
    String content,
    TextStyle baseStyle,
    List<Note> highlights, {
    void Function(Note)? onHighlightTap,
    Set<String> vocabularyWords = const {},
    int contentStart = 0,
  }) {
    if ((highlights.isEmpty && vocabularyWords.isEmpty) || content.isEmpty) {
      return TextSpan(text: content, style: baseStyle);
    }
    if (_paintVersion == _lastPlainVersion &&
        _lastPlainContent == content &&
        _listEquals(_lastPlainHighlights, highlights) &&
        _setEquals(_lastPlainVocab, vocabularyWords) &&
        _lastPlainContentStart == contentStart) {
      return _cachedPlainResult!;
    }
    final spans = <InlineSpan>[];

    // Build regions: highlight spans
    final regions = <_Region>[];
    final pageEnd = contentStart + content.length;
    var offset = 0;

    // Highlight regions
    for (final h in highlights) {
      final hStart = h.charOffset.toInt();
      final hEnd = hStart + h.length.toInt();

      // Skip highlights entirely outside this page's range
      if (hEnd <= contentStart || hStart >= pageEnd) continue;

      // Translate to page-local offsets
      final localHStart = hStart > contentStart ? hStart - contentStart : 0;
      final localHEnd = hEnd - contentStart;

      if (localHEnd <= offset || localHStart >= content.length) continue;
      final overlapStart = localHStart > offset ? localHStart : offset;
      final overlapEnd = localHEnd < content.length
          ? localHEnd
          : content.length;
      if (overlapStart > offset) {
        regions.add(
          _Region.text(content.substring(offset, overlapStart), baseStyle),
        );
      }
      final highlightColor = Color(h.highlightColor ?? 0xFFFFEB3B);
      regions.add(
        _Region.highlight(
          content.substring(overlapStart, overlapEnd),
          baseStyle.copyWith(
            background: Paint()..color = highlightColor.withAlpha(77),
          ),
          onHighlightTap != null
              ? (TapGestureRecognizer()..onTap = () => onHighlightTap(h))
              : null,
          highlightColor,
        ),
      );
      offset = overlapEnd;
    }
    if (offset < content.length) {
      regions.add(_Region.text(content.substring(offset), baseStyle));
    }

    // If no highlights, create single text region
    if (regions.isEmpty && content.isNotEmpty) {
      regions.add(_Region.text(content, baseStyle));
    }

    for (final r in regions) {
      if (r.isHighlight) {
        spans.add(
          WidgetSpan(
            child: Container(
              width: 2,
              height: double.infinity,
              color: r.highlightBarColor,
            ),
          ),
        );
      }
      if (r.recognizer != null) {
        spans.add(
          TextSpan(text: r.text, style: r.style, recognizer: r.recognizer),
        );
      } else {
        spans.add(TextSpan(text: r.text, style: r.style));
      }
    }
    var result = TextSpan(children: spans);
    if (vocabularyWords.isNotEmpty) {
      result = _paintVocabulary(content, result, vocabularyWords);
    }
    _lastPlainVersion = _paintVersion;
    _lastPlainContent = content;
    _lastPlainHighlights = List.from(highlights);
    _lastPlainVocab = Set.from(vocabularyWords);
    _lastPlainContentStart = contentStart;
    _cachedPlainResult = result;
    return result;
  }

  static TextSpan _paintVocabulary(
    String text,
    TextSpan span,
    Set<String> words,
  ) {
    final matches = <_WordMatch>[];
    final wordRegex = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)?");
    for (final m in wordRegex.allMatches(text)) {
      if (words.contains(m.group(0)!.toLowerCase())) {
        matches.add(_WordMatch(m.start, m.end));
      }
    }
    if (matches.isEmpty) return span;
    return _applyWordMarks(span, matches, 0);
  }

  static TextSpan _applyWordMarks(
    TextSpan span,
    List<_WordMatch> matches,
    int offset,
  ) {
    if (span.text != null) {
      final text = span.text!;
      final localMatches = matches
          .where((m) => m.start >= offset && m.end <= offset + text.length)
          .map((m) => _WordMatch(m.start - offset, m.end - offset))
          .toList();
      if (localMatches.isEmpty) return span;
      final children = <InlineSpan>[];
      var pos = 0;
      for (final m in localMatches) {
        if (m.start > pos) {
          children.add(
            TextSpan(text: text.substring(pos, m.start), style: span.style),
          );
        }
        children.add(
          TextSpan(
            text: text.substring(m.start, m.end),
            style: (span.style ?? const TextStyle()).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF4CAF50),
              decorationStyle: TextDecorationStyle.dotted,
            ),
          ),
        );
        pos = m.end;
      }
      if (pos < text.length) {
        children.add(TextSpan(text: text.substring(pos), style: span.style));
      }
      return TextSpan(children: children, style: span.style);
    }
    if (span.children == null || span.children!.isEmpty) return span;
    final newChildren = <InlineSpan>[];
    var childOffset = offset;
    for (final child in span.children!) {
      if (child is TextSpan) {
        final len = _textSpanLength(child);
        newChildren.add(_applyWordMarks(child, matches, childOffset));
        childOffset += len;
      } else {
        newChildren.add(child);
      }
    }
    return TextSpan(children: newChildren, style: span.style);
  }

  static int _textSpanLength(TextSpan span) {
    if (span.text != null) return span.text!.length;
    if (span.children != null) {
      var len = 0;
      for (final child in span.children!) {
        if (child is TextSpan) len += _textSpanLength(child);
      }
      return len;
    }
    return 0;
  }

  /// 给富文本 TextSpan 应用高亮背景色和生词标记
  static TextSpan paintRich(
    TextSpan span,
    int contentStart,
    List<Note> highlights, {
    void Function(Note)? onHighlightTap,
    Set<String> vocabularyWords = const {},
  }) {
    if (_paintVersion == _lastRichVersion &&
        _lastRichSpan == span &&
        _lastRichContentStart == contentStart &&
        _listEquals(_lastRichHighlights, highlights) &&
        _setEquals(_lastRichVocab, vocabularyWords)) {
      return _cachedRichResult!;
    }
    if (highlights.isEmpty) {
      if (vocabularyWords.isNotEmpty && span.text != null) {
        _lastRichVersion = _paintVersion;
        _lastRichSpan = span;
        _lastRichContentStart = contentStart;
        _lastRichHighlights = List.from(highlights);
        _lastRichVocab = Set.from(vocabularyWords);
        _cachedRichResult = _paintVocabulary(span.text!, span, vocabularyWords);
        return _cachedRichResult!;
      }
      _lastRichVersion = _paintVersion;
      _lastRichSpan = span;
      _lastRichContentStart = contentStart;
      _lastRichHighlights = List.from(highlights);
      _lastRichVocab = Set.from(vocabularyWords);
      _cachedRichResult = span;
      return span;
    }
    if (span.children != null && span.children!.isNotEmpty) {
      final children = <InlineSpan>[];
      var childOffset = contentStart;
      for (final child in span.children!) {
        if (child is TextSpan) {
          final len = _textSpanLength(child);
          children.add(
            paintRich(
              child,
              childOffset,
              highlights,
              onHighlightTap: onHighlightTap,
              vocabularyWords: vocabularyWords,
            ),
          );
          childOffset += len;
        } else {
          children.add(child);
        }
      }
      _lastRichVersion = _paintVersion;
      _lastRichSpan = span;
      _lastRichContentStart = contentStart;
      _lastRichHighlights = List.from(highlights);
      _lastRichVocab = Set.from(vocabularyWords);
      _cachedRichResult = TextSpan(children: children, style: span.style);
      return _cachedRichResult!;
    }
    final text = span.text;
    if (text == null || text.isEmpty) return span;
    final baseStyle = span.style ?? const TextStyle();
    final result = <InlineSpan>[];
    var offset = 0;

    final regions = <_Region>[];

    for (final h in highlights) {
      final hStart = h.charOffset.toInt();
      final hEnd = hStart + h.length.toInt();
      final localStart = hStart - contentStart;
      final localEnd = hEnd - contentStart;
      if (localEnd <= 0 || localStart >= text.length) continue;
      final overlapStart = localStart > 0 ? localStart : 0;
      final overlapEnd = localEnd < text.length ? localEnd : text.length;
      if (overlapStart > offset) {
        regions.add(
          _Region.text(text.substring(offset, overlapStart), baseStyle),
        );
      }
      final highlightColor = Color(h.highlightColor ?? 0xFFFFEB3B);
      regions.add(
        _Region.highlight(
          text.substring(overlapStart, overlapEnd),
          baseStyle.copyWith(
            background: Paint()..color = highlightColor.withAlpha(77),
          ),
          onHighlightTap != null
              ? (TapGestureRecognizer()..onTap = () => onHighlightTap(h))
              : null,
          highlightColor,
        ),
      );
      offset = overlapEnd;
    }
    if (offset < text.length) {
      regions.add(_Region.text(text.substring(offset), baseStyle));
    }

    if (regions.isEmpty) {
      if (vocabularyWords.isNotEmpty) {
        _lastRichVersion = _paintVersion;
        _lastRichSpan = span;
        _lastRichContentStart = contentStart;
        _lastRichHighlights = List.from(highlights);
        _lastRichVocab = Set.from(vocabularyWords);
        _cachedRichResult = _paintVocabulary(text, span, vocabularyWords);
        return _cachedRichResult!;
      }
      _lastRichVersion = _paintVersion;
      _lastRichSpan = span;
      _lastRichContentStart = contentStart;
      _lastRichHighlights = List.from(highlights);
      _lastRichVocab = Set.from(vocabularyWords);
      _cachedRichResult = span;
      return span;
    }

    for (final r in regions) {
      if (r.isHighlight) {
        result.add(
          WidgetSpan(
            child: Container(
              width: 2,
              height: double.infinity,
              color: r.highlightBarColor,
            ),
          ),
        );
      }
      if (r.recognizer != null) {
        result.add(
          TextSpan(text: r.text, style: r.style, recognizer: r.recognizer),
        );
      } else {
        result.add(TextSpan(text: r.text, style: r.style));
      }
    }
    var finalSpan = TextSpan(children: result, style: span.style);
    if (vocabularyWords.isNotEmpty) {
      finalSpan = _paintVocabulary(text, finalSpan, vocabularyWords);
    }
    _lastRichVersion = _paintVersion;
    _lastRichSpan = span;
    _lastRichContentStart = contentStart;
    _lastRichHighlights = List.from(highlights);
    _lastRichVocab = Set.from(vocabularyWords);
    _cachedRichResult = finalSpan;
    return finalSpan;
  }

  static bool _listEquals(List<Note> a, List<Note> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final na = a[i], nb = b[i];
      if (na.id != nb.id ||
          na.charOffset != nb.charOffset ||
          na.length != nb.length) {
        return false;
      }
    }
    return true;
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

class _Region {
  final String text;
  final TextStyle style;
  final TapGestureRecognizer? recognizer;
  final bool isHighlight;
  final Color? highlightBarColor;
  _Region._({
    required this.text,
    required this.style,
    this.recognizer,
    this.isHighlight = false,
    this.highlightBarColor,
  });
  factory _Region.text(String text, TextStyle style) =>
      _Region._(text: text, style: style);
  factory _Region.highlight(
    String text,
    TextStyle style,
    TapGestureRecognizer? r,
    Color highlightColor,
  ) => _Region._(
    text: text,
    style: style,
    recognizer: r,
    isHighlight: true,
    highlightBarColor: highlightColor,
  );
}

class _WordMatch {
  final int start;
  final int end;
  _WordMatch(this.start, this.end);
}
