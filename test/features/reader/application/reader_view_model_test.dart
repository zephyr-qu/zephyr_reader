// test/features/reader/application/reader_view_model_test.dart
//
// 覆盖 P2.3 — ReaderViewModel 翻页逻辑
//
// ReaderViewModel 是 @lazySingleton，内部创建 ChapterManager（已单独测试）。
// 此处测试 ViewModel 层对 ChapterManager 的委托和信号传播是否正确。

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/domain/translation_service.dart';

// ===== Mocks =====

class _MockRepo extends Mock implements ReaderRepository {}

class _MockTranslationService extends Mock implements TranslationService {}

class _MockSharedPreferences extends Mock implements SharedPreferences {
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
  final SharedPreferences prefs = _MockSharedPreferences();

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
  final writingDirection = signal<WritingDirection>(
    WritingDirection.horizontal,
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
  double get pageMargin => padding.value;
  @override
  Future<void> resetToDefault() async {}
  @override
  void dispose() {}
}

ReaderViewModel createVm({
  required ReaderRepository repo,
  required ReaderConfig config,
}) {
  final translatePrefs = _MockSharedPreferences();
  final translateConfig = TranslationConfig(translatePrefs);
  final translateService = _MockTranslationService();
  return ReaderViewModel(repo, config, translateConfig, translateService);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReaderViewModel vm;

  setUp(() {
    final repo = _MockRepo();
    final config = _TestConfig();
    vm = createVm(repo: repo, config: config);
  });

  group('ReaderViewModel pagination', () {
    test('previousPage 在第 0 页时不变', () {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 0;

      vm.previousPage();
      expect(vm.pageIndex.value, equals(0));
    });

    test('nextPage 从第 0 页到第 1 页', () {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 0;

      vm.nextPage();
      expect(vm.pageIndex.value, equals(1));
    });

    test('nextPage 边界：最后一页时不变', () {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 2;

      vm.nextPage();
      expect(vm.pageIndex.value, equals(2));
    });

    test('loadPage 边界：超出范围不改变', () async {
      vm.chapterManager.totalPages.value = 3;
      vm.chapterManager.pageIndex.value = 0;

      await vm.loadPage(-1);
      expect(vm.pageIndex.value, equals(0));
    });

    test('setReadingMode 更新 readingMode 信号', () {
      expect(vm.readingMode.value, equals(ReadingMode.pagination));

      vm.setReadingMode(ReadingMode.scroll);
      expect(vm.readingMode.value, equals(ReadingMode.scroll));

      vm.setReadingMode(ReadingMode.pageTurn);
      expect(vm.readingMode.value, equals(ReadingMode.pageTurn));
    });
  });
}
