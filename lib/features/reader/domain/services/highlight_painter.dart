import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:zephyr_reader/src/rust/storage/models.dart';

class HighlightPainter {
  HighlightPainter._();

  /// 给纯文本段落应用高亮背景色，可选搜索高亮和生词标记
  static TextSpan paintPlain(
    String content,
    TextStyle baseStyle,
    List<Note> highlights, {
    void Function(Note)? onHighlightTap,
    String? searchQuery,
    bool searchMatchHighlight = false,
    Set<String> vocabularyWords = const {},
  }) {
    if ((highlights.isEmpty && (searchQuery == null || searchQuery.isEmpty)) || content.isEmpty) {
      if (vocabularyWords.isNotEmpty) {
        return _paintVocabulary(content, TextSpan(text: content, style: baseStyle), vocabularyWords);
      }
      return TextSpan(text: content, style: baseStyle);
    }
    final spans = <TextSpan>[];
    var offset = 0;

    // Build regions: highlight spans + search matches
    final regions = <_Region>[];

    // Highlight regions
    for (final h in highlights) {
      final hStart = h.charOffset.toInt();
      final hEnd = hStart + h.length.toInt();
      if (hEnd <= offset || hStart >= content.length) continue;
      final overlapStart = hStart > offset ? hStart : offset;
      final overlapEnd = hEnd < content.length ? hEnd : content.length;
      if (overlapStart > offset) {
        regions.add(_Region.text(content.substring(offset, overlapStart), baseStyle));
      }
      regions.add(_Region.highlight(
        content.substring(overlapStart, overlapEnd),
        baseStyle.copyWith(
          background: Paint()..color = Color(h.highlightColor ?? 0xFFFFEB3B).withAlpha(77),
        ),
        onHighlightTap != null
            ? (TapGestureRecognizer()..onTap = () => onHighlightTap(h))
            : null,
      ));
      offset = overlapEnd;
    }
    if (offset < content.length) {
      regions.add(_Region.text(content.substring(offset), baseStyle));
    }

    // If no highlights, create single text region
    if (regions.isEmpty && content.isNotEmpty) {
      regions.add(_Region.text(content, baseStyle));
    }

    // Apply search highlighting on top of existing regions
    if (searchQuery != null && searchQuery.isNotEmpty) {
      return _paintVocabulary(content,
        _applySearchHighlight(regions, searchQuery, searchMatchHighlight, baseStyle),
        vocabularyWords);
    }

    for (final r in regions) {
      if (r.recognizer != null) {
        spans.add(TextSpan(text: r.text, style: r.style, recognizer: r.recognizer));
      } else {
        spans.add(TextSpan(text: r.text, style: r.style));
      }
    }
    var result = TextSpan(children: spans);
    if (vocabularyWords.isNotEmpty) {
      result = _paintVocabulary(content, result, vocabularyWords);
    }
    return result;
  }

  static TextSpan _applySearchHighlight(
    List<_Region> regions,
    String query,
    bool highlightCurrent,
    TextStyle baseStyle,
  ) {
    final result = <TextSpan>[];
    for (final region in regions) {
      final text = region.text;
      var pos = 0;
      final lower = text.toLowerCase();
      final qLower = query.toLowerCase();
      while (pos < text.length) {
        final idx = lower.indexOf(qLower, pos);
        if (idx == -1) {
          result.add(TextSpan(text: text.substring(pos), style: region.style));
          break;
        }
        if (idx > pos) {
          result.add(TextSpan(text: text.substring(pos, idx), style: region.style));
        }
        result.add(TextSpan(
          text: text.substring(idx, idx + query.length),
          style: region.style.copyWith(
            background: Paint()..color = (highlightCurrent && idx == 0
                ? Colors.orange.withAlpha(150)
                : Colors.yellow.withAlpha(120)),
          ),
        ));
        pos = idx + query.length;
      }
    }
    return TextSpan(children: result);
  }

  static TextSpan _paintVocabulary(String text, TextSpan span, Set<String> words) {
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

  static TextSpan _applyWordMarks(TextSpan span, List<_WordMatch> matches, int offset) {
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
          children.add(TextSpan(text: text.substring(pos, m.start), style: span.style));
        }
        children.add(TextSpan(
          text: text.substring(m.start, m.end),
          style: (span.style ?? const TextStyle()).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF4CAF50),
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ));
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
    String? searchQuery,
    bool searchMatchHighlight = false,
    Set<String> vocabularyWords = const {},
  }) {
    if (highlights.isEmpty && (searchQuery == null || searchQuery.isEmpty)) {
      if (vocabularyWords.isNotEmpty && span.text != null) {
        return _paintVocabulary(span.text!, span, vocabularyWords);
      }
      return span;
    }
    if (span.children != null && span.children!.isNotEmpty) {
      final children = <InlineSpan>[];
      var childOffset = contentStart;
      for (final child in span.children!) {
        if (child is TextSpan) {
          final len = _textSpanLength(child);
          children.add(paintRich(child, childOffset, highlights,
              onHighlightTap: onHighlightTap,
              searchQuery: searchQuery,
              searchMatchHighlight: searchMatchHighlight,
              vocabularyWords: vocabularyWords));
          childOffset += len;
        } else {
          children.add(child);
        }
      }
      return TextSpan(children: children, style: span.style);
    }
    final text = span.text;
    if (text == null || text.isEmpty) return span;
    final baseStyle = span.style ?? const TextStyle();
    final result = <TextSpan>[];
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
        regions.add(_Region.text(text.substring(offset, overlapStart), baseStyle));
      }
      regions.add(_Region.highlight(
        text.substring(overlapStart, overlapEnd),
        baseStyle.copyWith(
          background: Paint()..color = Color(h.highlightColor ?? 0xFFFFEB3B).withAlpha(77),
        ),
        onHighlightTap != null
            ? (TapGestureRecognizer()..onTap = () => onHighlightTap(h))
            : null,
      ));
      offset = overlapEnd;
    }
    if (offset < text.length) {
      regions.add(_Region.text(text.substring(offset), baseStyle));
    }

    if (regions.isEmpty) {
      if (vocabularyWords.isNotEmpty) {
        return _paintVocabulary(text, span, vocabularyWords);
      }
      return span;
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchResult = _applySearchHighlight(regions, searchQuery, searchMatchHighlight, baseStyle);
      if (vocabularyWords.isNotEmpty) {
        return _paintVocabulary(text, searchResult, vocabularyWords);
      }
      return searchResult;
    }

    for (final r in regions) {
      if (r.recognizer != null) {
        result.add(TextSpan(text: r.text, style: r.style, recognizer: r.recognizer));
      } else {
        result.add(TextSpan(text: r.text, style: r.style));
      }
    }
    var finalSpan = TextSpan(children: result, style: span.style);
    if (vocabularyWords.isNotEmpty) {
      finalSpan = _paintVocabulary(text, finalSpan, vocabularyWords);
    }
    return finalSpan;
  }
}

class _Region {
  final String text;
  final TextStyle style;
  final TapGestureRecognizer? recognizer;
  _Region._({required this.text, required this.style, this.recognizer});
  factory _Region.text(String text, TextStyle style) => _Region._(text: text, style: style);
  factory _Region.highlight(String text, TextStyle style, TapGestureRecognizer? r) =>
      _Region._(text: text, style: style, recognizer: r);
}

class _WordMatch {
  final int start;
  final int end;
  _WordMatch(this.start, this.end);
}
