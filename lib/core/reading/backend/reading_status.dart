/// Status of a reading backend session.
enum ReadingStatus {
  /// Initial state before [ReadingBackend.open] is called.
  closed,

  /// [ReadingBackend.open] has been called, waiting for initialization.
  opening,

  /// Locator/chapter position is being restored.
  restoring,

  /// Backend is fully initialized and ready for user interaction.
  ready,

  /// An error occurred during opening or while reading.
  failed,
}
