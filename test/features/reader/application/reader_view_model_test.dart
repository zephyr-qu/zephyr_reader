// test/features/reader/application/reader_view_model_test.dart
//
// 覆盖 P2.3 — ReaderViewModel 翻页逻辑
//
// ReaderViewModel 是 @lazySingleton，内部创建 ChapterManager（已单独测试）。
// 此处测试 ViewModel 层对 ChapterManager 的委托和信号传播是否正确。

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_flutter/signals_flutter.dart' hide PersistedSignal;
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/annotations/application/annotation_view_model.dart';
import 'package:zephyr_reader/features/reader/annotations/application/bookmark_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/reading_session_manager.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/translation/application/translation_config.dart';
import 'package:zephyr_reader/features/reader/translation/application/translation_view_model.dart';
import 'package:zephyr_reader/features/reader/translation/domain/translation_service.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

// ===== Mocks =====

class _MockRepo extends Mock implements ReaderRepository {}

class _MockTranslationConfig extends Mock implements TranslationConfig {
  @override
  bool get isConfigured => false;
}

class _MockTranslationService extends Mock implements TranslationService {}

class _MockSharedPreferences extends Mock implements PreferencesService {
  _MockSharedPreferences() {
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => setString(any(), any())).thenAnswer((_) async => true);
    when(() => remove(any())).thenAnswer((_) async => true);
  }
}

class _TestConfig implements ReaderConfig {
  @override
  final PreferencesService prefs = _MockSharedPreferences();

  @override
  late final theme = persistedEnum<ReaderTheme>(
    prefs,
    '',
    ReaderTheme.light,
    ReaderTheme.fromId,
    debounce: Duration.zero,
  );
  @override
  late final fontSize = persistedDouble(
    prefs,
    '',
    16.0,
    debounce: Duration.zero,
  );
  @override
  late final lineHeight = persistedDouble(
    prefs,
    '',
    1.6,
    debounce: Duration.zero,
  );
  @override
  late final paragraphSpacing = persistedDouble(
    prefs,
    '',
    16.0,
    debounce: Duration.zero,
  );
  @override
  late final padding = persistedDouble(
    prefs,
    '',
    16.0,
    debounce: Duration.zero,
  );
  @override
  late final readerBgColorIndex = persistedInt(
    prefs,
    '',
    0,
    debounce: Duration.zero,
  );
  @override
  late final autoScroll = persistedBool(
    prefs,
    '',
    false,
    debounce: Duration.zero,
  );
  @override
  late final autoScrollSpeed = persistedInt(
    prefs,
    '',
    30,
    debounce: Duration.zero,
  );
  @override
  late final letterSpacing = persistedDouble(
    prefs,
    '',
    0.0,
    debounce: Duration.zero,
  );
  @override
  late final punctuationSqueeze = persistedBool(
    prefs,
    '',
    true,
    debounce: Duration.zero,
  );
  @override
  late final baselineAlign = persistedBool(
    prefs,
    '',
    true,
    debounce: Duration.zero,
  );
  @override
  late final tapLayout = persistedEnum<TapLayout>(
    prefs,
    '',
    TapLayout.rightHanded,
    (name) => TapLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TapLayout.rightHanded,
    ),
    debounce: Duration.zero,
  );
  @override
  final brightnessOverlay = signal<double>(0.0);
  @override
  late final followSystemFontScale = persistedBool(
    prefs,
    '',
    false,
    debounce: Duration.zero,
  );
  @override
  Future<void> resetToDefault() async {}
  @override
  void dispose() {}

  @override
  late final firstLineIndent = persistedBool(
    prefs,
    '',
    false,
    debounce: Duration.zero,
  );
  @override
  late final language = persistedEnum<LanguageType>(
    prefs,
    '',
    LanguageType.mixed,
    (name) => LanguageType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LanguageType.mixed,
    ),
    debounce: Duration.zero,
  );
  @override
  late final autoSpaceRatio = persistedDouble(
    prefs,
    '',
    0.5,
    debounce: Duration.zero,
  );
  @override
  late final textAlign = persistedEnum<TextAlign>(
    prefs,
    '',
    TextAlign.start,
    (name) => TextAlign.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TextAlign.start,
    ),
    debounce: Duration.zero,
  );
  @override
  late final paginationSkin = persistedEnum<PaginationSkin>(
    prefs,
    '',
    PaginationSkin.slide,
    (name) => PaginationSkin.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PaginationSkin.slide,
    ),
    debounce: Duration.zero,
  );
}

ReaderViewModel createVm({
  required ReaderRepository repo,
  required ReaderConfig config,
}) {
  return ReaderViewModel(repo: repo, config: config);
}

void main() {
  late ReaderViewModel vm;

  setUp(() {
    GetIt.I.reset();
    // Mock translation deps for TranslationViewModel's getIt fallback
    GetIt.I.registerFactory<TranslationConfig>(() => _MockTranslationConfig());
    GetIt.I.registerFactory<TranslationService>(
      () => _MockTranslationService(),
    );
    // Register sub-VMs as factoryParam for DI
    GetIt.I.registerFactoryParam<
      ChapterViewModel,
      ReaderRepositoryInterface,
      ReaderConfig
    >((repo, config) => ChapterViewModel(repo, config));
    GetIt.I.registerFactoryParam<ReadingSessionManager, ChapterViewModel, void>(
      (vm, _) => ReadingSessionManager(vm as ChapterViewModel),
    );
    GetIt.I.registerFactoryParam<BookmarkViewModel, ChapterViewModel, void>(
      (vm, _) => BookmarkViewModel(vm as ChapterViewModel),
    );
    GetIt.I.registerFactoryParam<AnnotationViewModel, ChapterViewModel, void>(
      (vm, _) => AnnotationViewModel(vm as ChapterViewModel),
    );
    GetIt.I.registerFactoryParam<TranslationViewModel, ChapterViewModel, void>(
      (vm, _) => TranslationViewModel(vm as ChapterViewModel),
    );
  });
  setUp(() {
    final repo = _MockRepo();
    final config = _TestConfig();
    vm = createVm(repo: repo, config: config);
  });

  group('ReaderViewModel pagination', () {
    test('previousPage 在第 0 页时不变', () async {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 0;

      await vm.chapterManager.previousPage();
      expect(vm.chapterManager.pageIndex.value, equals(0));
    });

    test('nextPage 从第 0 页到第 1 页', () async {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 0;

      await vm.chapterManager.nextPage();
      expect(vm.chapterManager.pageIndex.value, equals(1));
    });

    test('nextPage 边界：最后一页时不变', () async {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 2;

      await vm.chapterManager.nextPage();
      expect(vm.chapterManager.pageIndex.value, equals(2));
    });

    test('loadPage 边界：超出范围不改变', () async {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 0;

      await vm.loadPage(-1);
      expect(vm.chapterManager.pageIndex.value, equals(0));
    });

    test('setReadingMode 更新 readingMode 信号', () {
      expect(vm.readingMode.value, equals(ReadingMode.pagination));

      vm.setReadingMode(ReadingMode.scroll);
      expect(vm.readingMode.value, equals(ReadingMode.scroll));

      vm.setReadingMode(ReadingMode.pagination);
      vm.config.paginationSkin.value = PaginationSkin.curl;
      expect(vm.readingMode.value, equals(ReadingMode.pagination));
      expect(vm.config.paginationSkin.value, equals(PaginationSkin.curl));
    });
  });
}
