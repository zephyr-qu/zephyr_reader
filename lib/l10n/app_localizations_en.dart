// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Zephyr Reader';

  @override
  String get tabHome => 'Home';

  @override
  String get tabBookshelf => 'Bookshelf';

  @override
  String get tabStatistics => 'Stats';

  @override
  String get tabProfile => 'Profile';

  @override
  String get continueReading => 'Continue Reading';

  @override
  String get recentReading => 'Recent';

  @override
  String get noReadingRecord => 'No reading records';

  @override
  String get bookshelf => 'Bookshelf';

  @override
  String get searchBooks => 'Search books';

  @override
  String get importBook => 'Import';

  @override
  String get all => 'All';

  @override
  String get reading => 'Reading';

  @override
  String get notStarted => 'Unread';

  @override
  String get finished => 'Finished';

  @override
  String get gridView => 'Grid';

  @override
  String get listView => 'List';

  @override
  String get noBooks => 'No books yet';

  @override
  String get bookDetail => 'Book Details';

  @override
  String get author => 'Author';

  @override
  String get translator => 'Translator';

  @override
  String get publisher => 'Publisher';

  @override
  String get format => 'Format';

  @override
  String get fileSize => 'File Size';

  @override
  String get totalPages => 'Pages';

  @override
  String get readingProgress => 'Reading Progress';

  @override
  String get readingTime => 'Reading Time';

  @override
  String get readingCount => 'Read Count';

  @override
  String get estimatedRemaining => 'Est. Remaining';

  @override
  String get startReading => 'Start Reading';

  @override
  String get readFromBeginning => 'Read from Beginning';

  @override
  String get notesCount => 'Notes';

  @override
  String get highlightsCount => 'Highlights';

  @override
  String get vocabularyCount => 'Words';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get exportNotes => 'Export Notes';

  @override
  String get refresh => 'Refresh';

  @override
  String get delete => 'Delete';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get reader => 'Reader';

  @override
  String get scrollMode => 'Scroll';

  @override
  String get pageTurnMode => 'Flip';

  @override
  String get paginationMode => 'Pages';

  @override
  String get bilingualMode => 'Bilingual';

  @override
  String get horizontal => 'Horizontal';

  @override
  String get vertical => 'Vertical';

  @override
  String get fontSize => 'Font Size';

  @override
  String get lineHeight => 'Line Height';

  @override
  String get letterSpacing => 'Letter Spacing';

  @override
  String get paragraphSpacing => 'Paragraph Spacing';

  @override
  String get pageMargin => 'Page Margin';

  @override
  String get readingBackground => 'Background';

  @override
  String get brightness => 'Brightness';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get font => 'Font';

  @override
  String get defaultFont => 'System Default';

  @override
  String chapterN(int n) {
    return 'Chapter $n';
  }

  @override
  String pageInfo(int current, int total) {
    return '$current/$total';
  }

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String get noBookmarks => 'No bookmarks';

  @override
  String get searchInPage => 'Search in Page';

  @override
  String get noResults => 'No results';

  @override
  String get ttsPlay => 'Play';

  @override
  String get ttsPause => 'Pause';

  @override
  String get ttsStop => 'Stop';

  @override
  String get ttsSpeed => 'Speed';

  @override
  String get selectionCopy => 'Copy';

  @override
  String get selectionHighlight => 'Highlight';

  @override
  String get selectionNote => 'Note';

  @override
  String get selectionDictionary => 'Define';

  @override
  String get selectionVocabulary => 'Vocabulary';

  @override
  String get selectionBilingual => 'Bilingual Pair';

  @override
  String get highlightYellow => 'Yellow';

  @override
  String get highlightGreen => 'Green';

  @override
  String get highlightBlue => 'Blue';

  @override
  String get highlightPink => 'Pink';

  @override
  String get highlightPurple => 'Purple';

  @override
  String get dictionary => 'Dictionary';

  @override
  String get lookupWord => 'Look Up';

  @override
  String get addToVocabulary => 'Add to Vocabulary';

  @override
  String get noDefinition => 'No definition found';

  @override
  String get vocabulary => 'Vocabulary';

  @override
  String get vocabularyBook => 'Vocabulary';

  @override
  String get wordCount => 'Words';

  @override
  String get learning => 'Learning';

  @override
  String get known => 'Known';

  @override
  String get newWord => 'New';

  @override
  String get searchWords => 'Search words';

  @override
  String get noWords => 'No words yet';

  @override
  String get statusUnlearned => 'Unlearned';

  @override
  String get statusLearning => 'Learning';

  @override
  String get statusMastered => 'Mastered';

  @override
  String get fromBook => 'From';

  @override
  String get statistics => 'Statistics';

  @override
  String get annualReport => 'Annual Report';

  @override
  String get readingOverview => 'Overview';

  @override
  String get weeklyOverview => 'This Week';

  @override
  String get readingDuration => 'Duration';

  @override
  String get readingWords => 'Words Read';

  @override
  String get readingDays => 'Days';

  @override
  String get consecutiveDays => 'Reading Streak';

  @override
  String get booksCompleted => 'Books Finished';

  @override
  String get readingSpeed => 'Reading Speed';

  @override
  String get wordsPerMinute => 'words/min';

  @override
  String get readingFootprint => 'Reading Footprint';

  @override
  String get daysActive => 'days active';

  @override
  String get readingTrend => 'This Week\'s Trend';

  @override
  String get readingRhythm => 'Reading Rhythm';

  @override
  String recentDays(int days) {
    return 'Last $days Days';
  }

  @override
  String get sessions => 'Sessions';

  @override
  String get settings => 'Settings';

  @override
  String get appSettings => 'App Settings';

  @override
  String get readingSettings => 'Reading Settings';

  @override
  String get themeSettings => 'Theme Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get readerBgColor => 'Background Color';

  @override
  String get fontSettings => 'Typography';

  @override
  String get pageSettings => 'Page Settings';

  @override
  String get screenSettings => 'Display';

  @override
  String get keepScreenOn => 'Keep Screen On';

  @override
  String get showBattery => 'Show Battery';

  @override
  String get showTime => 'Show Time';

  @override
  String get clickZone => 'Tap Zones';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow System';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get region => 'Region';

  @override
  String get syncSettings => 'Sync';

  @override
  String get autoSync => 'Auto Sync';

  @override
  String get manualSync => 'Manual';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get backup => 'Backup';

  @override
  String get restore => 'Restore';

  @override
  String get storageManagement => 'Storage';

  @override
  String get clearCache => 'Clear Cache';

  @override
  String get cacheSize => 'Cache Size';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get userAgreement => 'Terms of Service';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get sync => 'Sync';

  @override
  String get webdavConfig => 'WebDAV Config';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get remotePath => 'Remote Path';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncHistory => 'Sync History';

  @override
  String get syncSuccess => 'Sync Successful';

  @override
  String get syncFailed => 'Sync Failed';

  @override
  String get lastSync => 'Last Sync';

  @override
  String get conflictResolution => 'Conflict Resolution';

  @override
  String get useLocal => 'Use Local';

  @override
  String get useRemote => 'Use Remote';

  @override
  String get loading => 'Loading…';

  @override
  String get error => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get success => 'Success';

  @override
  String get failed => 'Failed';

  @override
  String get offline => 'Offline';

  @override
  String get empty => 'Nothing here yet';

  @override
  String get search => 'Search';

  @override
  String get unknownAuthor => 'Unknown Author';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingNoon => 'Good noon';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get greetingLateNight => 'Still reading?';

  @override
  String get startReadingJourney => 'Start your reading journey';

  @override
  String get exploreNewWorld => 'Open a book, explore a new world';

  @override
  String get goToBookshelf => 'Go to Bookshelf';

  @override
  String get splashTagline => 'Light as wind, read without boundaries';
}
