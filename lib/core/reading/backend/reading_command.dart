import '../position/reading_position.dart';

///
/// All navigation is expressed as sealed commands. The backend translates
/// these into engine-specific actions (e.g. page turn, chapter jump).
sealed class ReadingCommand {
  const ReadingCommand();
}

/// Navigate to the previous page/view.
final class PreviousPage extends ReadingCommand {
  const PreviousPage();
}

/// Navigate to the next page/view.
final class NextPage extends ReadingCommand {
  const NextPage();
}

/// Navigate to the previous chapter.
final class PreviousChapter extends ReadingCommand {
  const PreviousChapter();
}

/// Navigate to the next chapter.
final class NextChapter extends ReadingCommand {
  const NextChapter();
}

/// Navigate to a specific chapter.
final class GoToChapter extends ReadingCommand {
  final String chapterId;
  const GoToChapter(this.chapterId);
}

/// Navigate to a specific logical position.
final class GoToPosition extends ReadingCommand {
  final ReadingPosition position;
  const GoToPosition(this.position);
}
