import 'reading_status.dart';
import '../position/reading_position.dart';

/// Atomic reading state snapshot consumed by the UI layer.
///
/// The page shell subscribes to a single [ReadingSnapshot] rather than
/// subscribing to multiple signals that could go out of sync. This
/// guarantees that every frame sees an internally consistent state.
class ReadingSnapshot {
  /// Current status of the backend session.
  final ReadingStatus status;

  /// Title of the currently open book.
  final String bookTitle;

  /// Title of the current chapter.
  final String chapterTitle;

  /// Overall reading progress as a fraction in [0.0, 1.0].
  final double totalProgress;

  /// Logical position within the book, if available.
  final ReadingPosition? position;

  /// Error message when status is [ReadingStatus.failed].
  final String? errorMessage;

  const ReadingSnapshot({
    required this.status,
    required this.bookTitle,
    required this.chapterTitle,
    required this.totalProgress,
    this.position,
    this.errorMessage,
  });

  /// Create a snapshot for a closed state.
  static const closed = ReadingSnapshot(
    status: ReadingStatus.closed,
    bookTitle: '',
    chapterTitle: '',
    totalProgress: 0.0,
  );

  /// Create a snapshot for a failed state with an error message.
  factory ReadingSnapshot.failed(String message) => ReadingSnapshot(
    status: ReadingStatus.failed,
    bookTitle: '',
    chapterTitle: '',
    totalProgress: 0.0,
    errorMessage: message,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingSnapshot &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          bookTitle == other.bookTitle &&
          chapterTitle == other.chapterTitle &&
          totalProgress == other.totalProgress &&
          position == other.position &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    status,
    bookTitle,
    chapterTitle,
    totalProgress,
    position,
    errorMessage,
  );

  @override
  String toString() =>
      'ReadingSnapshot('
      'status: $status, '
      'bookTitle: $bookTitle, '
      'chapterTitle: $chapterTitle, '
      'totalProgress: ${(totalProgress * 100).toStringAsFixed(1)}%, '
      'position: $position, '
      'errorMessage: $errorMessage'
      ')';
}
