// test/features/reader/core/application/pagination_coordinator_test.dart
//
// 验证 PaginationCoordinator 纯逻辑：参数构建、有效性判断、页码解析。
// FFI 调用（computeConfigHash、beginPaginate 等）不在本测试范围内。

import 'dart:ui' show TextAlign;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

// ===== Mocks =====

class _MockRepo extends Mock implements ReaderRepositoryInterface {}

class _MockPrefs extends Mock implements PreferencesService {
  _MockPrefs() {
    when(
      () => getDouble(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (invocation) => invocation.namedArguments[#defaultValue] as double,
    );
    when(
      () => getInt(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (invocation) => invocation.namedArguments[#defaultValue] as int,
    );
    when(
      () => getBool(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (invocation) => invocation.namedArguments[#defaultValue] as bool,
    );
    when(() => getString(any())).thenReturn(null);
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => setString(any(), any())).thenAnswer((_) async => true);
    when(() => remove(any())).thenAnswer((_) async => true);
  }
}

class _MockConfig implements ReaderConfig {
  @override
  final PreferencesService prefs = _MockPrefs();

  @override
  late final fontSize = persistedDouble(prefs, '', 16.0);

  @override
  late final lineHeight = persistedDouble(prefs, '', 1.6);

  @override
  late final padding = persistedDouble(
    prefs,
    '',
    ReaderTypographyDefaults.padding,
  );

  @override
  late final letterSpacing = persistedDouble(prefs, '', 0.0);

  @override
  late final paragraphSpacing = persistedDouble(
    prefs,
    '',
    ReaderTypographyDefaults.paragraphSpacing,
  );

  @override
  late final punctuationSqueeze = persistedBool(prefs, '', true);

  @override
  late final firstLineIndent = persistedBool(prefs, '', true);

  // Remaining fields — not needed for these tests, but required by interface.
  @override
  late final theme = persistedEnum<ReaderTheme>(
    prefs,
    '',
    ReaderTheme.light,
    ReaderTheme.fromId,
  );
  @override
  late final readerBgColorIndex = persistedInt(prefs, '', 0);
  @override
  late final autoScroll = persistedBool(prefs, '', false);
  @override
  late final autoScrollSpeed = persistedInt(prefs, '', 30);
  @override
  late final baselineAlign = persistedBool(prefs, '', true);
  @override
  late final language = persistedEnum<LanguageType>(
    prefs,
    '',
    LanguageType.auto,
    (name) => LanguageType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LanguageType.auto,
    ),
  );
  @override
  late final autoSpaceRatio = persistedDouble(prefs, '', 0.25);
  @override
  late final textAlign = persistedEnum(
    prefs,
    '',
    TextAlign.justify,
    (name) => TextAlign.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TextAlign.justify,
    ),
  );
  @override
  late final paginationSkin = persistedEnum(
    prefs,
    '',
    PaginationSkin.slide,
    (name) => PaginationSkin.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PaginationSkin.slide,
    ),
  );
  @override
  late final tapLayout = persistedEnum(
    prefs,
    '',
    TapLayout.rightHanded,
    (name) => TapLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TapLayout.rightHanded,
    ),
  );
  @override
  late final followSystemFontScale = persistedBool(prefs, '', false);
  @override
  final brightnessOverlay = signal<double>(0.0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test descriptors
const _descriptors3 = [
  PackedPage(
    pageIndex: 0,
    startOffset: 0,
    endOffset: 99,
    slices: [],
    isLastPage: false,
  ),
  PackedPage(
    pageIndex: 1,
    startOffset: 100,
    endOffset: 199,
    slices: [],
    isLastPage: false,
  ),
  PackedPage(
    pageIndex: 2,
    startOffset: 200,
    endOffset: 300,
    slices: [],
    isLastPage: true,
  ),
];

void main() {
  late _MockRepo repo;
  late _MockConfig config;
  late ChapterViewModel chapterVM;

  setUp(() {
    repo = _MockRepo();
    config = _MockConfig();
    chapterVM = ChapterViewModel(repo, config);

    registerFallbackValue(
      const PaginationParams(
        fontSize: 16,
        lineHeight: 1.6,
        width: 400,
        height: 600,
        padding: 20,
      ),
    );
  });

  group('buildPaginationParams', () {
    test('reflects config signals and coordinator dimensions', () {
      final coordinator = PaginationCoordinator(repo, config, chapterVM);
      coordinator.pageWidth = 375;
      coordinator.pageHeight = 667;
      coordinator.devicePixelRatio = 2.0;
      coordinator.fontFamily = 'Source Han Sans';

      final params = coordinator.buildPaginationParams();

      expect(params.fontSize, 16.0);
      expect(params.lineHeight, 1.6);
      expect(params.width, 375);
      expect(params.height, 667);
      expect(params.padding, ReaderTypographyDefaults.padding);
      expect(params.devicePixelRatio, 2.0);
      expect(params.fontFamily, 'Source Han Sans');
      expect(params.letterSpacing, 0.0);
      expect(
        params.paragraphSpacing,
        ReaderTypographyDefaults.paragraphSpacing,
      );
      expect(params.punctuationSqueeze, true);
      expect(params.firstLineIndent, true);
    });

    test(
      'does not clamp when pageHeight is small (clamp preserves min=max)',
      () {
        final coordinator = PaginationCoordinator(repo, config, chapterVM);
        coordinator.pageHeight = 120;

        final params = coordinator.buildPaginationParams();
        expect(params.height, 120);
      },
    );
  });

  group('isPaginationValid', () {
    test('returns true when total > 0 and descriptors non-empty', () {
      when(() => repo.descriptors).thenReturn(_descriptors3);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      expect(coordinator.isPaginationValid(3), isTrue);
    });

    test('returns false when total is 0', () {
      when(() => repo.descriptors).thenReturn(_descriptors3);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      expect(coordinator.isPaginationValid(0), isFalse);
    });

    test('returns false when descriptors is null', () {
      when(() => repo.descriptors).thenReturn(null);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      expect(coordinator.isPaginationValid(3), isFalse);
    });

    test('returns false when descriptors is empty', () {
      when(() => repo.descriptors).thenReturn([]);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      expect(coordinator.isPaginationValid(3), isFalse);
    });
  });

  group('resolvePageForCharOffset', () {
    test('returns session result when repo resolves successfully', () {
      when(() => repo.resolvePageIndexForCharOffset(any())).thenReturn(1);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      final result = coordinator.resolvePageForCharOffset(150, _descriptors3);
      expect(result, 1);
    });

    test('clamps session result to descriptor range', () {
      when(() => repo.resolvePageIndexForCharOffset(any())).thenReturn(10);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      final result = coordinator.resolvePageForCharOffset(150, _descriptors3);
      // 10 clamped to max descriptor index = 2
      expect(result, 2);
    });

    test('falls back to binary search when session returns null', () {
      when(() => repo.resolvePageIndexForCharOffset(any())).thenReturn(null);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      // charOffset 150 falls in page 1 (100..199)
      final result = coordinator.resolvePageForCharOffset(150, _descriptors3);
      expect(result, 1);
    });

    test('binary search returns 0 for offset before first page', () {
      when(() => repo.resolvePageIndexForCharOffset(any())).thenReturn(null);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      final result = coordinator.resolvePageForCharOffset(-5, _descriptors3);
      expect(result, 0);
    });

    test('binary search returns last page for offset beyond range', () {
      when(() => repo.resolvePageIndexForCharOffset(any())).thenReturn(null);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      final result = coordinator.resolvePageForCharOffset(500, _descriptors3);
      expect(result, 2);
    });
  });

  group('applyFullResult', () {
    test('maps totalPages and resolves pageIndex from charOffset', () {
      when(() => repo.descriptors).thenReturn(_descriptors3);
      when(() => repo.sessionMode).thenReturn(ChapterPaginationMode.plainText);
      when(() => repo.resolvePageIndexForCharOffset(any())).thenReturn(null);
      when(() => repo.ensurePageWindow(any())).thenReturn(null);
      final coordinator = PaginationCoordinator(repo, config, chapterVM);

      final result = coordinator.applyFullResult(
        total: 3,
        initialCharOffset: 150,
        content: 'A'.padRight(301),
      );

      expect(result.totalPages, 3);
      // 150 → page 1 via binary search
      expect(result.pageIndex, 1);
    });
  });

  group('storeLineBreaks', () {
    test('handles empty text gracefully', () async {
      final coordinator = PaginationCoordinator(repo, config, chapterVM);
      // Should not throw or FFI-call for empty content
      await coordinator.storeLineBreaks('');
      // No crash — FFI error is caught by try/catch
    });

    test(
      'I_phase6: storeLineBreaks handles non-empty text without crashing',
      () async {
        final coordinator = PaginationCoordinator(repo, config, chapterVM);
        // In unit tests, reader_api.storeLineBreaks will fail with
        // "flutter_rust_bridge has not been initialized" — this is
        // caught by the try/catch inside storeLineBreaks.
        // The test validates the method doesn't throw externally.
        await coordinator.storeLineBreaks('测试文本测试文本测试文本测试文本');
        // No crash — TextPainter extraction + FFI call wrapped in try/catch
      },
    );
  });
}
