import 'dart:async';
import 'dart:convert';
import 'dart:ui' show TextAlign;

// Readium test fixtures require non-const localized metadata constructors.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/epub/readium_view_model.dart';
import 'package:zephyr_reader/src/rust/domain/engine_positions/models.dart';
import 'package:zephyr_reader/src/rust/domain/progress/models.dart';

class _MockFlutterReadium extends Mock implements FlutterReadium {
  @override
  Stream<Locator> get onTextLocatorChanged => const Stream.empty();

  /// Captures [FlutterReadium.setDefaultPreferences] calls — open() presets
  /// the native layout mode (scroll vs pagination) before the view is created.
  final defaultPreferencesCalls = <EPUBPreferences>[];

  @override
  void setDefaultPreferences(EPUBPreferences preferences) {
    defaultPreferencesCalls.add(preferences);
  }
}

class _MockReaderConfig extends Mock implements ReaderConfig {}

class _MockTtsSettingsViewModel extends Mock implements TtsSettingsViewModel {}

class _MockPersistedSignal<T> extends Mock implements PersistedSignal<T> {}

class _FakeEpubPreferences extends Fake implements EPUBPreferences {}

_MockPersistedSignal<ReaderTextAlign> _stubAdvancedTypography(
  _MockReaderConfig config,
) {
  final lineHeight = _MockPersistedSignal<double>();
  when(() => lineHeight.value).thenReturn(1.4);
  when(() => config.lineHeight).thenReturn(lineHeight);

  final letterSpacing = _MockPersistedSignal<double>();
  when(() => letterSpacing.value).thenReturn(0.0);
  when(() => config.letterSpacing).thenReturn(letterSpacing);

  final paragraphSpacing = _MockPersistedSignal<double>();
  when(() => paragraphSpacing.value).thenReturn(0.0);
  when(() => config.paragraphSpacing).thenReturn(paragraphSpacing);

  final paragraphIndent = _MockPersistedSignal<double>();
  when(() => paragraphIndent.value).thenReturn(0.0);
  when(() => config.paragraphIndent).thenReturn(paragraphIndent);

  final textAlign = _MockPersistedSignal<ReaderTextAlign>();
  when(() => textAlign.value).thenReturn(ReaderTextAlign.auto);
  when(() => config.textAlign).thenReturn(textAlign);
  return textAlign;
}

