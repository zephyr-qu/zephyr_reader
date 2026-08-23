// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabHome => 'Home';

  @override
  String get tabBookshelf => 'Bookshelf';

  @override
  String get tabStatistics => 'Stats';

  @override
  String get tabProfile => 'Profile';

  @override
  String get back => 'Back';

  @override
  String get continueReading => 'Continue Reading';

  @override
  String get recentReading => 'Recent';

  @override
  String get noReadingRecord => 'No reading records';

  @override
  String get bookshelf => 'Bookshelf';

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
  String get listView => 'List';

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
  String get readingProgress => 'Reading Progress';

  @override
  String get readingTime => 'Reading Time';

  @override
  String estimatedTime(Object hours, Object minutes) {
    return 'About ${hours}h ${minutes}min';
  }

  @override
  String estimatedTimeShort(Object minutes) {
    return 'About ${minutes}min';
  }

  @override
  String get startReading => 'Start Reading';

  @override
  String get readFromBeginning => 'Read from Beginning';

  @override
  String get edit => 'Edit';

  @override
  String get exportNotes => 'Export Notes';

  @override
  String get refresh => 'Refresh';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get reader => 'Reader';

  @override
  String get scrollMode => 'Scroll';

  @override
  String get paginationMode => 'Pages';

  @override
  String get fontSize => 'Font Size';

  @override
  String get fontFamily => 'Font Family';

  @override
  String get fontWeight => 'Font Weight';

  @override
  String get lineHeight => 'Line Height';

  @override
  String get letterSpacing => 'Letter Spacing';

  @override
  String get paragraphSpacing => 'Paragraph Spacing';

  @override
  String get paragraphIndent => 'Paragraph Indent';

  @override
  String get textAlignment => 'Text Alignment';

  @override
  String get textAlignAuto => 'Default';

  @override
  String get textAlignLeft => 'Left';

  @override
  String get textAlignJustify => 'Justify';

  @override
  String get pageMargin => 'Page Margin';

  @override
  String get brightness => 'Brightness';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get font => 'Font';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get addBookmark => 'Add Bookmark';

  @override
  String get ttsSpeed => 'Speed';

  @override
  String get dictionary => 'Dictionary Management';

  @override
  String get wordCount => 'Words';

  @override
  String get statistics => 'Statistics';

  @override
  String get readingWords => 'Words Read';

  @override
  String get booksCompleted => 'Books Finished';

  @override
  String get readingTrend => 'This Week\'s Trend';

  @override
  String get sessions => 'Sessions';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'Follow System';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get backup => 'Backup';

  @override
  String get clearCache => 'Clear Cache';

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
  String get selectPreset => 'Select Preset';

  @override
  String get clearConfig => 'Clear Config';

  @override
  String get serverUrlRequired => 'Please enter server URL';

  @override
  String get serverUrlInvalid =>
      'Please enter a full URL (including http:// or https://)';

  @override
  String get usernameRequired => 'Please enter username';

  @override
  String get passwordRequired => 'Please enter password';

  @override
  String get remotePathRequired => 'Please enter remote path';

  @override
  String get remotePathInvalid => 'Remote path should start with /';

  @override
  String get configSaved => 'WebDAV config saved';

  @override
  String get saveConfigFailed => 'Failed to save config';

  @override
  String get configCleared => 'Config cleared';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get syncSuccess => 'Sync Successful';

  @override
  String get syncFailed => 'Sync Failed';

  @override
  String get syncConfigInvalid =>
      'Invalid sync config, please check WebDAV settings';

  @override
  String get dataCleared => 'Cache cleared';

  @override
  String dataClearFailed(Object error) {
    return 'Failed to clear cache: $error';
  }

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
  String get unknownError => 'Unknown error';

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

  @override
  String get bookshelfSearchHint => 'Search books...';

  @override
  String get bookshelfSettings => 'Bookshelf Settings';

  @override
  String get bookshelfEmpty => 'Your bookshelf is empty';

  @override
  String get closeSearch => 'Close search';

  @override
  String get scanFolder => 'Scan Folder';

  @override
  String get batchManage => 'Batch Manage';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get markAsUnread => 'Mark as Unread';

  @override
  String get markAsReading => 'Mark as Reading';

  @override
  String get reExtractCover => 'Re-extract Cover';

  @override
  String get unpin => 'Unpin';

  @override
  String get pinTop => 'Pin to Top';

  @override
  String get selectCategory => 'Select Category';

  @override
  String bookImported(Object title) {
    return 'Imported: $title';
  }

  @override
  String importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get scanningFolder => 'Scanning folder...';

  @override
  String get noBookFilesFound => 'No book files found';

  @override
  String scanComplete(Object count) {
    return 'Scan complete, imported $count books';
  }

  @override
  String scanProgress(Object done, Object total) {
    return 'Scanning $done/$total...';
  }

  @override
  String scanCompleteWithFailures(Object fail, Object success) {
    return 'Scan complete, imported $success, failed $fail';
  }

  @override
  String get showReadingProgress => 'Show Reading Progress';

  @override
  String get defaultSort => 'Default Sort';

  @override
  String get moveCategory => 'Move to Category';

  @override
  String get changeStatus => 'Change Status';

  @override
  String get apply => 'Apply';

  @override
  String selectedBooksCount(Object count) {
    return '$count selected';
  }

  @override
  String get totalChars => 'Total Characters';

  @override
  String get addedTime => 'Added';

  @override
  String get chapterList => 'Chapters';

  @override
  String get collapse => 'Collapse';

  @override
  String get category => 'Category';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get deleteBook => 'Delete Book';

  @override
  String get confirmDeleteBookMessage =>
      'Are you sure you want to delete this book? This action cannot be undone.';

  @override
  String deleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String get loadFailed => 'Failed to load';

  @override
  String get appearanceSection => 'Reading Appearance';

  @override
  String get readingModeSection => 'Reading Mode';

  @override
  String get typographySection => 'Typography';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get profileDisplayName => 'Reader';

  @override
  String get profileTagline => 'Reading is a way of life';

  @override
  String get sectionSystem => 'System';

  @override
  String get sectionReadingData => 'Reading Data';

  @override
  String get sectionReadingTools => 'Reading Tools';

  @override
  String get sectionDisplayAppearance => 'Display & Appearance';

  @override
  String get readingSessions => 'Reading History';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get ttsSettings => 'TTS Settings';

  @override
  String get typographySettings => 'Typography';

  @override
  String get themeBrightness => 'Theme & Brightness';

  @override
  String get otherSettings => 'Other Settings';

  @override
  String appVersionDisplay(Object version) {
    return 'Zephyr Reader v$version';
  }

  @override
  String get checkUpdate => 'Check Update';

  @override
  String get openSourceLicense => 'Open Source License';

  @override
  String get feedback => 'Feedback';

  @override
  String get selectDictionaryFile => 'Select Dictionary File';

  @override
  String get selectMdxDescription => 'Please select a .mdx dictionary file…';

  @override
  String get dictionaryLoadFailed =>
      'Dictionary load failed, please check the file';

  @override
  String get categoryManagement => 'Category Management';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline => 'A reading experience as light as a breeze';

  @override
  String get aboutSectionFeatures => 'Features';

  @override
  String get aboutSectionTechStack => 'Tech Stack';

  @override
  String get aboutSectionLinks => 'Resources';

  @override
  String get aboutDescription =>
      'Zephyr Reader is an offline novel reader built with Flutter + Rust, supporting EPUB and TXT formats with smart typesetting.';

  @override
  String get aboutFeatureOffline => '100% Offline';

  @override
  String get aboutFeatureOfflineDesc =>
      'Core features work offline with no backend or ads';

  @override
  String get aboutFeaturePerformance => 'High Performance';

  @override
  String get aboutFeaturePerformanceDesc =>
      'Rust-powered engine parses large files instantly';

  @override
  String get aboutFeatureThemes => 'Multiple Themes';

  @override
  String get aboutFeatureThemesDesc => 'Light, Dark & Pure Black night mode';

  @override
  String get aboutFeatureAdaptive => 'Adaptive Layout';

  @override
  String get aboutFeatureAdaptiveDesc =>
      'Adaptive layout for phones and tablets';

  @override
  String get aboutFeatureSync => 'WebDAV Sync';

  @override
  String get aboutFeatureSyncDesc => 'Cross-device sync & secure backup';

  @override
  String get aboutCheckUpdate => 'Check for Updates';

  @override
  String get aboutLatestVersion => 'Already up to date';

  @override
  String get aboutUserAgreement => 'User Agreement';

  @override
  String get aboutPrivacyPolicy => 'Privacy Policy';

  @override
  String get aboutOpenSourceLicense => 'Open Source Licenses';

  @override
  String get aboutFeedback => 'Feedback';

  @override
  String get aboutCannotOpenLink => 'Cannot open link';

  @override
  String get unknownVersion => 'Unknown';

  @override
  String get readAloud => 'Read Aloud';

  @override
  String get readingAssist => 'Reading Assist';

  @override
  String get readerThemeLight => 'Day';

  @override
  String get readerThemeDark => 'Night';

  @override
  String get readerThemeSepia => 'Sepia';

  @override
  String get sortLastRead => 'Last Read';

  @override
  String get sortCreatedAt => 'Date Added';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortAuthor => 'Author';

  @override
  String get sortProgress => 'Progress';

  @override
  String get themeSystem => 'System';

  @override
  String get introLabel => 'Description';

  @override
  String get bookTitle => 'Title';

  @override
  String get currentChapter => 'Current';

  @override
  String get editMetadata => 'Edit Metadata';

  @override
  String get statReadingTime => 'Reading Time';

  @override
  String get statReadingCount => 'Read Count';

  @override
  String get statEstimatedRemaining => 'Estimated Remaining';

  @override
  String get expand => 'Expand';

  @override
  String tocTitle(Object count) {
    return 'Table of Contents ($count ch)';
  }

  @override
  String get isbn => 'ISBN';

  @override
  String get appTheme => 'App Theme';

  @override
  String get autoTheme => 'Auto Theme';

  @override
  String get bookFormat => 'Format';

  @override
  String get sortDialogTitle => 'Select Sort Order';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(Object hours) {
    return '$hours hr ago';
  }

  @override
  String lastSyncTime(Object time) {
    return 'Last sync: $time';
  }

  @override
  String get todayReading => 'Today';

  @override
  String get minutes => 'min';

  @override
  String goalTemplate(Object minutes) {
    return '$minutes min goal';
  }

  @override
  String get streakLabel => 'Reading Streak';

  @override
  String get daysUnit => 'days';

  @override
  String booksRead(Object count) {
    return '$count books read';
  }

  @override
  String get insufficientData => 'Insufficient data';

  @override
  String get readingHeatmap => 'Reading Heatmap';

  @override
  String get noSessions => 'No reading sessions';

  @override
  String get autoRecordHint => 'Automatically recorded while reading';

  @override
  String get sessionDetails => 'Session Details';

  @override
  String get unknownBook => 'Unknown book';

  @override
  String sessionSummary(Object chars, Object count, Object duration) {
    return '$count sessions · $duration · $chars read';
  }

  @override
  String chapterInfo(Object chars, Object index) {
    return 'Ch. $index · $chars';
  }

  @override
  String get deleteSessionTitle => 'Delete Sessions';

  @override
  String get deleteSessionConfirm => 'Delete all sessions for this book?';

  @override
  String get periodToday => 'Today';

  @override
  String get periodWeek => 'Week';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodYear => 'Year';

  @override
  String get totalReadingTime => 'Total reading time';

  @override
  String get sessionsCount => 'sessions';

  @override
  String batchDeleteConfirm(Object count) {
    return 'Delete $count selected books?';
  }

  @override
  String get categoryName => 'Category Name';

  @override
  String get addCategory => 'Add Category';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String confirmDeleteCategory(Object name) {
    return 'Delete category \"$name\"? Books won\'t be affected.';
  }

  @override
  String get categoryNameRequired => 'Please enter a category name';

  @override
  String get noCategories => 'No categories yet';

  @override
  String get addCategoryHint => 'Tap + to add a category';

  @override
  String get backupSuccess => 'Backup successful';

  @override
  String backupFailed(Object error) {
    return 'Backup failed: $error';
  }

  @override
  String get restoreSuccess => 'Restore successful';

  @override
  String restoreFailed(Object error) {
    return 'Restore failed: $error';
  }

  @override
  String get clear => 'Clear';

  @override
  String get restoreRestartNotice => 'Data restored. Please restart the app.';

  @override
  String get restoreTitle => 'Restore from backup';

  @override
  String get restoreSubtitle => 'Select a .db backup file to restore';

  @override
  String get restoring => 'Restoring…';

  @override
  String get neverBackedUp => 'Never backed up';

  @override
  String timeDaysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String timeMonthsAgo(Object months) {
    return '$months months ago';
  }

  @override
  String get restoreConfirmTitle => 'Restore backup?';

  @override
  String get restoreConfirmWarning =>
      'This will overwrite all current data. Verify the backup is from a trusted source.';

  @override
  String get restoreConfirmAction => 'Restore';

  @override
  String get restoreStatVersion => 'Version';

  @override
  String get restoreStatExportedAt => 'Exported';

  @override
  String get restoreStatBooks => 'Books';

  @override
  String get restoreStatNotes => 'Notes';

  @override
  String get restoreStatBookmarks => 'Bookmarks';

  @override
  String get secondsUnit => 'sec';

  @override
  String get hoursUnit => 'hr';

  @override
  String get charsUnit => 'chars';

  @override
  String get thousandCharsUnit => 'K';

  @override
  String get byteUnit => 'B';

  @override
  String get kilobyteUnit => 'KB';

  @override
  String get megabyteUnit => 'MB';

  @override
  String get gigabyteUnit => 'GB';

  @override
  String get livePreview => 'Live Preview';

  @override
  String get autoScroll => 'Auto Scroll';

  @override
  String get autoScrollSpeed => 'Scroll Interval';

  @override
  String get ttsPlaybackParams => 'Playback';

  @override
  String get ttsPitch => 'Pitch';

  @override
  String get ttsPauseBetween => 'Pause Between Sentences';

  @override
  String get ttsOriginalOnly => 'Original Only';

  @override
  String get ttsSwitchInterval => 'Switch Interval';

  @override
  String get ttsBehavior => 'Behavior';

  @override
  String get ttsBackgroundPlay => 'Background Play';

  @override
  String get ttsBackgroundPlayDesc =>
      'Continue reading when app is backgrounded';

  @override
  String get ttsAutoPage => 'Auto Page Turn';

  @override
  String get ttsAutoPageDesc => 'Auto-advance to next chapter';

  @override
  String get ttsHighlightFollow => 'Highlight Follow';

  @override
  String get ttsHighlightFollowDesc => 'Highlight current sentence during TTS';

  @override
  String get ttsDimOnLock => 'Dim on Lock';

  @override
  String get ttsDimOnLockDesc => 'Save battery, ideal for bedtime listening';

  @override
  String get otherBehavior => 'Behavior';

  @override
  String get languageSubtitle => '简体中文 / English';

  @override
  String get otherNotifications => 'Notifications';

  @override
  String get otherNotificationsDesc =>
      'Reading goal reminders, sync notifications';

  @override
  String get otherStartupCheck => 'Check Updates on Start';

  @override
  String get otherStartupCheckDesc =>
      'Check for new versions on foreground start';

  @override
  String get otherExperimental => 'Experimental';

  @override
  String get otherLegal => 'Legal & Compliance';

  @override
  String get openSourceLicenseDesc => 'Flutter / Rust / Third-party licenses';

  @override
  String get resetAllSettings => 'Reset All Settings';

  @override
  String get resetAllSettingsDesc =>
      'Reset typography, themes, sync to defaults';

  @override
  String get clearAllData => 'Clear Cache';

  @override
  String get clearAllDataDesc =>
      'Clear reading cache and temp files, no data loss';

  @override
  String get confirmReset => 'Confirm Reset';

  @override
  String get confirmResetContent =>
      'This will reset typography, theme, sync settings to defaults.\n\nBooks, notes and vocabulary won\'t be deleted.';

  @override
  String get clearAllDataTitle => 'Clear Cache';

  @override
  String get clearAllDataContent =>
      'This will clear reading cache and temporary files.\n\nBooks, notes and vocabulary won\'t be deleted.';

  @override
  String get confirmClear => 'Confirm Clear';

  @override
  String get readingMode => 'Reading Mode';

  @override
  String get deleteBookmark => 'Delete Bookmark';

  @override
  String get add => 'Add';

  @override
  String get charOffset => 'Offset';

  @override
  String get themePreviewSampleText =>
      'The spring wind has greened the southern shore again.';

  @override
  String get aboutFeatureLookup => 'Dictionary & Translation';

  @override
  String get aboutFeatureLookupDesc =>
      'Offline dictionary with configurable translation API';
}
