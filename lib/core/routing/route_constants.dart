/// Unified route definitions, each value carries its path pattern.
///
/// Replaces [RoutePaths] and [RouteNames] as the single source of truth.
enum AppRoute {
  splash('/'),
  home('/home'),
  bookshelf('/bookshelf'),
  bookDetail('/books/:id'),
  reader('/reader/:bookId/:chapterId'),
  about('/settings/about'),
  settings('/settings'),
  profile('/profile'),
  statistics('/statistics'),
  categoryManagement('/bookshelf/categories'),
  readingSessions('/statistics/sessions'),
  dataManagement('/settings/data-management'),
  ttsSettings('/settings/tts'),
  typographySettings('/settings/typography'),
  themeBrightness('/settings/theme'),
  otherSettings('/settings/other');
  /// Path pattern string (e.g. `/books/:id`).
  final String path;

  const AppRoute(this.path);
}
