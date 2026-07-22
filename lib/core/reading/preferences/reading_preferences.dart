/// Unified reader preferences shared across both reading engines.
///
/// These are user-facing settings. Not all engines support every setting;
/// check [ReadingCapabilities] at runtime.
class ReadingPreferences {
  /// Font size in logical pixels.
  final double fontSize;

  /// Line height as a multiplier (e.g. 1.5 means 1.5× line spacing).
  final double lineHeight;

  /// Font family name.
  final String? fontFamily;

  /// Theme: 'light', 'sepia', 'dark'.
  final String theme;

  /// Left/right page margin in logical pixels.
  final double pageMargin;

  /// Text alignment: 'left', 'justify', etc.
  final String textAlignment;

  /// Reading mode: 'paginated' or 'scroll'.
  final String readingMode;

  const ReadingPreferences({
    this.fontSize = 16.0,
    this.lineHeight = 1.5,
    this.fontFamily,
    this.theme = 'light',
    this.pageMargin = 16.0,
    this.textAlignment = 'justify',
    this.readingMode = 'paginated',
  });

  /// Default preferences matching the app's defaults.
  static const defaults = ReadingPreferences();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPreferences &&
          runtimeType == other.runtimeType &&
          fontSize == other.fontSize &&
          lineHeight == other.lineHeight &&
          fontFamily == other.fontFamily &&
          theme == other.theme &&
          pageMargin == other.pageMargin &&
          textAlignment == other.textAlignment &&
          readingMode == other.readingMode;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    fontSize,
    lineHeight,
    fontFamily,
    theme,
    pageMargin,
    textAlignment,
    readingMode,
  );

  @override
  String toString() =>
      'ReadingPreferences('
      'fontSize: $fontSize, '
      'lineHeight: $lineHeight, '
      'fontFamily: $fontFamily, '
      'theme: $theme, '
      'pageMargin: $pageMargin, '
      'textAlignment: $textAlignment, '
      'readingMode: $readingMode'
      ')';
}
