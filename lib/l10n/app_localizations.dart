import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader'**
  String get appName;

  /// No description provided for @tabHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get tabHome;

  /// No description provided for @tabBookshelf.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get tabBookshelf;

  /// No description provided for @tabStatistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get tabStatistics;

  /// No description provided for @tabProfile.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get tabProfile;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @continueReading.
  ///
  /// In zh, this message translates to:
  /// **'继续阅读'**
  String get continueReading;

  /// No description provided for @recentReading.
  ///
  /// In zh, this message translates to:
  /// **'最近阅读'**
  String get recentReading;

  /// No description provided for @noReadingRecord.
  ///
  /// In zh, this message translates to:
  /// **'暂无阅读记录'**
  String get noReadingRecord;

  /// No description provided for @bookshelf.
  ///
  /// In zh, this message translates to:
  /// **'书架'**
  String get bookshelf;

  /// No description provided for @searchBooks.
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍'**
  String get searchBooks;

  /// No description provided for @importBook.
  ///
  /// In zh, this message translates to:
  /// **'导入书籍'**
  String get importBook;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @reading.
  ///
  /// In zh, this message translates to:
  /// **'在读'**
  String get reading;

  /// No description provided for @notStarted.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get notStarted;

  /// No description provided for @finished.
  ///
  /// In zh, this message translates to:
  /// **'已读完'**
  String get finished;

  /// No description provided for @gridView.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get listView;

  /// No description provided for @noBooks.
  ///
  /// In zh, this message translates to:
  /// **'暂无书籍'**
  String get noBooks;

  /// No description provided for @bookDetail.
  ///
  /// In zh, this message translates to:
  /// **'书籍详情'**
  String get bookDetail;

  /// No description provided for @author.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get author;

  /// No description provided for @translator.
  ///
  /// In zh, this message translates to:
  /// **'译者'**
  String get translator;

  /// No description provided for @publisher.
  ///
  /// In zh, this message translates to:
  /// **'出版社'**
  String get publisher;

  /// No description provided for @format.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get format;

  /// No description provided for @fileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小'**
  String get fileSize;

  /// No description provided for @totalPages.
  ///
  /// In zh, this message translates to:
  /// **'总页数'**
  String get totalPages;

  /// No description provided for @readingProgress.
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get readingProgress;

  /// No description provided for @readingTime.
  ///
  /// In zh, this message translates to:
  /// **'阅读时长'**
  String get readingTime;

  /// No description provided for @readingCount.
  ///
  /// In zh, this message translates to:
  /// **'阅读次数'**
  String get readingCount;

  /// No description provided for @estimatedRemaining.
  ///
  /// In zh, this message translates to:
  /// **'预计剩余'**
  String get estimatedRemaining;

  /// No description provided for @estimatedTime.
  ///
  /// In zh, this message translates to:
  /// **'约 {hours}小时{minutes}分钟'**
  String estimatedTime(Object hours, Object minutes);

  /// No description provided for @estimatedTimeShort.
  ///
  /// In zh, this message translates to:
  /// **'约 {minutes}分钟'**
  String estimatedTimeShort(Object minutes);

  /// No description provided for @startReading.
  ///
  /// In zh, this message translates to:
  /// **'开始阅读'**
  String get startReading;

  /// No description provided for @readFromBeginning.
  ///
  /// In zh, this message translates to:
  /// **'从头开始'**
  String get readFromBeginning;

  /// No description provided for @notesCount.
  ///
  /// In zh, this message translates to:
  /// **'笔记数'**
  String get notesCount;

  /// No description provided for @highlightsCount.
  ///
  /// In zh, this message translates to:
  /// **'高亮数'**
  String get highlightsCount;

  /// No description provided for @vocabularyCount.
  ///
  /// In zh, this message translates to:
  /// **'生词数'**
  String get vocabularyCount;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @exportNotes.
  ///
  /// In zh, this message translates to:
  /// **'导出笔记'**
  String get exportNotes;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @reader.
  ///
  /// In zh, this message translates to:
  /// **'阅读器'**
  String get reader;

  /// No description provided for @scrollMode.
  ///
  /// In zh, this message translates to:
  /// **'滚动'**
  String get scrollMode;

  /// No description provided for @pageTurnMode.
  ///
  /// In zh, this message translates to:
  /// **'翻页'**
  String get pageTurnMode;

  /// No description provided for @paginationMode.
  ///
  /// In zh, this message translates to:
  /// **'分页'**
  String get paginationMode;

  /// No description provided for @bilingualMode.
  ///
  /// In zh, this message translates to:
  /// **'对照'**
  String get bilingualMode;

  /// No description provided for @horizontal.
  ///
  /// In zh, this message translates to:
  /// **'横排'**
  String get horizontal;

  /// No description provided for @vertical.
  ///
  /// In zh, this message translates to:
  /// **'竖排'**
  String get vertical;

  /// No description provided for @fontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSize;

  /// No description provided for @followSystemFontScale.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystemFontScale;

  /// No description provided for @lineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行间距'**
  String get lineHeight;

  /// No description provided for @letterSpacing.
  ///
  /// In zh, this message translates to:
  /// **'字间距'**
  String get letterSpacing;

  /// No description provided for @paragraphSpacing.
  ///
  /// In zh, this message translates to:
  /// **'段间距'**
  String get paragraphSpacing;

  /// No description provided for @pageMargin.
  ///
  /// In zh, this message translates to:
  /// **'页边距'**
  String get pageMargin;

  /// No description provided for @readingBackground.
  ///
  /// In zh, this message translates to:
  /// **'阅读背景'**
  String get readingBackground;

  /// No description provided for @brightness.
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get brightness;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @font.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get font;

  /// No description provided for @defaultFont.
  ///
  /// In zh, this message translates to:
  /// **'系统默认'**
  String get defaultFont;

  /// No description provided for @chapterN.
  ///
  /// In zh, this message translates to:
  /// **'第 {n} 章'**
  String chapterN(Object n);

  /// No description provided for @pageInfo.
  ///
  /// In zh, this message translates to:
  /// **'{current}/{total}'**
  String pageInfo(Object current, Object total);

  /// No description provided for @bookmarks.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get bookmarks;

  /// No description provided for @addBookmark.
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get addBookmark;

  /// No description provided for @noBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'暂无书签'**
  String get noBookmarks;

  /// No description provided for @searchInPage.
  ///
  /// In zh, this message translates to:
  /// **'页面内查找'**
  String get searchInPage;

  /// No description provided for @noResults.
  ///
  /// In zh, this message translates to:
  /// **'无结果'**
  String get noResults;

  /// No description provided for @ttsPlay.
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get ttsPlay;

  /// No description provided for @ttsPause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get ttsPause;

  /// No description provided for @ttsStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get ttsStop;

  /// No description provided for @ttsSpeed.
  ///
  /// In zh, this message translates to:
  /// **'语速'**
  String get ttsSpeed;

  /// No description provided for @selectionCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get selectionCopy;

  /// No description provided for @selectionHighlight.
  ///
  /// In zh, this message translates to:
  /// **'高亮'**
  String get selectionHighlight;

  /// No description provided for @selectionNote.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get selectionNote;

  /// No description provided for @selectionDictionary.
  ///
  /// In zh, this message translates to:
  /// **'查词'**
  String get selectionDictionary;

  /// No description provided for @selectionVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'生词本'**
  String get selectionVocabulary;

  /// No description provided for @selectionBilingual.
  ///
  /// In zh, this message translates to:
  /// **'标注两侧'**
  String get selectionBilingual;

  /// No description provided for @highlightYellow.
  ///
  /// In zh, this message translates to:
  /// **'黄色'**
  String get highlightYellow;

  /// No description provided for @highlightGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿色'**
  String get highlightGreen;

  /// No description provided for @highlightBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝色'**
  String get highlightBlue;

  /// No description provided for @highlightPink.
  ///
  /// In zh, this message translates to:
  /// **'粉色'**
  String get highlightPink;

  /// No description provided for @highlightPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫色'**
  String get highlightPurple;

  /// No description provided for @dictionary.
  ///
  /// In zh, this message translates to:
  /// **'词典'**
  String get dictionary;

  /// No description provided for @lookupWord.
  ///
  /// In zh, this message translates to:
  /// **'查词'**
  String get lookupWord;

  /// No description provided for @addToVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'加入生词本'**
  String get addToVocabulary;

  /// No description provided for @noDefinition.
  ///
  /// In zh, this message translates to:
  /// **'未找到释义'**
  String get noDefinition;

  /// No description provided for @vocabulary.
  ///
  /// In zh, this message translates to:
  /// **'生词本'**
  String get vocabulary;

  /// No description provided for @vocabularyBook.
  ///
  /// In zh, this message translates to:
  /// **'生词本'**
  String get vocabularyBook;

  /// No description provided for @wordCount.
  ///
  /// In zh, this message translates to:
  /// **'词数'**
  String get wordCount;

  /// No description provided for @learning.
  ///
  /// In zh, this message translates to:
  /// **'学习中'**
  String get learning;

  /// No description provided for @known.
  ///
  /// In zh, this message translates to:
  /// **'已掌握'**
  String get known;

  /// No description provided for @newWord.
  ///
  /// In zh, this message translates to:
  /// **'新词'**
  String get newWord;

  /// No description provided for @searchWords.
  ///
  /// In zh, this message translates to:
  /// **'搜索单词'**
  String get searchWords;

  /// No description provided for @noWords.
  ///
  /// In zh, this message translates to:
  /// **'暂无生词'**
  String get noWords;

  /// No description provided for @statusUnlearned.
  ///
  /// In zh, this message translates to:
  /// **'未学'**
  String get statusUnlearned;

  /// No description provided for @statusLearning.
  ///
  /// In zh, this message translates to:
  /// **'学习中'**
  String get statusLearning;

  /// No description provided for @statusMastered.
  ///
  /// In zh, this message translates to:
  /// **'已掌握'**
  String get statusMastered;

  /// No description provided for @fromBook.
  ///
  /// In zh, this message translates to:
  /// **'来自'**
  String get fromBook;

  /// No description provided for @statistics.
  ///
  /// In zh, this message translates to:
  /// **'阅读统计'**
  String get statistics;

  /// No description provided for @annualReport.
  ///
  /// In zh, this message translates to:
  /// **'年度阅览报告'**
  String get annualReport;

  /// No description provided for @readingOverview.
  ///
  /// In zh, this message translates to:
  /// **'阅读概览'**
  String get readingOverview;

  /// No description provided for @weeklyOverview.
  ///
  /// In zh, this message translates to:
  /// **'本周总览'**
  String get weeklyOverview;

  /// No description provided for @readingDuration.
  ///
  /// In zh, this message translates to:
  /// **'阅读时长'**
  String get readingDuration;

  /// No description provided for @readingWords.
  ///
  /// In zh, this message translates to:
  /// **'阅读字数'**
  String get readingWords;

  /// No description provided for @readingDays.
  ///
  /// In zh, this message translates to:
  /// **'阅读天数'**
  String get readingDays;

  /// No description provided for @consecutiveDays.
  ///
  /// In zh, this message translates to:
  /// **'连续阅读天数'**
  String get consecutiveDays;

  /// No description provided for @booksCompleted.
  ///
  /// In zh, this message translates to:
  /// **'读完书籍'**
  String get booksCompleted;

  /// No description provided for @readingSpeed.
  ///
  /// In zh, this message translates to:
  /// **'平均阅读速度'**
  String get readingSpeed;

  /// No description provided for @wordsPerMinute.
  ///
  /// In zh, this message translates to:
  /// **'字/分钟'**
  String get wordsPerMinute;

  /// No description provided for @readingFootprint.
  ///
  /// In zh, this message translates to:
  /// **'阅读足迹'**
  String get readingFootprint;

  /// No description provided for @daysActive.
  ///
  /// In zh, this message translates to:
  /// **'天活跃'**
  String get daysActive;

  /// No description provided for @readingTrend.
  ///
  /// In zh, this message translates to:
  /// **'本周阅读趋势'**
  String get readingTrend;

  /// No description provided for @readingRhythm.
  ///
  /// In zh, this message translates to:
  /// **'阅读节奏'**
  String get readingRhythm;

  /// No description provided for @recentDays.
  ///
  /// In zh, this message translates to:
  /// **'近 {days} 天'**
  String recentDays(Object days);

  /// No description provided for @sessions.
  ///
  /// In zh, this message translates to:
  /// **'阅读会话'**
  String get sessions;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @appSettings.
  ///
  /// In zh, this message translates to:
  /// **'应用设置'**
  String get appSettings;

  /// No description provided for @readingSettings.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get readingSettings;

  /// No description provided for @themeSettings.
  ///
  /// In zh, this message translates to:
  /// **'主题设置'**
  String get themeSettings;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'阅读外观'**
  String get appearance;

  /// No description provided for @readerBgColor.
  ///
  /// In zh, this message translates to:
  /// **'阅读背景色'**
  String get readerBgColor;

  /// No description provided for @fontSettings.
  ///
  /// In zh, this message translates to:
  /// **'字体设置'**
  String get fontSettings;

  /// No description provided for @pageSettings.
  ///
  /// In zh, this message translates to:
  /// **'翻页设置'**
  String get pageSettings;

  /// No description provided for @screenSettings.
  ///
  /// In zh, this message translates to:
  /// **'屏幕设置'**
  String get screenSettings;

  /// No description provided for @keepScreenOn.
  ///
  /// In zh, this message translates to:
  /// **'保持屏幕常亮'**
  String get keepScreenOn;

  /// No description provided for @showBattery.
  ///
  /// In zh, this message translates to:
  /// **'显示电量'**
  String get showBattery;

  /// No description provided for @showTime.
  ///
  /// In zh, this message translates to:
  /// **'显示时间'**
  String get showTime;

  /// No description provided for @clickZone.
  ///
  /// In zh, this message translates to:
  /// **'点击区域'**
  String get clickZone;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @chinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @region.
  ///
  /// In zh, this message translates to:
  /// **'地区'**
  String get region;

  /// No description provided for @syncSettings.
  ///
  /// In zh, this message translates to:
  /// **'同步设置'**
  String get syncSettings;

  /// No description provided for @manualSync.
  ///
  /// In zh, this message translates to:
  /// **'手动同步'**
  String get manualSync;

  /// No description provided for @daily.
  ///
  /// In zh, this message translates to:
  /// **'每天一次'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In zh, this message translates to:
  /// **'每周一次'**
  String get weekly;

  /// No description provided for @backupRestore.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupRestore;

  /// No description provided for @backup.
  ///
  /// In zh, this message translates to:
  /// **'备份数据'**
  String get backup;

  /// No description provided for @restore.
  ///
  /// In zh, this message translates to:
  /// **'恢复数据'**
  String get restore;

  /// No description provided for @storageManagement.
  ///
  /// In zh, this message translates to:
  /// **'存储管理'**
  String get storageManagement;

  /// No description provided for @clearCache.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get clearCache;

  /// No description provided for @cacheSize.
  ///
  /// In zh, this message translates to:
  /// **'缓存大小'**
  String get cacheSize;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @userAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get userAgreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @resetToDefault.
  ///
  /// In zh, this message translates to:
  /// **'重置为默认值'**
  String get resetToDefault;

  /// No description provided for @sync.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get sync;

  /// No description provided for @webdavConfig.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 配置'**
  String get webdavConfig;

  /// No description provided for @serverUrl.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverUrl;

  /// No description provided for @username.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// No description provided for @password.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// No description provided for @remotePath.
  ///
  /// In zh, this message translates to:
  /// **'远程路径'**
  String get remotePath;

  /// No description provided for @selectPreset.
  ///
  /// In zh, this message translates to:
  /// **'选择预设'**
  String get selectPreset;

  /// No description provided for @clearConfig.
  ///
  /// In zh, this message translates to:
  /// **'清除配置'**
  String get clearConfig;

  /// No description provided for @serverUrlRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get serverUrlRequired;

  /// No description provided for @serverUrlInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入完整的 URL（包含 http:// 或 https://）'**
  String get serverUrlInvalid;

  /// No description provided for @usernameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get usernameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get passwordRequired;

  /// No description provided for @remotePathRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入远程路径'**
  String get remotePathRequired;

  /// No description provided for @remotePathInvalid.
  ///
  /// In zh, this message translates to:
  /// **'远程路径应以 / 开头'**
  String get remotePathInvalid;

  /// No description provided for @configSaved.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 配置已保存'**
  String get configSaved;

  /// No description provided for @saveConfigFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存配置失败'**
  String get saveConfigFailed;

  /// No description provided for @configCleared.
  ///
  /// In zh, this message translates to:
  /// **'配置已清除'**
  String get configCleared;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @syncHistory.
  ///
  /// In zh, this message translates to:
  /// **'同步历史'**
  String get syncHistory;

  /// No description provided for @syncSuccess.
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get syncSuccess;

  /// No description provided for @syncFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncFailed;

  /// No description provided for @syncConfigInvalid.
  ///
  /// In zh, this message translates to:
  /// **'同步配置无效，请检查 WebDAV 设置'**
  String get syncConfigInvalid;

  /// No description provided for @dataCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清理缓存'**
  String get dataCleared;

  /// No description provided for @dataClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存失败：{error}'**
  String dataClearFailed(Object error);

  /// No description provided for @lastSync.
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get lastSync;

  /// No description provided for @conflictResolution.
  ///
  /// In zh, this message translates to:
  /// **'冲突解决'**
  String get conflictResolution;

  /// No description provided for @useLocal.
  ///
  /// In zh, this message translates to:
  /// **'使用本地版本'**
  String get useLocal;

  /// No description provided for @useRemote.
  ///
  /// In zh, this message translates to:
  /// **'使用远程版本'**
  String get useRemote;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @confirmAgain.
  ///
  /// In zh, this message translates to:
  /// **'二次确认'**
  String get confirmAgain;

  /// No description provided for @continueAction.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueAction;

  /// No description provided for @success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get success;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failed;

  /// No description provided for @offline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// No description provided for @empty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get empty;

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @unknownAuthor.
  ///
  /// In zh, this message translates to:
  /// **'未知作者'**
  String get unknownAuthor;

  /// No description provided for @greetingMorning.
  ///
  /// In zh, this message translates to:
  /// **'早上好'**
  String get greetingMorning;

  /// No description provided for @greetingNoon.
  ///
  /// In zh, this message translates to:
  /// **'中午好'**
  String get greetingNoon;

  /// No description provided for @greetingAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午好'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上好'**
  String get greetingEvening;

  /// No description provided for @greetingLateNight.
  ///
  /// In zh, this message translates to:
  /// **'夜深了'**
  String get greetingLateNight;

  /// No description provided for @startReadingJourney.
  ///
  /// In zh, this message translates to:
  /// **'开始你的阅读之旅'**
  String get startReadingJourney;

  /// No description provided for @exploreNewWorld.
  ///
  /// In zh, this message translates to:
  /// **'打开一本书，探索新的世界'**
  String get exploreNewWorld;

  /// No description provided for @goToBookshelf.
  ///
  /// In zh, this message translates to:
  /// **'去书库'**
  String get goToBookshelf;

  /// No description provided for @splashTagline.
  ///
  /// In zh, this message translates to:
  /// **'轻如风，阅无界'**
  String get splashTagline;

  /// No description provided for @bookshelfSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍...'**
  String get bookshelfSearchHint;

  /// No description provided for @bookshelfSettings.
  ///
  /// In zh, this message translates to:
  /// **'书架设置'**
  String get bookshelfSettings;

  /// No description provided for @bookshelfEmpty.
  ///
  /// In zh, this message translates to:
  /// **'书架空空如也'**
  String get bookshelfEmpty;

  /// No description provided for @closeSearch.
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get closeSearch;

  /// No description provided for @scanFolder.
  ///
  /// In zh, this message translates to:
  /// **'扫描文件夹'**
  String get scanFolder;

  /// No description provided for @batchManage.
  ///
  /// In zh, this message translates to:
  /// **'批量管理'**
  String get batchManage;

  /// No description provided for @globalSearch.
  ///
  /// In zh, this message translates to:
  /// **'全局搜索'**
  String get globalSearch;

  /// No description provided for @editCategory.
  ///
  /// In zh, this message translates to:
  /// **'编辑分类'**
  String get editCategory;

  /// No description provided for @markAsUnread.
  ///
  /// In zh, this message translates to:
  /// **'标记为未开始'**
  String get markAsUnread;

  /// No description provided for @markAsReading.
  ///
  /// In zh, this message translates to:
  /// **'标记为阅读中'**
  String get markAsReading;

  /// No description provided for @reExtractCover.
  ///
  /// In zh, this message translates to:
  /// **'补提取封面'**
  String get reExtractCover;

  /// No description provided for @unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpin;

  /// No description provided for @pinTop.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pinTop;

  /// No description provided for @selectCategory.
  ///
  /// In zh, this message translates to:
  /// **'选择分类'**
  String get selectCategory;

  /// No description provided for @bookImported.
  ///
  /// In zh, this message translates to:
  /// **'已导入：{title}'**
  String bookImported(Object title);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(Object error);

  /// No description provided for @scanningFolder.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描文件夹...'**
  String get scanningFolder;

  /// No description provided for @noBookFilesFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到书籍文件'**
  String get noBookFilesFound;

  /// No description provided for @scanComplete.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成，导入了 {count} 本书'**
  String scanComplete(Object count);

  /// No description provided for @scanProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在扫描 {done}/{total}...'**
  String scanProgress(Object done, Object total);

  /// No description provided for @scanCompleteWithFailures.
  ///
  /// In zh, this message translates to:
  /// **'扫描完成，导入了 {success} 本，导入失败 {fail} 本'**
  String scanCompleteWithFailures(Object fail, Object success);

  /// No description provided for @showReadingProgress.
  ///
  /// In zh, this message translates to:
  /// **'显示阅读进度'**
  String get showReadingProgress;

  /// No description provided for @defaultSort.
  ///
  /// In zh, this message translates to:
  /// **'默认排序'**
  String get defaultSort;

  /// No description provided for @selectSortMethod.
  ///
  /// In zh, this message translates to:
  /// **'选择排序方式'**
  String get selectSortMethod;

  /// No description provided for @moveCategory.
  ///
  /// In zh, this message translates to:
  /// **'移动分类'**
  String get moveCategory;

  /// No description provided for @changeStatus.
  ///
  /// In zh, this message translates to:
  /// **'更改状态'**
  String get changeStatus;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @selectedBooksCount.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 本'**
  String selectedBooksCount(Object count);

  /// No description provided for @bookInfo.
  ///
  /// In zh, this message translates to:
  /// **'书籍信息'**
  String get bookInfo;

  /// No description provided for @chapterCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'章节数'**
  String get chapterCountLabel;

  /// No description provided for @totalChars.
  ///
  /// In zh, this message translates to:
  /// **'总字符'**
  String get totalChars;

  /// No description provided for @addedTime.
  ///
  /// In zh, this message translates to:
  /// **'添加时间'**
  String get addedTime;

  /// No description provided for @chapterList.
  ///
  /// In zh, this message translates to:
  /// **'章节列表'**
  String get chapterList;

  /// No description provided for @collapse.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// No description provided for @viewAllChapters.
  ///
  /// In zh, this message translates to:
  /// **'查看全部 {count} 章'**
  String viewAllChapters(Object count);

  /// No description provided for @category.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get category;

  /// No description provided for @weeklyReadingTime.
  ///
  /// In zh, this message translates to:
  /// **'本周阅读时长'**
  String get weeklyReadingTime;

  /// No description provided for @dangerZone.
  ///
  /// In zh, this message translates to:
  /// **'危险操作'**
  String get dangerZone;

  /// No description provided for @deleteBook.
  ///
  /// In zh, this message translates to:
  /// **'删除本书'**
  String get deleteBook;

  /// No description provided for @confirmDeleteBookMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除本书吗？此操作不可恢复。'**
  String get confirmDeleteBookMessage;

  /// No description provided for @deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String deleteFailed(Object error);

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @saveHighlightFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存高亮失败'**
  String get saveHighlightFailed;

  /// No description provided for @saveAnnotationFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存笔记失败'**
  String get saveAnnotationFailed;

  /// No description provided for @deleteHighlightFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除高亮失败'**
  String get deleteHighlightFailed;

  /// No description provided for @updateNoteFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新笔记失败'**
  String get updateNoteFailed;

  /// No description provided for @bilingualHighlightFailed.
  ///
  /// In zh, this message translates to:
  /// **'双语高亮创建失败'**
  String get bilingualHighlightFailed;

  /// No description provided for @chapterLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'章节加载失败：{error}'**
  String chapterLoadFailed(Object error);

  /// No description provided for @contentEmpty.
  ///
  /// In zh, this message translates to:
  /// **'内容为空'**
  String get contentEmpty;

  /// No description provided for @appearanceSection.
  ///
  /// In zh, this message translates to:
  /// **'外观主题'**
  String get appearanceSection;

  /// No description provided for @readingModeSection.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get readingModeSection;

  /// No description provided for @layoutSection.
  ///
  /// In zh, this message translates to:
  /// **'版面布局'**
  String get layoutSection;

  /// No description provided for @typographySection.
  ///
  /// In zh, this message translates to:
  /// **'文字排版'**
  String get typographySection;

  /// No description provided for @previous.
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get next;

  /// No description provided for @currentlyReading.
  ///
  /// In zh, this message translates to:
  /// **'正在阅读'**
  String get currentlyReading;

  /// No description provided for @setBilingualTranslation.
  ///
  /// In zh, this message translates to:
  /// **'设置对照译文'**
  String get setBilingualTranslation;

  /// No description provided for @pasteTranslationHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴或输入当前章节的译文内容：'**
  String get pasteTranslationHint;

  /// No description provided for @pasteTranslationPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'在此粘贴译文文本…'**
  String get pasteTranslationPlaceholder;

  /// No description provided for @addNote.
  ///
  /// In zh, this message translates to:
  /// **'添加笔记'**
  String get addNote;

  /// No description provided for @noteHintText.
  ///
  /// In zh, this message translates to:
  /// **'输入你的笔记内容…'**
  String get noteHintText;

  /// No description provided for @editNote.
  ///
  /// In zh, this message translates to:
  /// **'编辑笔记'**
  String get editNote;

  /// No description provided for @deleteHighlight.
  ///
  /// In zh, this message translates to:
  /// **'删除高亮'**
  String get deleteHighlight;

  /// No description provided for @profileDisplayName.
  ///
  /// In zh, this message translates to:
  /// **'书友'**
  String get profileDisplayName;

  /// No description provided for @profileTagline.
  ///
  /// In zh, this message translates to:
  /// **'阅读是一种生活态度'**
  String get profileTagline;

  /// No description provided for @consecutiveDaysLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续天数'**
  String get consecutiveDaysLabel;

  /// No description provided for @sectionStudyMgmt.
  ///
  /// In zh, this message translates to:
  /// **'学习与管理'**
  String get sectionStudyMgmt;

  /// No description provided for @sectionReadingExp.
  ///
  /// In zh, this message translates to:
  /// **'阅读体验'**
  String get sectionReadingExp;

  /// No description provided for @sectionSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get sectionSystem;

  /// No description provided for @learningNotes.
  ///
  /// In zh, this message translates to:
  /// **'学习与笔记'**
  String get learningNotes;

  /// No description provided for @readingSessions.
  ///
  /// In zh, this message translates to:
  /// **'阅读会话'**
  String get readingSessions;

  /// No description provided for @storageSync.
  ///
  /// In zh, this message translates to:
  /// **'存储与同步'**
  String get storageSync;

  /// No description provided for @ttsSettings.
  ///
  /// In zh, this message translates to:
  /// **'朗读设置'**
  String get ttsSettings;

  /// No description provided for @typographySettings.
  ///
  /// In zh, this message translates to:
  /// **'排版与字体'**
  String get typographySettings;

  /// No description provided for @themeBrightness.
  ///
  /// In zh, this message translates to:
  /// **'主题与亮度'**
  String get themeBrightness;

  /// No description provided for @otherSettings.
  ///
  /// In zh, this message translates to:
  /// **'其他设置'**
  String get otherSettings;

  /// No description provided for @synced.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get synced;

  /// No description provided for @appVersionDisplay.
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader v{version}'**
  String appVersionDisplay(Object version);

  /// No description provided for @appIntroduction.
  ///
  /// In zh, this message translates to:
  /// **'应用介绍'**
  String get appIntroduction;

  /// No description provided for @coreFeatures.
  ///
  /// In zh, this message translates to:
  /// **'核心特性'**
  String get coreFeatures;

  /// No description provided for @techStack.
  ///
  /// In zh, this message translates to:
  /// **'技术栈'**
  String get techStack;

  /// No description provided for @moreInfo.
  ///
  /// In zh, this message translates to:
  /// **'更多信息'**
  String get moreInfo;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @openSourceLicense.
  ///
  /// In zh, this message translates to:
  /// **'开源许可证'**
  String get openSourceLicense;

  /// No description provided for @feedback.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get feedback;

  /// No description provided for @alreadyLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get alreadyLatestVersion;

  /// No description provided for @cannotOpenLink.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get cannotOpenLink;

  /// No description provided for @aboutFeature1.
  ///
  /// In zh, this message translates to:
  /// **'纯离线使用，无需网络'**
  String get aboutFeature1;

  /// No description provided for @aboutFeature2.
  ///
  /// In zh, this message translates to:
  /// **'支持 EPUB、TXT、PDF 格式'**
  String get aboutFeature2;

  /// No description provided for @aboutFeature3.
  ///
  /// In zh, this message translates to:
  /// **'智能排版引擎'**
  String get aboutFeature3;

  /// No description provided for @aboutFeature4.
  ///
  /// In zh, this message translates to:
  /// **'双语对照阅读'**
  String get aboutFeature4;

  /// No description provided for @aboutFeature5.
  ///
  /// In zh, this message translates to:
  /// **'生词本与学习记录'**
  String get aboutFeature5;

  /// No description provided for @aboutFeature6.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 多端同步'**
  String get aboutFeature6;

  /// No description provided for @copyrightFooter.
  ///
  /// In zh, this message translates to:
  /// **'© 2026 Zephyr Reader'**
  String get copyrightFooter;

  /// No description provided for @madeWithFooter.
  ///
  /// In zh, this message translates to:
  /// **'用 Flutter · Rust · ❤ 构建'**
  String get madeWithFooter;

  /// No description provided for @errorFileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'文件未找到'**
  String get errorFileNotFound;

  /// No description provided for @errorFileReadError.
  ///
  /// In zh, this message translates to:
  /// **'文件读取失败'**
  String get errorFileReadError;

  /// No description provided for @errorUnsupportedFormat.
  ///
  /// In zh, this message translates to:
  /// **'不支持的格式'**
  String get errorUnsupportedFormat;

  /// No description provided for @errorEpubParse.
  ///
  /// In zh, this message translates to:
  /// **'EPUB 解析错误'**
  String get errorEpubParse;

  /// No description provided for @errorDatabase.
  ///
  /// In zh, this message translates to:
  /// **'数据库错误'**
  String get errorDatabase;

  /// No description provided for @errorInternal.
  ///
  /// In zh, this message translates to:
  /// **'内部错误'**
  String get errorInternal;

  /// No description provided for @errorTaskPanic.
  ///
  /// In zh, this message translates to:
  /// **'任务失败：{task}'**
  String errorTaskPanic(Object task);

  /// No description provided for @selectDictionaryFile.
  ///
  /// In zh, this message translates to:
  /// **'选择词典文件'**
  String get selectDictionaryFile;

  /// No description provided for @selectMdxDescription.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个 .mdx 词典文件…'**
  String get selectMdxDescription;

  /// No description provided for @invalidMdxFile.
  ///
  /// In zh, this message translates to:
  /// **'请选择有效的 .mdx 文件'**
  String get invalidMdxFile;

  /// No description provided for @dictionaryLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'词典加载失败，请检查文件'**
  String get dictionaryLoadFailed;

  /// No description provided for @pronunciation.
  ///
  /// In zh, this message translates to:
  /// **'发音'**
  String get pronunciation;

  /// No description provided for @noExactMatch.
  ///
  /// In zh, this message translates to:
  /// **'未找到精确匹配。您是不是要找：'**
  String get noExactMatch;

  /// No description provided for @wordSegmentation.
  ///
  /// In zh, this message translates to:
  /// **'分词：'**
  String get wordSegmentation;

  /// No description provided for @bilingualNoAlignment.
  ///
  /// In zh, this message translates to:
  /// **'未找到双语对齐位置'**
  String get bilingualNoAlignment;

  /// No description provided for @bilingualNoParagraph.
  ///
  /// In zh, this message translates to:
  /// **'未找到对应段落'**
  String get bilingualNoParagraph;

  /// No description provided for @bilingualHighlightCreated.
  ///
  /// In zh, this message translates to:
  /// **'双语高亮已创建'**
  String get bilingualHighlightCreated;

  /// No description provided for @selectFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get selectFile;

  /// No description provided for @dictionaryConfigHint.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个 .mdx 格式的词典文件。如果有同名的 .mdd 资源文件（音频/图片），放在同一目录下会自动加载。'**
  String get dictionaryConfigHint;

  /// No description provided for @categoryManagement.
  ///
  /// In zh, this message translates to:
  /// **'分类管理'**
  String get categoryManagement;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In zh, this message translates to:
  /// **'轻如风，阅无界'**
  String get aboutTagline;

  /// No description provided for @aboutSectionFeatures.
  ///
  /// In zh, this message translates to:
  /// **'核心特性'**
  String get aboutSectionFeatures;

  /// No description provided for @aboutSectionTechStack.
  ///
  /// In zh, this message translates to:
  /// **'技术栈'**
  String get aboutSectionTechStack;

  /// No description provided for @aboutSectionLinks.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get aboutSectionLinks;

  /// No description provided for @aboutDescription.
  ///
  /// In zh, this message translates to:
  /// **'Zephyr Reader 是一款纯离线的双语小说阅读器，Flutter + Rust 构建，100% 本地，无后端，无广告，无数据收集，专注于中英文双语阅读体验。'**
  String get aboutDescription;

  /// No description provided for @aboutFeatureOffline.
  ///
  /// In zh, this message translates to:
  /// **'完全离线'**
  String get aboutFeatureOffline;

  /// No description provided for @aboutFeatureOfflineDesc.
  ///
  /// In zh, this message translates to:
  /// **'核心功能无需网络，无后端无广告'**
  String get aboutFeatureOfflineDesc;

  /// No description provided for @aboutFeaturePerformance.
  ///
  /// In zh, this message translates to:
  /// **'高性能'**
  String get aboutFeaturePerformance;

  /// No description provided for @aboutFeaturePerformanceDesc.
  ///
  /// In zh, this message translates to:
  /// **'Rust 引擎即时解析大文件'**
  String get aboutFeaturePerformanceDesc;

  /// No description provided for @aboutFeatureBilingual.
  ///
  /// In zh, this message translates to:
  /// **'双语对照'**
  String get aboutFeatureBilingual;

  /// No description provided for @aboutFeatureBilingualDesc.
  ///
  /// In zh, this message translates to:
  /// **'中英同权对齐'**
  String get aboutFeatureBilingualDesc;

  /// No description provided for @aboutFeatureThemes.
  ///
  /// In zh, this message translates to:
  /// **'多主题'**
  String get aboutFeatureThemes;

  /// No description provided for @aboutFeatureThemesDesc.
  ///
  /// In zh, this message translates to:
  /// **'浅色/深色/纯黑夜间模式'**
  String get aboutFeatureThemesDesc;

  /// No description provided for @aboutFeatureAdaptive.
  ///
  /// In zh, this message translates to:
  /// **'自适应布局'**
  String get aboutFeatureAdaptive;

  /// No description provided for @aboutFeatureAdaptiveDesc.
  ///
  /// In zh, this message translates to:
  /// **'手机和平板自动适配'**
  String get aboutFeatureAdaptiveDesc;

  /// No description provided for @aboutFeatureSync.
  ///
  /// In zh, this message translates to:
  /// **'WebDAV 同步'**
  String get aboutFeatureSync;

  /// No description provided for @aboutFeatureSyncDesc.
  ///
  /// In zh, this message translates to:
  /// **'多端同步与安全备份'**
  String get aboutFeatureSyncDesc;

  /// No description provided for @aboutCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get aboutCheckUpdate;

  /// No description provided for @aboutLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get aboutLatestVersion;

  /// No description provided for @aboutUserAgreement.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get aboutUserAgreement;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutOpenSourceLicense.
  ///
  /// In zh, this message translates to:
  /// **'开源许可证'**
  String get aboutOpenSourceLicense;

  /// No description provided for @aboutFeedback.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get aboutFeedback;

  /// No description provided for @aboutCannotOpenLink.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get aboutCannotOpenLink;

  /// No description provided for @unknownVersion.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknownVersion;

  /// No description provided for @prev.
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get prev;

  /// No description provided for @readAloud.
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get readAloud;

  /// No description provided for @addedToVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'已加入生词本：{word}'**
  String addedToVocabulary(Object word);

  /// No description provided for @addToVocabFailed.
  ///
  /// In zh, this message translates to:
  /// **'加入生词本失败：{error}'**
  String addToVocabFailed(Object error);

  /// No description provided for @readerThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'白天'**
  String get readerThemeLight;

  /// No description provided for @readerThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'夜间'**
  String get readerThemeDark;

  /// No description provided for @readerThemeSepia.
  ///
  /// In zh, this message translates to:
  /// **'护眼'**
  String get readerThemeSepia;

  /// No description provided for @readerFontSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get readerFontSizeSmall;

  /// No description provided for @readerFontSizeMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get readerFontSizeMedium;

  /// No description provided for @readerFontSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get readerFontSizeLarge;

  /// No description provided for @readerFontSizeXLarge.
  ///
  /// In zh, this message translates to:
  /// **'特大'**
  String get readerFontSizeXLarge;

  /// No description provided for @sortLastRead.
  ///
  /// In zh, this message translates to:
  /// **'最近阅读'**
  String get sortLastRead;

  /// No description provided for @sortCreatedAt.
  ///
  /// In zh, this message translates to:
  /// **'添加时间'**
  String get sortCreatedAt;

  /// No description provided for @sortTitle.
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get sortTitle;

  /// No description provided for @sortAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get sortAuthor;

  /// No description provided for @sortProgress.
  ///
  /// In zh, this message translates to:
  /// **'阅读进度'**
  String get sortProgress;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @introLabel.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get introLabel;

  /// No description provided for @bookTitle.
  ///
  /// In zh, this message translates to:
  /// **'书名'**
  String get bookTitle;

  /// No description provided for @currentChapter.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get currentChapter;

  /// No description provided for @editMetadata.
  ///
  /// In zh, this message translates to:
  /// **'编辑元数据'**
  String get editMetadata;

  /// No description provided for @statReadingTime.
  ///
  /// In zh, this message translates to:
  /// **'阅读时长'**
  String get statReadingTime;

  /// No description provided for @statReadingCount.
  ///
  /// In zh, this message translates to:
  /// **'阅读次数'**
  String get statReadingCount;

  /// No description provided for @statEstimatedRemaining.
  ///
  /// In zh, this message translates to:
  /// **'预计剩余'**
  String get statEstimatedRemaining;

  /// No description provided for @expand.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// No description provided for @tocTitle.
  ///
  /// In zh, this message translates to:
  /// **'目录（{count} 章）'**
  String tocTitle(Object count);

  /// No description provided for @totalChapters.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 章'**
  String totalChapters(Object count);

  /// No description provided for @isbn.
  ///
  /// In zh, this message translates to:
  /// **'ISBN'**
  String get isbn;

  /// No description provided for @bookIntro.
  ///
  /// In zh, this message translates to:
  /// **'内容简介'**
  String get bookIntro;

  /// No description provided for @timePresetSunsetToSunrise.
  ///
  /// In zh, this message translates to:
  /// **'日落到日出'**
  String get timePresetSunsetToSunrise;

  /// No description provided for @timePresetEveningToMorning.
  ///
  /// In zh, this message translates to:
  /// **'傍晚到早晨'**
  String get timePresetEveningToMorning;

  /// No description provided for @timePresetCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get timePresetCustom;

  /// No description provided for @appTheme.
  ///
  /// In zh, this message translates to:
  /// **'应用主题'**
  String get appTheme;

  /// No description provided for @autoTheme.
  ///
  /// In zh, this message translates to:
  /// **'自动主题'**
  String get autoTheme;

  /// No description provided for @autoThemeDesc.
  ///
  /// In zh, this message translates to:
  /// **'根据时间段自动切换深浅主题'**
  String get autoThemeDesc;

  /// No description provided for @autoThemeSchedule.
  ///
  /// In zh, this message translates to:
  /// **'定时设置'**
  String get autoThemeSchedule;

  /// No description provided for @bookFormat.
  ///
  /// In zh, this message translates to:
  /// **'格式'**
  String get bookFormat;

  /// No description provided for @bookIntroLabel.
  ///
  /// In zh, this message translates to:
  /// **'内容简介'**
  String get bookIntroLabel;

  /// No description provided for @sortDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择排序方式'**
  String get sortDialogTitle;

  /// No description provided for @tapLayoutRightHanded.
  ///
  /// In zh, this message translates to:
  /// **'右手模式'**
  String get tapLayoutRightHanded;

  /// No description provided for @tapLayoutLeftHanded.
  ///
  /// In zh, this message translates to:
  /// **'左手模式'**
  String get tapLayoutLeftHanded;

  /// No description provided for @tapLayout.
  ///
  /// In zh, this message translates to:
  /// **'翻页点击区域'**
  String get tapLayout;

  /// No description provided for @timeJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟前'**
  String timeMinutesAgo(Object minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时前'**
  String timeHoursAgo(Object hours);

  /// No description provided for @lastSyncTime.
  ///
  /// In zh, this message translates to:
  /// **'上次同步：{time}'**
  String lastSyncTime(Object time);

  /// No description provided for @todayReading.
  ///
  /// In zh, this message translates to:
  /// **'今日阅读'**
  String get todayReading;

  /// No description provided for @minutes.
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get minutes;

  /// No description provided for @goalTemplate.
  ///
  /// In zh, this message translates to:
  /// **'目标 {minutes} 分钟'**
  String goalTemplate(Object minutes);

  /// No description provided for @streakLabel.
  ///
  /// In zh, this message translates to:
  /// **'连续阅读'**
  String get streakLabel;

  /// No description provided for @daysUnit.
  ///
  /// In zh, this message translates to:
  /// **'天'**
  String get daysUnit;

  /// No description provided for @booksRead.
  ///
  /// In zh, this message translates to:
  /// **'读过 {count} 本书'**
  String booksRead(Object count);

  /// No description provided for @insufficientData.
  ///
  /// In zh, this message translates to:
  /// **'数据不足'**
  String get insufficientData;

  /// No description provided for @readingHeatmap.
  ///
  /// In zh, this message translates to:
  /// **'阅读热力图'**
  String get readingHeatmap;

  /// No description provided for @weekdayMon.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get weekdaySun;

  /// No description provided for @vocabStats.
  ///
  /// In zh, this message translates to:
  /// **'生词统计'**
  String get vocabStats;

  /// No description provided for @statusIgnored.
  ///
  /// In zh, this message translates to:
  /// **'已忽略'**
  String get statusIgnored;

  /// No description provided for @noSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无阅读会话'**
  String get noSessions;

  /// No description provided for @autoRecordHint.
  ///
  /// In zh, this message translates to:
  /// **'开始阅读后会自动记录'**
  String get autoRecordHint;

  /// No description provided for @sessionDetails.
  ///
  /// In zh, this message translates to:
  /// **'会话详情'**
  String get sessionDetails;

  /// No description provided for @unknownBook.
  ///
  /// In zh, this message translates to:
  /// **'未知书籍'**
  String get unknownBook;

  /// No description provided for @sessionSummary.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 次 · {duration} · 阅读 {chars}'**
  String sessionSummary(Object chars, Object count, Object duration);

  /// No description provided for @chapterInfo.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 章 · {chars}'**
  String chapterInfo(Object chars, Object index);

  /// No description provided for @deleteSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除会话记录'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除本书的所有阅读会话记录吗？'**
  String get deleteSessionConfirm;

  /// No description provided for @periodToday.
  ///
  /// In zh, this message translates to:
  /// **'本日'**
  String get periodToday;

  /// No description provided for @periodWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get periodWeek;

  /// No description provided for @periodMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get periodMonth;

  /// No description provided for @periodYear.
  ///
  /// In zh, this message translates to:
  /// **'全年'**
  String get periodYear;

  /// No description provided for @totalReadingTime.
  ///
  /// In zh, this message translates to:
  /// **'总阅读时长'**
  String get totalReadingTime;

  /// No description provided for @sessionsCount.
  ///
  /// In zh, this message translates to:
  /// **'次会话'**
  String get sessionsCount;

  /// No description provided for @wifiPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'WiFi 传书'**
  String get wifiPageTitle;

  /// No description provided for @wifiServerRunning.
  ///
  /// In zh, this message translates to:
  /// **'服务器运行中'**
  String get wifiServerRunning;

  /// No description provided for @wifiServerStopped.
  ///
  /// In zh, this message translates to:
  /// **'服务器已停止'**
  String get wifiServerStopped;

  /// No description provided for @wifiStartServer.
  ///
  /// In zh, this message translates to:
  /// **'启动服务器'**
  String get wifiStartServer;

  /// No description provided for @wifiStopServer.
  ///
  /// In zh, this message translates to:
  /// **'停止服务器'**
  String get wifiStopServer;

  /// No description provided for @wifiCopyLink.
  ///
  /// In zh, this message translates to:
  /// **'复制链接'**
  String get wifiCopyLink;

  /// No description provided for @wifiLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'链接已复制'**
  String get wifiLinkCopied;

  /// No description provided for @wifiInstruction.
  ///
  /// In zh, this message translates to:
  /// **'连接与电脑相同的 Wi-Fi 网络，在浏览器中打开上方地址即可传输文件。'**
  String get wifiInstruction;

  /// No description provided for @wifiFileUploaded.
  ///
  /// In zh, this message translates to:
  /// **'已上传：{filename}'**
  String wifiFileUploaded(Object filename);

  /// No description provided for @wifiServerStarted.
  ///
  /// In zh, this message translates to:
  /// **'服务器已启动'**
  String get wifiServerStarted;

  /// No description provided for @batchDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 本书吗？'**
  String batchDeleteConfirm(Object count);

  /// No description provided for @categoryName.
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get categoryName;

  /// No description provided for @addCategory.
  ///
  /// In zh, this message translates to:
  /// **'添加分类'**
  String get addCategory;

  /// No description provided for @editCategoryName.
  ///
  /// In zh, this message translates to:
  /// **'编辑分类名称'**
  String get editCategoryName;

  /// No description provided for @deleteCategory.
  ///
  /// In zh, this message translates to:
  /// **'删除分类'**
  String get deleteCategory;

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除分类「{name}」吗？关联书籍不会受影响。'**
  String confirmDeleteCategory(Object name);

  /// No description provided for @categoryNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入分类名称'**
  String get categoryNameRequired;

  /// No description provided for @categoryAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'分类名称已存在'**
  String get categoryAlreadyExists;

  /// No description provided for @noCategories.
  ///
  /// In zh, this message translates to:
  /// **'暂无分类'**
  String get noCategories;

  /// No description provided for @addCategoryHint.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角添加分类'**
  String get addCategoryHint;

  /// No description provided for @wifiTransferLog.
  ///
  /// In zh, this message translates to:
  /// **'传输记录'**
  String get wifiTransferLog;

  /// No description provided for @wifiWaitUpload.
  ///
  /// In zh, this message translates to:
  /// **'等待文件上传…'**
  String get wifiWaitUpload;

  /// No description provided for @wifiStartServerPrompt.
  ///
  /// In zh, this message translates to:
  /// **'启动服务器开始传输'**
  String get wifiStartServerPrompt;

  /// No description provided for @backupSuccess.
  ///
  /// In zh, this message translates to:
  /// **'备份成功'**
  String get backupSuccess;

  /// No description provided for @backupFailed.
  ///
  /// In zh, this message translates to:
  /// **'备份失败：{error}'**
  String backupFailed(Object error);

  /// No description provided for @restoreSuccess.
  ///
  /// In zh, this message translates to:
  /// **'恢复成功'**
  String get restoreSuccess;

  /// No description provided for @restoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复失败：{error}'**
  String restoreFailed(Object error);

  /// No description provided for @searchGroupBooks.
  ///
  /// In zh, this message translates to:
  /// **'书籍'**
  String get searchGroupBooks;

  /// No description provided for @searchGroupNotes.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get searchGroupNotes;

  /// No description provided for @searchGroupVocab.
  ///
  /// In zh, this message translates to:
  /// **'生词'**
  String get searchGroupVocab;

  /// No description provided for @searchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关结果'**
  String get searchNoResults;

  /// No description provided for @bookSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍内容…'**
  String get bookSearchHint;

  /// No description provided for @bookSearchHintAll.
  ///
  /// In zh, this message translates to:
  /// **'搜索所有书籍内容…'**
  String get bookSearchHintAll;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索书籍、笔记、生词…'**
  String get searchHint;

  /// No description provided for @searchHistory.
  ///
  /// In zh, this message translates to:
  /// **'搜索历史'**
  String get searchHistory;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败'**
  String get searchFailed;

  /// No description provided for @searchEnterKeyword.
  ///
  /// In zh, this message translates to:
  /// **'请输入搜索关键词'**
  String get searchEnterKeyword;

  /// No description provided for @searchTryOtherKeywords.
  ///
  /// In zh, this message translates to:
  /// **'尝试其他关键词'**
  String get searchTryOtherKeywords;

  /// No description provided for @searchError.
  ///
  /// In zh, this message translates to:
  /// **'搜索出错'**
  String get searchError;

  /// No description provided for @resultSummary.
  ///
  /// In zh, this message translates to:
  /// **'找到 {count} 条结果 · 耗时 {duration}ms'**
  String resultSummary(Object count, Object duration);

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @restoreRestartNotice.
  ///
  /// In zh, this message translates to:
  /// **'数据已还原，请重启应用以生效。'**
  String get restoreRestartNotice;

  /// No description provided for @backupSubtitleNever.
  ///
  /// In zh, this message translates to:
  /// **'从未备份'**
  String get backupSubtitleNever;

  /// No description provided for @backupSubtitleDays.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前备份 — 建议立即备份'**
  String backupSubtitleDays(Object days);

  /// No description provided for @backupSubtitleHours.
  ///
  /// In zh, this message translates to:
  /// **'{hours} 小时前备份'**
  String backupSubtitleHours(Object hours);

  /// No description provided for @backupSubtitleMinutes.
  ///
  /// In zh, this message translates to:
  /// **'{minutes} 分钟前备份'**
  String backupSubtitleMinutes(Object minutes);

  /// No description provided for @backupSubtitleJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚备份'**
  String get backupSubtitleJustNow;

  /// No description provided for @restoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'从备份还原'**
  String get restoreTitle;

  /// No description provided for @restoreSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择一个 .db 备份文件恢复数据'**
  String get restoreSubtitle;

  /// No description provided for @currentDataStats.
  ///
  /// In zh, this message translates to:
  /// **'当前数据统计'**
  String get currentDataStats;

  /// No description provided for @backingUp.
  ///
  /// In zh, this message translates to:
  /// **'备份中…'**
  String get backingUp;

  /// No description provided for @restoring.
  ///
  /// In zh, this message translates to:
  /// **'恢复中…'**
  String get restoring;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String operationFailed(Object error);

  /// No description provided for @lastBackup.
  ///
  /// In zh, this message translates to:
  /// **'上次备份：{time}'**
  String lastBackup(Object time);

  /// No description provided for @neverBackedUp.
  ///
  /// In zh, this message translates to:
  /// **'尚未进行过备份'**
  String get neverBackedUp;

  /// No description provided for @dataSummary.
  ///
  /// In zh, this message translates to:
  /// **'数据量：{books} 本书 · {notes} 条笔记'**
  String dataSummary(Object books, Object notes);

  /// No description provided for @timeDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天前'**
  String timeDaysAgo(Object days);

  /// No description provided for @timeMonthsAgo.
  ///
  /// In zh, this message translates to:
  /// **'{months} 个月前'**
  String timeMonthsAgo(Object months);

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认还原'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmWarning.
  ///
  /// In zh, this message translates to:
  /// **'此操作将覆盖当前所有数据。请确认该备份文件来源可信。'**
  String get restoreConfirmWarning;

  /// No description provided for @restoreConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'确认还原'**
  String get restoreConfirmAction;

  /// No description provided for @restoreStatVersion.
  ///
  /// In zh, this message translates to:
  /// **'备份版本'**
  String get restoreStatVersion;

  /// No description provided for @restoreStatExportedAt.
  ///
  /// In zh, this message translates to:
  /// **'导出时间'**
  String get restoreStatExportedAt;

  /// No description provided for @restoreStatBooks.
  ///
  /// In zh, this message translates to:
  /// **'书籍'**
  String get restoreStatBooks;

  /// No description provided for @restoreStatNotes.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get restoreStatNotes;

  /// No description provided for @restoreStatBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get restoreStatBookmarks;

  /// No description provided for @restoreStatVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'生词'**
  String get restoreStatVocabulary;

  /// No description provided for @allBooks.
  ///
  /// In zh, this message translates to:
  /// **'全部书籍'**
  String get allBooks;

  /// No description provided for @allWordLists.
  ///
  /// In zh, this message translates to:
  /// **'全部词库'**
  String get allWordLists;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @exportLearningData.
  ///
  /// In zh, this message translates to:
  /// **'导出学习数据'**
  String get exportLearningData;

  /// No description provided for @exportNotesMarkdownDesc.
  ///
  /// In zh, this message translates to:
  /// **'导出所有笔记为 Markdown 文档'**
  String get exportNotesMarkdownDesc;

  /// No description provided for @exportVocabCsvDesc.
  ///
  /// In zh, this message translates to:
  /// **'导出所有生词为表格文件'**
  String get exportVocabCsvDesc;

  /// No description provided for @goReading.
  ///
  /// In zh, this message translates to:
  /// **'去阅读'**
  String get goReading;

  /// No description provided for @noNotes.
  ///
  /// In zh, this message translates to:
  /// **'暂无笔记'**
  String get noNotes;

  /// No description provided for @noteEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'在阅读中做笔记后，它们会出现在这里'**
  String get noteEmptyHint;

  /// No description provided for @notebook.
  ///
  /// In zh, this message translates to:
  /// **'笔记本'**
  String get notebook;

  /// No description provided for @notesMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'笔记 (Markdown)'**
  String get notesMarkdown;

  /// No description provided for @totalVocabCount.
  ///
  /// In zh, this message translates to:
  /// **'生词总数'**
  String get totalVocabCount;

  /// No description provided for @vocabEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'在阅读中添加生词后，它们会出现在这里'**
  String get vocabEmptyHint;

  /// No description provided for @vocabListCsv.
  ///
  /// In zh, this message translates to:
  /// **'生词表 (CSV)'**
  String get vocabListCsv;

  /// No description provided for @wordListCet4.
  ///
  /// In zh, this message translates to:
  /// **'CET-4'**
  String get wordListCet4;

  /// No description provided for @wordListCet6.
  ///
  /// In zh, this message translates to:
  /// **'CET-6'**
  String get wordListCet6;

  /// No description provided for @wordListIelts.
  ///
  /// In zh, this message translates to:
  /// **'IELTS'**
  String get wordListIelts;

  /// No description provided for @wordListToefl.
  ///
  /// In zh, this message translates to:
  /// **'TOEFL'**
  String get wordListToefl;

  /// No description provided for @confirmDeleteWord.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除「{word}」吗？'**
  String confirmDeleteWord(Object word);

  /// No description provided for @vocabPageEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'去阅读时点击单词即可加入生词本'**
  String get vocabPageEmptyHint;

  /// No description provided for @vocabFilterEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'没有符合条件的生词'**
  String get vocabFilterEmptyHint;

  /// No description provided for @vocabStatsAll.
  ///
  /// In zh, this message translates to:
  /// **'全部 {count}'**
  String vocabStatsAll(Object count);

  /// No description provided for @vocabStatsUnstarted.
  ///
  /// In zh, this message translates to:
  /// **'未学 {count}'**
  String vocabStatsUnstarted(Object count);

  /// No description provided for @vocabStatsLearning.
  ///
  /// In zh, this message translates to:
  /// **'学习中 {count}'**
  String vocabStatsLearning(Object count);

  /// No description provided for @vocabStatsMastered.
  ///
  /// In zh, this message translates to:
  /// **'已掌握 {count}'**
  String vocabStatsMastered(Object count);

  /// No description provided for @vocabStatsIgnored.
  ///
  /// In zh, this message translates to:
  /// **'已忽略 {count}'**
  String vocabStatsIgnored(Object count);

  /// No description provided for @secondsUnit.
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get secondsUnit;

  /// No description provided for @hoursUnit.
  ///
  /// In zh, this message translates to:
  /// **'小时'**
  String get hoursUnit;

  /// No description provided for @charsUnit.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get charsUnit;

  /// No description provided for @thousandCharsUnit.
  ///
  /// In zh, this message translates to:
  /// **'千'**
  String get thousandCharsUnit;

  /// No description provided for @livePreview.
  ///
  /// In zh, this message translates to:
  /// **'实时预览'**
  String get livePreview;

  /// No description provided for @fontSelection.
  ///
  /// In zh, this message translates to:
  /// **'字体选择'**
  String get fontSelection;

  /// No description provided for @typographyParams.
  ///
  /// In zh, this message translates to:
  /// **'排版参数'**
  String get typographyParams;

  /// No description provided for @advancedTypography.
  ///
  /// In zh, this message translates to:
  /// **'高级排版'**
  String get advancedTypography;

  /// No description provided for @cjkOptimization.
  ///
  /// In zh, this message translates to:
  /// **'CJK 优化'**
  String get cjkOptimization;

  /// No description provided for @punctuationSqueeze.
  ///
  /// In zh, this message translates to:
  /// **'标点挤压'**
  String get punctuationSqueeze;

  /// No description provided for @punctuationSqueezeDesc.
  ///
  /// In zh, this message translates to:
  /// **'减少中文标点符号周围的空白'**
  String get punctuationSqueezeDesc;

  /// No description provided for @baselineAlign.
  ///
  /// In zh, this message translates to:
  /// **'中西文基线对齐'**
  String get baselineAlign;

  /// No description provided for @baselineAlignDesc.
  ///
  /// In zh, this message translates to:
  /// **'强制统一行高，避免混排时文字跳动'**
  String get baselineAlignDesc;

  /// No description provided for @autoScroll.
  ///
  /// In zh, this message translates to:
  /// **'自动翻页'**
  String get autoScroll;

  /// No description provided for @autoScrollSpeed.
  ///
  /// In zh, this message translates to:
  /// **'翻页间隔'**
  String get autoScrollSpeed;

  /// No description provided for @verticalMode.
  ///
  /// In zh, this message translates to:
  /// **'竖排模式'**
  String get verticalMode;

  /// No description provided for @verticalModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'从右向左阅读，适合古籍排版'**
  String get verticalModeDesc;

  /// No description provided for @ttsPreviewStop.
  ///
  /// In zh, this message translates to:
  /// **'停止试听'**
  String get ttsPreviewStop;

  /// No description provided for @ttsPreviewPlay.
  ///
  /// In zh, this message translates to:
  /// **'试听当前配置'**
  String get ttsPreviewPlay;

  /// No description provided for @ttsAutoRefresh.
  ///
  /// In zh, this message translates to:
  /// **'修改后自动刷新'**
  String get ttsAutoRefresh;

  /// No description provided for @ttsVoiceEngine.
  ///
  /// In zh, this message translates to:
  /// **'语音引擎'**
  String get ttsVoiceEngine;

  /// No description provided for @ttsEngine.
  ///
  /// In zh, this message translates to:
  /// **'TTS 引擎'**
  String get ttsEngine;

  /// No description provided for @systemDefault.
  ///
  /// In zh, this message translates to:
  /// **'系统默认'**
  String get systemDefault;

  /// No description provided for @ttsEnglishVoice.
  ///
  /// In zh, this message translates to:
  /// **'英文语音'**
  String get ttsEnglishVoice;

  /// No description provided for @ttsChineseVoice.
  ///
  /// In zh, this message translates to:
  /// **'中文语音'**
  String get ttsChineseVoice;

  /// No description provided for @ttsPlaybackParams.
  ///
  /// In zh, this message translates to:
  /// **'播放参数'**
  String get ttsPlaybackParams;

  /// No description provided for @ttsPitch.
  ///
  /// In zh, this message translates to:
  /// **'音调'**
  String get ttsPitch;

  /// No description provided for @ttsPauseBetween.
  ///
  /// In zh, this message translates to:
  /// **'句间停顿'**
  String get ttsPauseBetween;

  /// No description provided for @ttsBilingualReading.
  ///
  /// In zh, this message translates to:
  /// **'双语朗读'**
  String get ttsBilingualReading;

  /// No description provided for @zephyrExclusive.
  ///
  /// In zh, this message translates to:
  /// **'Zephyr 专属'**
  String get zephyrExclusive;

  /// No description provided for @ttsBilingualAlternate.
  ///
  /// In zh, this message translates to:
  /// **'双语交替朗读'**
  String get ttsBilingualAlternate;

  /// No description provided for @ttsBilingualAlternateDesc.
  ///
  /// In zh, this message translates to:
  /// **'先读英文原文，再读中文译文'**
  String get ttsBilingualAlternateDesc;

  /// No description provided for @ttsOriginalOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅朗读原文'**
  String get ttsOriginalOnly;

  /// No description provided for @ttsOriginalOnlyDesc.
  ///
  /// In zh, this message translates to:
  /// **'跳过译文段落，适合听力训练'**
  String get ttsOriginalOnlyDesc;

  /// No description provided for @ttsSwitchInterval.
  ///
  /// In zh, this message translates to:
  /// **'中英切换间隔'**
  String get ttsSwitchInterval;

  /// No description provided for @ttsBehavior.
  ///
  /// In zh, this message translates to:
  /// **'行为偏好'**
  String get ttsBehavior;

  /// No description provided for @ttsBackgroundPlay.
  ///
  /// In zh, this message translates to:
  /// **'后台播放'**
  String get ttsBackgroundPlay;

  /// No description provided for @ttsBackgroundPlayDesc.
  ///
  /// In zh, this message translates to:
  /// **'切出应用或锁屏后继续朗读'**
  String get ttsBackgroundPlayDesc;

  /// No description provided for @ttsAutoPage.
  ///
  /// In zh, this message translates to:
  /// **'自动翻页'**
  String get ttsAutoPage;

  /// No description provided for @ttsAutoPageDesc.
  ///
  /// In zh, this message translates to:
  /// **'读完当前章节自动跳转下一章'**
  String get ttsAutoPageDesc;

  /// No description provided for @ttsHighlightFollow.
  ///
  /// In zh, this message translates to:
  /// **'高亮跟随'**
  String get ttsHighlightFollow;

  /// No description provided for @ttsHighlightFollowDesc.
  ///
  /// In zh, this message translates to:
  /// **'朗读时实时高亮当前句子'**
  String get ttsHighlightFollowDesc;

  /// No description provided for @ttsDimOnLock.
  ///
  /// In zh, this message translates to:
  /// **'息屏时降低音量'**
  String get ttsDimOnLock;

  /// No description provided for @ttsDimOnLockDesc.
  ///
  /// In zh, this message translates to:
  /// **'节省电量，适合睡前听书'**
  String get ttsDimOnLockDesc;

  /// No description provided for @otherBehavior.
  ///
  /// In zh, this message translates to:
  /// **'应用行为'**
  String get otherBehavior;

  /// No description provided for @languageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'简体中文 / English'**
  String get languageSubtitle;

  /// No description provided for @otherNotifications.
  ///
  /// In zh, this message translates to:
  /// **'通知与提醒'**
  String get otherNotifications;

  /// No description provided for @otherNotificationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'阅读目标提醒、同步完成通知'**
  String get otherNotificationsDesc;

  /// No description provided for @otherStartupCheck.
  ///
  /// In zh, this message translates to:
  /// **'启动时检查更新'**
  String get otherStartupCheck;

  /// No description provided for @otherStartupCheckDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅前台启动时检测新版本'**
  String get otherStartupCheckDesc;

  /// No description provided for @otherExperimental.
  ///
  /// In zh, this message translates to:
  /// **'实验性功能'**
  String get otherExperimental;

  /// No description provided for @otherMarkdownPreview.
  ///
  /// In zh, this message translates to:
  /// **'Markdown 笔记预览'**
  String get otherMarkdownPreview;

  /// No description provided for @otherMarkdownPreviewDesc.
  ///
  /// In zh, this message translates to:
  /// **'在笔记列表中渲染 Markdown 格式'**
  String get otherMarkdownPreviewDesc;

  /// No description provided for @otherLegal.
  ///
  /// In zh, this message translates to:
  /// **'法律与合规'**
  String get otherLegal;

  /// No description provided for @openSourceLicenseDesc.
  ///
  /// In zh, this message translates to:
  /// **'Flutter / Rust / 第三方库许可'**
  String get openSourceLicenseDesc;

  /// No description provided for @resetAllSettings.
  ///
  /// In zh, this message translates to:
  /// **'重置所有设置'**
  String get resetAllSettings;

  /// No description provided for @resetAllSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认排版、主题、同步配置'**
  String get resetAllSettingsDesc;

  /// No description provided for @clearAllData.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get clearAllData;

  /// No description provided for @clearAllDataDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除阅读缓存和临时文件，不影响个人数据'**
  String get clearAllDataDesc;

  /// No description provided for @confirmReset.
  ///
  /// In zh, this message translates to:
  /// **'确认重置'**
  String get confirmReset;

  /// No description provided for @confirmResetContent.
  ///
  /// In zh, this message translates to:
  /// **'此操作将恢复排版、主题、同步配置等所有设置为默认值。\n\n不会删除书籍、笔记和生词数据。'**
  String get confirmResetContent;

  /// No description provided for @clearAllDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'清理缓存'**
  String get clearAllDataTitle;

  /// No description provided for @clearAllDataContent.
  ///
  /// In zh, this message translates to:
  /// **'此操作将清除阅读缓存和临时文件。\n\n不会删除书籍、笔记和生词数据。'**
  String get clearAllDataContent;

  /// No description provided for @confirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get confirmClear;

  /// No description provided for @translationApi.
  ///
  /// In zh, this message translates to:
  /// **'翻译 API'**
  String get translationApi;

  /// No description provided for @translationProvider.
  ///
  /// In zh, this message translates to:
  /// **'翻译服务'**
  String get translationProvider;

  /// No description provided for @translationApiUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 地址'**
  String get translationApiUrl;

  /// No description provided for @translationApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥'**
  String get translationApiKey;

  /// No description provided for @translationModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get translationModel;

  /// No description provided for @translationSourceLang.
  ///
  /// In zh, this message translates to:
  /// **'源语言'**
  String get translationSourceLang;

  /// No description provided for @translationTargetLang.
  ///
  /// In zh, this message translates to:
  /// **'目标语言'**
  String get translationTargetLang;

  /// No description provided for @translationAutoDetect.
  ///
  /// In zh, this message translates to:
  /// **'自动检测'**
  String get translationAutoDetect;

  /// No description provided for @translationTimeout.
  ///
  /// In zh, this message translates to:
  /// **'超时（秒）'**
  String get translationTimeout;

  /// No description provided for @translationTest.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get translationTest;

  /// No description provided for @translationTranslateWithApi.
  ///
  /// In zh, this message translates to:
  /// **'使用API翻译'**
  String get translationTranslateWithApi;

  /// No description provided for @translationTestSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接测试成功'**
  String get translationTestSuccess;

  /// No description provided for @translationTestFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接测试失败：{error}'**
  String translationTestFailed(Object error);

  /// No description provided for @translationApiNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置翻译 API'**
  String get translationApiNotConfigured;

  /// No description provided for @translating.
  ///
  /// In zh, this message translates to:
  /// **'正在翻译…'**
  String get translating;

  /// No description provided for @translationFailed.
  ///
  /// In zh, this message translates to:
  /// **'翻译失败：{error}'**
  String translationFailed(Object error);

  /// No description provided for @translationRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get translationRetry;

  /// No description provided for @translationManualPaste.
  ///
  /// In zh, this message translates to:
  /// **'手动粘贴'**
  String get translationManualPaste;

  /// No description provided for @readingMode.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get readingMode;

  /// No description provided for @themeSwitch.
  ///
  /// In zh, this message translates to:
  /// **'主题切换'**
  String get themeSwitch;

  /// No description provided for @bookmarkManage.
  ///
  /// In zh, this message translates to:
  /// **'书签管理'**
  String get bookmarkManage;

  /// No description provided for @searchBookmarkHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索书签...'**
  String get searchBookmarkHint;

  /// No description provided for @clearAll.
  ///
  /// In zh, this message translates to:
  /// **'清空所有'**
  String get clearAll;

  /// No description provided for @deleteSelected.
  ///
  /// In zh, this message translates to:
  /// **'删除选中'**
  String get deleteSelected;

  /// No description provided for @sortByTime.
  ///
  /// In zh, this message translates to:
  /// **'按时间排序'**
  String get sortByTime;

  /// No description provided for @sortByChapter.
  ///
  /// In zh, this message translates to:
  /// **'按章节排序'**
  String get sortByChapter;

  /// No description provided for @sortByPosition.
  ///
  /// In zh, this message translates to:
  /// **'按位置排序'**
  String get sortByPosition;

  /// 书签总数统计
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个书签'**
  String totalBookmarks(int count);

  /// 本书书签总数
  ///
  /// In zh, this message translates to:
  /// **'本书总计 {count} 个'**
  String bookTotalBookmarks(int count);

  /// No description provided for @reload.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get reload;

  /// No description provided for @noBookmarksFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关书签'**
  String get noBookmarksFound;

  /// No description provided for @addBookmarkHint.
  ///
  /// In zh, this message translates to:
  /// **'阅读时点击右上角添加书签'**
  String get addBookmarkHint;

  /// No description provided for @deleteBookmark.
  ///
  /// In zh, this message translates to:
  /// **'删除书签'**
  String get deleteBookmark;

  /// 确认删除单个书签
  ///
  /// In zh, this message translates to:
  /// **'确定要删除\"{title}\"吗？'**
  String confirmDeleteBookmark(String title);

  /// No description provided for @confirmDeleteBookmarkSimple.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除此书签吗？'**
  String get confirmDeleteBookmarkSimple;

  /// No description provided for @batchDelete.
  ///
  /// In zh, this message translates to:
  /// **'批量删除'**
  String get batchDelete;

  /// 确认批量删除书签
  ///
  /// In zh, this message translates to:
  /// **'确定要删除选中的 {count} 个书签吗？'**
  String confirmBatchDelete(int count);

  /// 删除书签成功提示
  ///
  /// In zh, this message translates to:
  /// **'已删除 {count} 个书签'**
  String deletedBookmarks(int count);

  /// No description provided for @clearAllBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'清空书签'**
  String get clearAllBookmarks;

  /// No description provided for @confirmAddBookmark.
  ///
  /// In zh, this message translates to:
  /// **'确定要在这里添加书签吗？'**
  String get confirmAddBookmark;

  /// No description provided for @bookmarkAdded.
  ///
  /// In zh, this message translates to:
  /// **'书签已添加'**
  String get bookmarkAdded;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @bookmarkDeleted.
  ///
  /// In zh, this message translates to:
  /// **'书签已删除'**
  String get bookmarkDeleted;

  /// No description provided for @jumpTo.
  ///
  /// In zh, this message translates to:
  /// **'跳转'**
  String get jumpTo;

  /// No description provided for @charOffset.
  ///
  /// In zh, this message translates to:
  /// **'偏移'**
  String get charOffset;

  /// No description provided for @notesAndHighlights.
  ///
  /// In zh, this message translates to:
  /// **'笔记与标注'**
  String get notesAndHighlights;

  /// No description provided for @refreshTooltip.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refreshTooltip;

  /// No description provided for @confirmClearAllBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空本书的所有书签吗？此操作不可恢复'**
  String get confirmClearAllBookmarks;

  /// No description provided for @cacheManage.
  ///
  /// In zh, this message translates to:
  /// **'缓存管理'**
  String get cacheManage;

  /// 清除阅读进度提示
  ///
  /// In zh, this message translates to:
  /// **'已清除《{title}》阅读进度'**
  String clearedProgress(String title);

  /// No description provided for @noProgressData.
  ///
  /// In zh, this message translates to:
  /// **'暂无阅读进度数据'**
  String get noProgressData;

  /// No description provided for @cacheInfoTip.
  ///
  /// In zh, this message translates to:
  /// **'缓存包含已加载的章节内容。清空后需重新加载，不影响书籍文件和阅读进度'**
  String get cacheInfoTip;

  /// No description provided for @bookCount.
  ///
  /// In zh, this message translates to:
  /// **'书籍数'**
  String get bookCount;

  /// No description provided for @withProgress.
  ///
  /// In zh, this message translates to:
  /// **'有进度'**
  String get withProgress;

  /// No description provided for @labelTotalChapters.
  ///
  /// In zh, this message translates to:
  /// **'总章节'**
  String get labelTotalChapters;

  /// No description provided for @indexLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'索引加载失败'**
  String get indexLoadFailed;

  /// No description provided for @indexChunks.
  ///
  /// In zh, this message translates to:
  /// **'索引块'**
  String get indexChunks;

  /// No description provided for @indexBooks.
  ///
  /// In zh, this message translates to:
  /// **'索引书籍'**
  String get indexBooks;

  /// No description provided for @indexChapters.
  ///
  /// In zh, this message translates to:
  /// **'索引章节'**
  String get indexChapters;

  /// No description provided for @clearProgress.
  ///
  /// In zh, this message translates to:
  /// **'清除进度'**
  String get clearProgress;

  /// No description provided for @clearedAllBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'已清空所有书签'**
  String get clearedAllBookmarks;

  /// No description provided for @themePreviewSampleText.
  ///
  /// In zh, this message translates to:
  /// **'春风又绿江南岸，明月何时照我还。'**
  String get themePreviewSampleText;

  /// No description provided for @textAlign.
  ///
  /// In zh, this message translates to:
  /// **'文字对齐'**
  String get textAlign;

  /// No description provided for @textAlignJustify.
  ///
  /// In zh, this message translates to:
  /// **'两端对齐'**
  String get textAlignJustify;

  /// No description provided for @textAlignStart.
  ///
  /// In zh, this message translates to:
  /// **'左对齐'**
  String get textAlignStart;

  /// No description provided for @textAlignCenter.
  ///
  /// In zh, this message translates to:
  /// **'居中'**
  String get textAlignCenter;

  /// No description provided for @textAlignEnd.
  ///
  /// In zh, this message translates to:
  /// **'右对齐'**
  String get textAlignEnd;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
