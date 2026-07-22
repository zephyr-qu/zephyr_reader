/// Errors that can occur when mapping between [ReadingPosition] and
/// engine-specific locators.
///
/// All mapping errors are explicit types — never string-based error
/// detection.
sealed class PositionMappingError {
  const PositionMappingError();
}

/// The locator's href could not be matched to any known chapter.
final class ChapterNotFound extends PositionMappingError {
  final String href;
  const ChapterNotFound(this.href);
}

/// The locator's text snippet could not be found in the chapter's plain text.
final class TextNotFound extends PositionMappingError {
  final String text;
  const TextNotFound(this.text);
}

/// The locator JSON is malformed or missing required fields.
final class InvalidLocator extends PositionMappingError {
  final String details;
  const InvalidLocator(this.details);
}

/// The publication fingerprint has changed; the hint cannot be trusted.
final class FingerprintMismatch extends PositionMappingError {
  final String expected;
  final String actual;
  const FingerprintMismatch(this.expected, this.actual);
}
