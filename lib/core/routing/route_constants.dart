/// 统一路由定义，包含 path 和自动派生的 name。
///
/// 后续替代 [RoutePaths] 和 [RouteNames] 成为单一来源。
enum AppRoute {
  splash('/'),
  home('/home'),
  bookshelf('/bookshelf'),
  bookDetail('/books/:id'),
  reader('/reader/:bookId/:chapterId'),
  about('/settings/about'),
  search('/search'),
  settings('/settings'),
  profile('/profile'),
  statistics('/statistics'),
  categoryManagement('/bookshelf/categories'),
  bookSearch('/search/book'),
  bookmarkManage('/reader/:bookId/bookmarks'),
  vocabulary('/vocabulary'),
  learningNotes('/learning-notes'),
  readingSessions('/statistics/sessions'),
  dataManagement('/settings/data-management'),
  ttsSettings('/settings/tts'),
  dictionarySettings('/settings/dictionary'),
  typographySettings('/settings/typography'),
  themeBrightness('/settings/theme'),
  otherSettings('/settings/other'),
  wifiTransfer('/wifi-transfer'),
  bilingualSettings('/settings/translation-api');

  /// 路径模式字符串（如 `/books/:id`）。
  final String path;
  const AppRoute(this.path);
}
