import 'reading_backend_kind.dart';

/// Describes the capabilities supported by a reading backend.
///
/// Engines must explicitly mark unsupported capabilities. The UI layer
/// uses this to decide what to show, disable with explanation, or
/// implement at the application level instead.
///
/// An absent capability must never be silently ignored or have a no-op
/// implementation — it must be visible to the user.
class ReadingCapabilities {
  final bool pagination;
  final bool continuousScroll;
  final bool precisePosition;
  final bool textSelection;
  final bool annotations;
  final bool nativeTts;
  final bool customFont;
  final bool letterSpacing;
  final bool paragraphSpacing;
  final bool firstLineIndent;

  const ReadingCapabilities({
    required this.pagination,
    required this.continuousScroll,
    required this.precisePosition,
    required this.textSelection,
    required this.annotations,
    required this.nativeTts,
    required this.customFont,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.firstLineIndent,
  });

  /// Builtin engine capabilities — all supported.
  static const builtin = ReadingCapabilities(
    pagination: true,
    continuousScroll: true,
    precisePosition: true,
    textSelection: true,
    annotations: true,
    nativeTts: false,
    customFont: true,
    letterSpacing: true,
    paragraphSpacing: true,
    firstLineIndent: true,
  );

  /// Readium engine default capabilities.
  static const readium = ReadingCapabilities(
    pagination: true,
    continuousScroll: true,
    precisePosition: true,
    textSelection: true,
    annotations: true,
    nativeTts: false,
    customFont: true,
    letterSpacing: true,
    paragraphSpacing: true,
    firstLineIndent: false,
  );

  /// Returns the default capability set for the given backend kind.
  factory ReadingCapabilities.forBackend(ReadingBackendKind kind) {
    switch (kind) {
      case ReadingBackendKind.builtin:
        return builtin;
      case ReadingBackendKind.readium:
        return readium;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingCapabilities &&
          runtimeType == other.runtimeType &&
          pagination == other.pagination &&
          continuousScroll == other.continuousScroll &&
          precisePosition == other.precisePosition &&
          textSelection == other.textSelection &&
          annotations == other.annotations &&
          nativeTts == other.nativeTts &&
          customFont == other.customFont &&
          letterSpacing == other.letterSpacing &&
          paragraphSpacing == other.paragraphSpacing &&
          firstLineIndent == other.firstLineIndent;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    pagination,
    continuousScroll,
    precisePosition,
    textSelection,
    annotations,
    nativeTts,
    customFont,
    letterSpacing,
    paragraphSpacing,
    firstLineIndent,
  );

  @override
  String toString() =>
      'ReadingCapabilities('
      'pagination: $pagination, '
      'continuousScroll: $continuousScroll, '
      'precisePosition: $precisePosition, '
      'textSelection: $textSelection, '
      'annotations: $annotations, '
      'nativeTts: $nativeTts, '
      'customFont: $customFont, '
      'letterSpacing: $letterSpacing, '
      'paragraphSpacing: $paragraphSpacing, '
      'firstLineIndent: $firstLineIndent'
      ')';
}