Future<void> _mountViewport(ReadiumViewModel vm) async {
  await vm.onViewportReady();
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEpubPreferences());
    registerFallbackValue(const TTSPreferences());
    registerFallbackValue(
      const Locator(href: 'fallback.xhtml', type: 'application/xhtml+xml'),
    );
  });

  test('waits for the native viewport before applying preferences', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    final textAlign = _stubAdvancedTypography(config);
    final ttsSettings = _MockTtsSettingsViewModel();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    // Legacy Builtin configuration used 18dp. Readium interprets the same
    // numeric value as 18%, which renders the book as a tiny center column.
    when(() => fontSize.value).thenReturn(18.0);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(24.0);
    final fontFamily = _MockPersistedSignal<String>();
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    final bgIndex = _MockPersistedSignal<int>();
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    final fontWeight = _MockPersistedSignal<double>();
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.fontWeight).thenReturn(fontWeight);
    when(() => fontWeight.value).thenReturn(400.0);
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    final ttsSpeed = _MockPersistedSignal<double>();
    when(() => ttsSpeed.value).thenReturn(1.25);
    when(() => ttsSettings.speed).thenReturn(ttsSpeed);
    final ttsPitch = _MockPersistedSignal<double>();
    when(() => ttsPitch.value).thenReturn(0.9);
    when(() => ttsSettings.pitch).thenReturn(ttsPitch);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.goToLocator(any())).thenAnswer((_) async => true);
    when(() => reader.ttsEnable(any())).thenAnswer((_) async {});
    when(() => reader.play(null)).thenAnswer((_) async {});
    when(() => reader.ttsSetPreferences(any())).thenAnswer((_) async {});
    when(() => reader.stop()).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-1',
      ttsSettings: ttsSettings,
      reader: reader,
    );

    await vm.open('book.epub');

    expect(vm.status.value, 'opening...');
    verifyNever(() => reader.setEPUBPreferences(any()));

    await _mountViewport(vm);

    expect(vm.status.value, 'ready');
    await vm.onViewportReady();
    verify(() => reader.onReaderStatusChanged).called(1);
    final capturedPreferences =
        verify(() => reader.setEPUBPreferences(captureAny())).captured.single
            as EPUBPreferences;
    expect(capturedPreferences.fontSize, 1.0);
    expect(capturedPreferences.fontWeight, 1.0);
    expect(capturedPreferences.lineHeight, 1.4);
    expect(capturedPreferences.letterSpacing, 0.0);
    expect(capturedPreferences.paragraphSpacing, 0.0);
    expect(capturedPreferences.paragraphIndent, 0.0);
    expect(capturedPreferences.textAlign, isNull);
    expect(capturedPreferences.publisherStyles, isFalse);
    await vm.toggleTts();
    final capturedTtsPreferences =
        verify(() => reader.ttsEnable(captureAny())).captured.single
            as TTSPreferences;
    expect(capturedTtsPreferences.speed, 1.25);
    expect(capturedTtsPreferences.pitch, 0.9);
    verify(() => reader.play(null)).called(1);
    await vm.applyTtsPreferences();
    verify(() => reader.ttsSetPreferences(captureAny())).called(1);
    // ReaderConfig stores the legacy UI value where 20 is the default.
    // Readium expects a multiplier where 1.0 is the default margin.
    expect(capturedPreferences.pageMargins, 1.2);
    expect(capturedPreferences.scroll, isFalse);

    vm.onLocatorChanged(
      const Locator(
        href: 'chapter.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(progression: 0.42),
      ),
    );
    when(() => fontSize.value).thenReturn(120.0);
    when(() => textAlign.value).thenReturn(ReaderTextAlign.justify);
    expect(await vm.applyPreferences(), isTrue);
    final updatedPreferences =
        verify(() => reader.setEPUBPreferences(captureAny())).captured.last
            as EPUBPreferences;
    expect(updatedPreferences.textAlign, TextAlign.justify);
    verify(() => reader.goToLocator(any())).called(1);

    when(
      () => reader.setEPUBPreferences(any()),
    ).thenThrow(StateError('native preference apply failed'));
    expect(await vm.applyPreferences(), isFalse);
    expect(vm.status.value, 'error');

    await vm.setReadingMode(ReadingMode.scroll);
    expect(vm.readingMode.value, ReadingMode.scroll);
    expect(vm.status.value, 'applying preferences...');
    expect(reader.defaultPreferencesCalls.last.scroll, isTrue);
    // The full preferences are applied by the new native viewport's ready
    // handshake, not against the old pager that is being replaced.

    await vm.close();
    await vm.close();
    verify(() => reader.closePublication()).called(1);
    expect(vm.currentLocator, isNull);
  });

  test('closes a publication that finishes opening after page exit', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    _stubAdvancedTypography(config);
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    final openCompleter = Completer<Publication>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Late Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) => openCompleter.future);
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-2',
      reader: reader,
    );
    final openFuture = vm.open('late.epub');
    await untilCalled(() => reader.openPublication(any()));

    await vm.close();
    openCompleter.complete(publication);

    await expectLater(openFuture, throwsStateError);
    verify(() => reader.closePublication()).called(1);
    expect(vm.status.value, 'closed');
  });

  test('next page does not skip chapter when locator advances', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    _stubAdvancedTypography(config);
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );
    late ReadiumViewModel vm;

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    final fontFamily = _MockPersistedSignal<String>();
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    final bgIndex = _MockPersistedSignal<int>();
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    final fontWeight = _MockPersistedSignal<double>();
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.fontWeight).thenReturn(fontWeight);
    when(() => fontWeight.value).thenReturn(400.0);
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.goForward()).thenAnswer((_) async {
      scheduleMicrotask(
        () => vm.onLocatorChanged(
          const Locator(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
        ),
      );
    });
    vm = ReadiumViewModel(
      config: config,
      bookId: 'book-next-page',
      reader: reader,
    );
    await vm.open('book.epub');
    await _mountViewport(vm);

    await vm.goRight();

    verify(() => reader.goForward()).called(1);
  });

  test(
    'next page does not infer a chapter fallback from a missing locator event',
    () async {
      final reader = _MockFlutterReadium();
      final config = _MockReaderConfig();
      _stubAdvancedTypography(config);
      final theme = _MockPersistedSignal<ReaderTheme>();
      final fontSize = _MockPersistedSignal<double>();
      final padding = _MockPersistedSignal<double>();
      final publication = Publication(
        metadata: Metadata(
          localizedTitle: LocalizedString.fromString('Test Book'),
        ),
        readingOrder: [
          const Link(href: 'chapter-1.xhtml', type: 'application/xhtml+xml'),
          const Link(href: 'chapter-2.xhtml', type: 'application/xhtml+xml'),
        ],
      );

      when(() => config.theme).thenReturn(theme);
      when(() => theme.value).thenReturn(ReaderTheme.light);
      when(() => config.fontSize).thenReturn(fontSize);
      when(() => fontSize.value).thenReturn(100);
      when(() => config.padding).thenReturn(padding);
      when(() => padding.value).thenReturn(20);
      final fontFamily = _MockPersistedSignal<String>();
      when(() => config.fontFamily).thenReturn(fontFamily);
      when(() => fontFamily.value).thenReturn('System');
      final bgIndex = _MockPersistedSignal<int>();
      when(() => config.readerBgColorIndex).thenReturn(bgIndex);
      when(() => bgIndex.value).thenReturn(0);
      final fontWeight = _MockPersistedSignal<double>();
      final readingMode = _MockPersistedSignal<ReadingMode>();
      when(() => config.fontWeight).thenReturn(fontWeight);
      when(() => fontWeight.value).thenReturn(400.0);
      when(() => config.readingMode).thenReturn(readingMode);
      when(() => readingMode.value).thenReturn(ReadingMode.pagination);
      when(
        () => reader.openPublication(any()),
      ).thenAnswer((_) async => publication);
      when(
        () => reader.onReaderStatusChanged,
      ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
      when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
      when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
      when(() => reader.goForward()).thenAnswer((_) async {});

      final vm = ReadiumViewModel(
        config: config,
        bookId: 'book-next-chapter',
        reader: reader,
      );
      await vm.open('book.epub');
      await _mountViewport(vm);

      await vm.goRight();

      verify(() => reader.goForward()).called(1);
    },
  );

  test('open presets default preferences matching the reading mode', () async {
    Future<void> runCase(ReadingMode mode, bool expectScroll) async {
      final reader = _MockFlutterReadium();
      final config = _MockReaderConfig();
      final readingMode = _MockPersistedSignal<ReadingMode>();
      when(() => config.readingMode).thenReturn(readingMode);
      when(() => readingMode.value).thenReturn(mode);
      final publication = Publication(
        metadata: Metadata(
          localizedTitle: LocalizedString.fromString('Prefs Book'),
        ),
        readingOrder: const [
          Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
        ],
      );
      when(
        () => reader.openPublication(any()),
      ).thenAnswer((_) async => publication);
      when(() => reader.closePublication()).thenAnswer((_) async {});

      final vm = ReadiumViewModel(
        config: config,
        bookId: 'book-prefs',
        reader: reader,
      );
      await vm.open('book.epub');

      expect(
        reader.defaultPreferencesCalls,
        hasLength(1),
        reason: 'open() 应通过 setDefaultPreferences 预置布局偏好',
      );
      expect(
        reader.defaultPreferencesCalls.single.scroll,
        expectScroll,
        reason: '$mode 下预置 scroll 应匹配阅读模式',
      );
      await vm.close();
    }

    await runCase(ReadingMode.scroll, true);
    await runCase(ReadingMode.pagination, false);
  });

  test('finalizes reading sessions on chapter change and close', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    _stubAdvancedTypography(config);
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter-1.xhtml', type: 'application/xhtml+xml'),
        const Link(href: 'chapter-2.xhtml', type: 'application/xhtml+xml'),
      ],
      tableOfContents: [
        const Link(
          href: 'chapter-1.xhtml',
          type: 'application/xhtml+xml',
          title: 'Chapter 1',
        ),
        const Link(
          href: 'chapter-2.xhtml',
          type: 'application/xhtml+xml',
          title: 'Chapter 2',
        ),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    final fontWeight = _MockPersistedSignal<double>();
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.fontWeight).thenReturn(fontWeight);
    when(() => fontWeight.value).thenReturn(400.0);
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final recorded = <({int chapterIndex})>[];
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-sessions',
      reader: reader,
      sessionRecorder:
          ({
            required bookId,
            required chapterIndex,
            required startedAt,
            required durationSeconds,
          }) async {
            recorded.add((chapterIndex: chapterIndex));
          },
    );

    await vm.open('book.epub');
    await _mountViewport(vm);
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter-1.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 10, totalProgression: 0.05),
      ),
    );
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter-2.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 12, totalProgression: 0.06),
      ),
    );
    await vm.close();
    await pumpEventQueue();

    expect(recorded.length, 2);
    expect(recorded[0].chapterIndex, 0, reason: '离开第一章时应结束第一章会话');
    expect(recorded[1].chapterIndex, 1, reason: '关闭时应结束第二章会话');
  });

  test('persists reading progress to the persistence layer on close', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    _stubAdvancedTypography(config);
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    final fontWeight = _MockPersistedSignal<double>();
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.fontWeight).thenReturn(fontWeight);
    when(() => fontWeight.value).thenReturn(400.0);
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    ReadingProgress? saved;
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-progress',
      reader: reader,
      persistProgress: (p) async {
        saved = p;
      },
    );

    await vm.open('book.epub');
    await _mountViewport(vm);
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 7, totalProgression: 0.5),
      ),
    );
    await vm.close();

    expect(saved, isNotNull, reason: '关闭时应向持久层写入进度');
    expect(saved!.bookId, 'book-progress');
    expect(saved!.chapterIndex, 0);
    expect(saved!.charOffset, 7, reason: '全书字符数未知时退化为页码位置');
    expect(saved!.progress, 0.5);
    expect(saved!.isCompleted, isFalse);
  });

  test('flush ends the session once without closing the publication', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    _stubAdvancedTypography(config);
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    final fontWeight = _MockPersistedSignal<double>();
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.fontWeight).thenReturn(fontWeight);
    when(() => fontWeight.value).thenReturn(400.0);
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    var sessionCount = 0;
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-flush',
      reader: reader,
      sessionRecorder:
          ({
            required bookId,
            required chapterIndex,
            required startedAt,
            required durationSeconds,
          }) async {
            sessionCount++;
          },
    );

    await vm.open('book.epub');
    await _mountViewport(vm);
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 3, totalProgression: 0.1),
      ),
    );

    await vm.flush();
    await pumpEventQueue();
    expect(sessionCount, 1, reason: 'flush 应结束当前会话');
    await vm.flush();
    expect(sessionCount, 1, reason: 'flush 幂等：无活跃会话时不重复记录');
    await vm.close();
    expect(sessionCount, 1, reason: 'flush 之后 close 不应再记录会话');
    await vm.close();
    expect(sessionCount, 1, reason: 'flush 之后 close 不应再记录会话');
  });

  test('persists the Locator as an engine position hint on close', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    _stubAdvancedTypography(config);
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
        identifier: 'epub-fingerprint-1',
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    final fontWeight = _MockPersistedSignal<double>();
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.fontWeight).thenReturn(fontWeight);
    when(() => fontWeight.value).thenReturn(400.0);
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    EnginePositionHint? savedHint;
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-locator',
      reader: reader,
      enginePositionSaver: ({required hint}) async {
        savedHint = hint;
      },
    );

    await vm.open('book.epub');
    await _mountViewport(vm);
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 7, totalProgression: 0.5),
      ),
    );
    await vm.close();

    expect(savedHint, isNotNull, reason: '关闭时应保存引擎位置提示');
    expect(savedHint!.engineKind, 'readium');
    expect(savedHint!.publicationFingerprint, 'epub-fingerprint-1');
    final restored = Locator.fromJson(
      jsonDecode(savedHint!.opaquePosition) as Map<String, dynamic>,
    );
    expect(restored?.href, 'chapter.xhtml');
    expect(restored?.locations?.position, 7);
  });

  test('restores the saved Locator when the fingerprint matches', () async {
    final reader = _MockFlutterReadium();
    final config = _MockReaderConfig();
    _stubAdvancedTypography(config);
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
        identifier: 'epub-fingerprint-1',
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    final fontWeight = _MockPersistedSignal<double>();
    final readingMode = _MockPersistedSignal<ReadingMode>();
    when(() => config.fontWeight).thenReturn(fontWeight);
    when(() => fontWeight.value).thenReturn(400.0);
    when(() => config.readingMode).thenReturn(readingMode);
    when(() => readingMode.value).thenReturn(ReadingMode.pagination);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final stored = EnginePositionHint(
      bookId: 'book-locator-restore',
      engineKind: 'readium',
      publicationFingerprint: 'epub-fingerprint-1',
      opaquePosition: jsonEncode(
        const Locator(
          href: 'saved-chapter.xhtml',
          type: 'application/xhtml+xml',
          locations: Locations(position: 42, totalProgression: 0.9),
        ).toJson(),
      ),
      updatedAt: DateTime.now().toUtc(),
    );
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-locator-restore',
      reader: reader,
      enginePositionLoader: ({required bookId}) async => stored,
    );

    await vm.open('book.epub');

    expect(vm.initialLocator?.href, 'saved-chapter.xhtml');
    expect(vm.initialLocator?.locations?.position, 42);
  });

  test(
    'discards the saved Locator when the fingerprint does not match',
    () async {
      final reader = _MockFlutterReadium();
      final config = _MockReaderConfig();
      _stubAdvancedTypography(config);
      final theme = _MockPersistedSignal<ReaderTheme>();
      final fontSize = _MockPersistedSignal<double>();
      final padding = _MockPersistedSignal<double>();
      final fontFamily = _MockPersistedSignal<String>();
      final bgIndex = _MockPersistedSignal<int>();
      final publication = Publication(
        metadata: Metadata(
          localizedTitle: LocalizedString.fromString('Test Book'),
          identifier: 'epub-fingerprint-1',
        ),
        readingOrder: [
          const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
        ],
        tableOfContents: [
          const Link(
            href: 'chapter.xhtml',
            type: 'application/xhtml+xml',
            title: 'Chapter 1',
          ),
        ],
      );

      when(() => config.theme).thenReturn(theme);
      when(() => theme.value).thenReturn(ReaderTheme.light);
      when(() => config.fontSize).thenReturn(fontSize);
      when(() => fontSize.value).thenReturn(100);
      when(() => config.padding).thenReturn(padding);
      when(() => padding.value).thenReturn(20);
      when(() => config.fontFamily).thenReturn(fontFamily);
      when(() => fontFamily.value).thenReturn('System');
      when(() => config.readerBgColorIndex).thenReturn(bgIndex);
      when(() => bgIndex.value).thenReturn(0);
      final fontWeight = _MockPersistedSignal<double>();
      final readingMode = _MockPersistedSignal<ReadingMode>();
      when(() => config.fontWeight).thenReturn(fontWeight);
      when(() => fontWeight.value).thenReturn(400.0);
      when(() => config.readingMode).thenReturn(readingMode);
      when(() => readingMode.value).thenReturn(ReadingMode.pagination);
      when(
        () => reader.openPublication(any()),
      ).thenAnswer((_) async => publication);
      when(
        () => reader.onReaderStatusChanged,
      ).thenAnswer((_) => Stream.value(ReadiumReaderStatus.ready));
      when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
      when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
      when(() => reader.closePublication()).thenAnswer((_) async {});

      final stored = EnginePositionHint(
        bookId: 'book-locator-stale',
        engineKind: 'readium',
        publicationFingerprint: 'old-fingerprint',
        opaquePosition: jsonEncode(
          const Locator(
            href: 'stale-chapter.xhtml',
            type: 'application/xhtml+xml',
          ).toJson(),
        ),
        updatedAt: DateTime.now().toUtc(),
      );
      final vm = ReadiumViewModel(
        config: config,
        bookId: 'book-locator-stale',
        reader: reader,
        enginePositionLoader: ({required bookId}) async => stored,
      );

      await vm.open('book.epub');

      expect(
        vm.initialLocator?.href,
        'chapter.xhtml',
        reason: '指纹不匹配时丢弃旧 Locator，退回目录首章',
      );
    },
  );
}
