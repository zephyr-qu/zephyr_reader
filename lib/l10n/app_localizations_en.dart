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
  String get followSystemFontScale => 'Follow System';

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
  String chapterN(Object n) {
    return 'Chapter $n';
  }

  @override
  String pageInfo(Object current, Object total) {
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
  String recentDays(Object days) {
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
  String get syncNow => 'Sync Now';

  @override
  String get syncHistory => 'Sync History';

  @override
  String get syncSuccess => 'Sync Successful';

  @override
  String get syncFailed => 'Sync Failed';

  @override
  String get syncConfigInvalid =>
      'Invalid sync config, please check WebDAV settings';

  @override
  String get dataCleared => 'All local data cleared';

  @override
  String dataClearFailed(Object error) {
    return 'Failed to clear data: $error';
  }

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
  String get confirmAgain => 'Confirm Again';

  @override
  String get continueAction => 'Continue';

  @override
  String get success => 'Success';

  @override
  String get failed => 'Failed';

  @override
  String get offline => 'Offline';

  @override
  String get empty => 'Nothing here yet';

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
  String get globalSearch => 'Global Search';

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
  String get selectSortMethod => 'Select Sort Method';

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
  String get bookInfo => 'Book Info';

  @override
  String get chapterCountLabel => 'Chapters';

  @override
  String get totalChars => 'Total Characters';

  @override
  String get addedTime => 'Added';

  @override
  String get chapterList => 'Chapters';

  @override
  String get collapse => 'Collapse';

  @override
  String viewAllChapters(Object count) {
    return 'View all $count chapters';
  }

  @override
  String get category => 'Category';

  @override
  String get weeklyReadingTime => 'Weekly Reading';

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
  String get appearanceSection => 'Appearance';

  @override
  String get readingModeSection => 'Reading Mode';

  @override
  String get layoutSection => 'Layout';

  @override
  String get typographySection => 'Typography';

  @override
  String get searchInChapterHint => 'Search in chapter...';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get currentlyReading => 'Currently Reading';

  @override
  String get setBilingualTranslation => 'Set Bilingual Translation';

  @override
  String get pasteTranslationHint =>
      'Paste or enter the translation of this chapter:';

  @override
  String get pasteTranslationPlaceholder => 'Paste your translation text here…';

  @override
  String get addNote => 'Add Note';

  @override
  String get noteHintText => 'Enter your note…';

  @override
  String get editNote => 'Edit Note';

  @override
  String get deleteHighlight => 'Delete Highlight';

  @override
  String get profileDisplayName => 'Reader';

  @override
  String get profileTagline => 'Reading is a way of life';

  @override
  String get consecutiveDaysLabel => 'Streak';

  @override
  String get sectionStudyMgmt => 'Study & Manage';

  @override
  String get sectionReadingExp => 'Reading Experience';

  @override
  String get sectionSystem => 'System';

  @override
  String get learningNotes => 'Learning Notes';

  @override
  String get readingSessions => 'Reading Sessions';

  @override
  String get storageSync => 'Storage & Sync';

  @override
  String get ttsSettings => 'TTS Settings';

  @override
  String get typographySettings => 'Typography';

  @override
  String get themeBrightness => 'Theme & Brightness';

  @override
  String get otherSettings => 'Other Settings';

  @override
  String get synced => 'Synced';

  @override
  String appVersionDisplay(Object version) {
    return 'Zephyr Reader v$version';
  }

  @override
  String get appIntroduction => 'Introduction';

  @override
  String get coreFeatures => 'Core Features';

  @override
  String get techStack => 'Tech Stack';

  @override
  String get moreInfo => 'More Info';

  @override
  String get checkUpdate => 'Check Update';

  @override
  String get openSourceLicense => 'Open Source License';

  @override
  String get feedback => 'Feedback';

  @override
  String get alreadyLatestVersion => 'Already up to date';

  @override
  String get cannotOpenLink => 'Cannot open link';

  @override
  String get aboutFeature1 => 'Offline-first, no network required';

  @override
  String get aboutFeature2 => 'Supports EPUB, TXT, PDF';

  @override
  String get aboutFeature3 => 'Smart typesetting engine';

  @override
  String get aboutFeature4 => 'Bilingual reading';

  @override
  String get aboutFeature5 => 'Vocabulary book & learning records';

  @override
  String get aboutFeature6 => 'WebDAV multi-device sync';

  @override
  String get copyrightFooter => '© 2026 Zephyr Reader';

  @override
  String get madeWithFooter => 'Made with Flutter · Rust · ❤';

  @override
  String get errorFileNotFound => 'File not found';

  @override
  String get errorFileReadError => 'Failed to read file';

  @override
  String get errorUnsupportedFormat => 'Unsupported format';

  @override
  String get errorEpubParse => 'EPUB parse error';

  @override
  String get errorDatabase => 'Database error';

  @override
  String get errorInternal => 'Internal error';

  @override
  String errorTaskPanic(Object task) {
    return 'Task failed: $task';
  }

  @override
  String get selectDictionaryFile => 'Select Dictionary File';

  @override
  String get selectMdxDescription => 'Please select a .mdx dictionary file…';

  @override
  String get invalidMdxFile => 'Please select a valid .mdx file';

  @override
  String get dictionaryLoadFailed =>
      'Dictionary load failed, please check the file';

  @override
  String get pronunciation => 'Pronunciation';

  @override
  String get noExactMatch => 'No exact match found. Did you mean:';

  @override
  String get wordSegmentation => 'Segmentation:';

  @override
  String get bilingualNoAlignment =>
      'No alignment found for bilingual highlight';

  @override
  String get bilingualNoParagraph => 'No matching paragraph found';

  @override
  String get bilingualHighlightCreated => 'Bilingual highlight created';

  @override
  String get selectFile => 'Select File';

  @override
  String get dictionaryConfigHint =>
      'Select a .mdx dictionary file. If a matching .mdd resource file (audio/images) exists in the same directory, it will be loaded automatically.';

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
      'Zephyr Reader is an offline bilingual novel reader built with Flutter + Rust.';

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
  String get aboutFeatureBilingual => 'Bilingual Layout';

  @override
  String get aboutFeatureBilingualDesc =>
      'Equal priority for Chinese & English';

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
  String get prev => 'Previous';

  @override
  String get readAloud => 'Read Aloud';

  @override
  String addedToVocabulary(Object word) {
    return 'Added to vocabulary: $word';
  }

  @override
  String addToVocabFailed(Object error) {
    return 'Failed to add to vocabulary: $error';
  }

  @override
  String get readerThemeLight => 'Day';

  @override
  String get readerThemeDark => 'Night';

  @override
  String get readerThemeSepia => 'Sepia';

  @override
  String get readerFontSizeSmall => 'Small';

  @override
  String get readerFontSizeMedium => 'Medium';

  @override
  String get readerFontSizeLarge => 'Large';

  @override
  String get readerFontSizeXLarge => 'Extra Large';

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
  String totalChapters(Object count) {
    return '$count chapters';
  }

  @override
  String get isbn => 'ISBN';

  @override
  String get bookIntro => 'About This Book';

  @override
  String get timePresetSunsetToSunrise => 'Sunset to Sunrise';

  @override
  String get timePresetEveningToMorning => 'Evening to Morning';

  @override
  String get timePresetCustom => 'Custom';

  @override
  String get appTheme => 'App Theme';

  @override
  String get bookFormat => 'Format';

  @override
  String get bookIntroLabel => 'About This Book';

  @override
  String get sortDialogTitle => 'Select Sort Order';

  @override
  String get tapLayoutRightHanded => 'Right-Handed';

  @override
  String get tapLayoutLeftHanded => 'Left-Handed';

  @override
  String get tapLayout => 'Tap Zones';

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
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get vocabStats => 'Vocabulary';

  @override
  String get statusIgnored => 'Ignored';

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
  String get wifiPageTitle => 'WiFi Transfer';

  @override
  String get wifiServerRunning => 'Server running';

  @override
  String get wifiServerStopped => 'Server stopped';

  @override
  String get wifiStartServer => 'Start Server';

  @override
  String get wifiStopServer => 'Stop Server';

  @override
  String get wifiCopyLink => 'Copy Link';

  @override
  String get wifiLinkCopied => 'Link copied';

  @override
  String get wifiInstruction =>
      'Connect to the same Wi-Fi network and open the URL above in your browser to transfer files.';

  @override
  String wifiFileUploaded(Object filename) {
    return 'Uploaded: $filename';
  }

  @override
  String get wifiServerStarted => 'Server started';

  @override
  String batchDeleteConfirm(Object count) {
    return 'Delete $count selected books?';
  }

  @override
  String get categoryName => 'Category Name';

  @override
  String get addCategory => 'Add Category';

  @override
  String get editCategoryName => 'Edit Category Name';

  @override
  String get deleteCategory => 'Delete Category';

  @override
  String confirmDeleteCategory(Object name) {
    return 'Delete category \"$name\"? Books won\'t be affected.';
  }

  @override
  String get categoryNameRequired => 'Please enter a category name';

  @override
  String get categoryAlreadyExists => 'Category name already exists';

  @override
  String get noCategories => 'No categories yet';

  @override
  String get addCategoryHint => 'Tap + to add a category';

  @override
  String get wifiTransferLog => 'Transfer Log';

  @override
  String get wifiWaitUpload => 'Waiting for file upload…';

  @override
  String get wifiStartServerPrompt => 'Start the server to begin transferring';

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
  String get searchGroupBooks => 'Books';

  @override
  String get searchGroupNotes => 'Notes';

  @override
  String get searchGroupVocab => 'Vocabulary';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get bookSearchHint => 'Search book content…';

  @override
  String get bookSearchHintAll => 'Search all books…';

  @override
  String get searchHint => 'Search books, notes, vocabulary…';

  @override
  String get searchHistory => 'Search history';

  @override
  String get searchFailed => 'Search failed';

  @override
  String get searchEnterKeyword => 'Enter a keyword to search';

  @override
  String get searchTryOtherKeywords => 'Try other keywords';

  @override
  String get searchError => 'Search error';

  @override
  String resultSummary(Object count, Object duration) {
    return '$count results · ${duration}ms';
  }

  @override
  String get clear => 'Clear';

  @override
  String get restoreRestartNotice => 'Data restored. Please restart the app.';

  @override
  String get backupSubtitleNever => 'Never backed up';

  @override
  String backupSubtitleDays(Object days) {
    return 'Backed up $days days ago — backup now';
  }

  @override
  String backupSubtitleHours(Object hours) {
    return 'Backed up $hours hours ago';
  }

  @override
  String backupSubtitleMinutes(Object minutes) {
    return 'Backed up $minutes minutes ago';
  }

  @override
  String get backupSubtitleJustNow => 'Just backed up';

  @override
  String get restoreTitle => 'Restore from backup';

  @override
  String get restoreSubtitle => 'Select a .db backup file to restore';

  @override
  String get currentDataStats => 'Data at a glance';

  @override
  String get backingUp => 'Backing up…';

  @override
  String get restoring => 'Restoring…';

  @override
  String operationFailed(Object error) {
    return 'Failed: $error';
  }

  @override
  String lastBackup(Object time) {
    return 'Last backup: $time';
  }

  @override
  String get neverBackedUp => 'Never backed up';

  @override
  String dataSummary(Object books, Object notes) {
    return 'Data: $books books · $notes notes';
  }

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
  String get restoreStatVocabulary => 'Vocabulary';

  @override
  String get allBooks => 'All Books';

  @override
  String get allWordLists => 'All Word Lists';

  @override
  String get export => 'Export';

  @override
  String get exportLearningData => 'Export Learning Data';

  @override
  String get exportNotesMarkdownDesc =>
      'Export all notes as Markdown documents';

  @override
  String get exportVocabCsvDesc => 'Export all vocabulary as a CSV file';

  @override
  String get goReading => 'Go Reading';

  @override
  String get noNotes => 'No notes yet';

  @override
  String get noteEmptyHint =>
      'Take notes while reading, and they will appear here.';

  @override
  String get notebook => 'Notebook';

  @override
  String get notesMarkdown => 'Notes (Markdown)';

  @override
  String get totalVocabCount => 'Vocabulary Total';

  @override
  String get vocabEmptyHint =>
      'Add vocabulary while reading, and they will appear here.';

  @override
  String get vocabListCsv => 'Vocabulary (CSV)';

  @override
  String get wordListCet4 => 'CET-4';

  @override
  String get wordListCet6 => 'CET-6';

  @override
  String get wordListIelts => 'IELTS';

  @override
  String get wordListToefl => 'TOEFL';

  @override
  String confirmDeleteWord(Object word) {
    return 'Are you sure you want to delete \"$word\"?';
  }

  @override
  String get vocabPageEmptyHint =>
      'Tap words while reading to add them to your vocabulary book.';

  @override
  String get vocabFilterEmptyHint => 'No words match your filter.';

  @override
  String vocabStatsAll(Object count) {
    return 'All $count';
  }

  @override
  String vocabStatsUnstarted(Object count) {
    return 'Unlearned $count';
  }

  @override
  String vocabStatsLearning(Object count) {
    return 'Learning $count';
  }

  @override
  String vocabStatsMastered(Object count) {
    return 'Mastered $count';
  }

  @override
  String vocabStatsIgnored(Object count) {
    return 'Ignored $count';
  }

  @override
  String get secondsUnit => 'sec';

  @override
  String get hoursUnit => 'hr';

  @override
  String get charsUnit => 'chars';

  @override
  String get thousandCharsUnit => 'K';

  @override
  String get livePreview => 'Live Preview';

  @override
  String get fontSelection => 'Font Selection';

  @override
  String get typographyParams => 'Typography';

  @override
  String get advancedTypography => 'Advanced';

  @override
  String get cjkOptimization => 'CJK';

  @override
  String get punctuationSqueeze => 'Punctuation Squeeze';

  @override
  String get punctuationSqueezeDesc =>
      'Reduce spacing around Chinese punctuation';

  @override
  String get baselineAlign => 'Baseline Align';

  @override
  String get baselineAlignDesc =>
      'Force uniform line height to prevent text jumping';

  @override
  String get verticalMode => 'Vertical Mode';

  @override
  String get verticalModeDesc =>
      'Right-to-left reading, ideal for classical texts';

  @override
  String get ttsPreviewStop => 'Stop';

  @override
  String get ttsPreviewPlay => 'Preview';

  @override
  String get ttsAutoRefresh => 'Auto-refresh on change';

  @override
  String get ttsVoiceEngine => 'Voice Engine';

  @override
  String get ttsEngine => 'TTS Engine';

  @override
  String get systemDefault => 'System Default';

  @override
  String get ttsEnglishVoice => 'English Voice';

  @override
  String get ttsChineseVoice => 'Chinese Voice';

  @override
  String get ttsPlaybackParams => 'Playback';

  @override
  String get ttsPitch => 'Pitch';

  @override
  String get ttsPauseBetween => 'Pause Between Sentences';

  @override
  String get ttsBilingualReading => 'Bilingual Reading';

  @override
  String get zephyrExclusive => 'Zephyr Exclusive';

  @override
  String get ttsBilingualAlternate => 'Alternate Bilingual';

  @override
  String get ttsBilingualAlternateDesc => 'Read English first, then Chinese';

  @override
  String get ttsOriginalOnly => 'Original Only';

  @override
  String get ttsOriginalOnlyDesc =>
      'Skip translations, ideal for listening practice';

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
  String get otherMarkdownPreview => 'Markdown Preview';

  @override
  String get otherMarkdownPreviewDesc => 'Render Markdown in notes list';

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
  String get clearAllData => 'Clear All Data';

  @override
  String get clearAllDataDesc => 'Delete books, notes, vocabulary, records';

  @override
  String get confirmReset => 'Confirm Reset';

  @override
  String get confirmResetContent =>
      'This will reset typography, theme, sync settings to defaults.\n\nBooks, notes and vocabulary won\'t be deleted.';

  @override
  String get clearAllDataTitle => 'Clear All Data';

  @override
  String get clearAllDataContent =>
      'This will delete all books, notes, vocabulary, reading progress and statistics.\n\nWe recommend backing up via WebDAV first.\n\nThis action cannot be undone.';

  @override
  String get confirmClear => 'Confirm Clear';
}
