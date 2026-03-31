abstract class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String bookshelf = '/bookshelf';
  static const String bookDetail = '/books/:id';
  static const String reader = '/reader/:bookId/:chapterId';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String articles = '/articles';
  static const String articleDetail = '/articles/:id';
  static const String statistics = '/statistics';

  // 设置相关
  static const String readingSettings = '/settings/reading';
  static const String appSettings = '/settings/app';
  static const String themeSettings = '/settings/theme';
  static const String about = '/about';
}

abstract class RouteNames {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String home = 'home';
  static const String bookshelf = 'bookshelf';
  static const String bookDetail = 'bookDetail';
  static const String reader = 'reader';
  static const String search = 'search';
  static const String settings = 'settings';
  static const String profile = 'profile';
  static const String articles = 'articles';
  static const String articleDetail = 'articleDetail';
  static const String statistics = 'statistics';

  // 设置相关
  static const String readingSettings = 'readingSettings';
  static const String appSettings = 'appSettings';
  static const String themeSettings = 'themeSettings';
  static const String about = 'about';
}
