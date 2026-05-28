import 'package:flutter/material.dart';

@immutable
class ReaderRenderConfig {
  final Color textColor;
  final Color backgroundColor;
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final String searchQuery;
  final bool searchMatchHighlight;
  final bool showVocabularyMark;
  final Set<String> vocabularyWords;

  const ReaderRenderConfig({
    required this.textColor,
    required this.backgroundColor,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.pageMargin,
    required this.searchQuery,
    required this.searchMatchHighlight,
    required this.showVocabularyMark,
    required this.vocabularyWords,
  });

  Set<String> get effectiveVocabWords =>
      showVocabularyMark ? vocabularyWords : const {};
}
