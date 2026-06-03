// test/widget/reader_page_bindings_test.dart
//
// HookBuilder Widget 测试 — useReaderBindings 信号绑定验证
//
// 验证 useReaderBindings 能正确连接 ReaderViewModel 的信号，
// 并在 ViewModel 信号变化时同步更新。

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_page_bindings.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';


// ===== Mock Config =====

class _MockSharedPreferences extends Mock implements SharedPreferences {
  _MockSharedPreferences() {
    // 为 PersistedSignal 的 setXxx 方法提供默认 stub
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => setString(any(), any())).thenAnswer((_) async => true);
    when(() => remove(any())).thenAnswer((_) async => true);
  }
}
class _MockReaderConfig implements ReaderConfig {
  @override
  final SharedPreferences prefs = _MockSharedPreferences();
  @override
  late final theme = persistedEnum<ReaderTheme>(
    prefs, '', ReaderTheme.light, ReaderTheme.fromId,
    debounce: Duration.zero,
  );
  @override
  late final fontSize = persistedDouble(
    prefs, '', ReaderFontSize.medium.size,
    debounce: Duration.zero,
  );
  @override
  late final lineHeight = persistedDouble(
    prefs, '', 1.6, debounce: Duration.zero,
  );
  @override
  late final paragraphSpacing = persistedDouble(
    prefs, '', 12.0, debounce: Duration.zero,
  );
  @override
  late final padding = persistedDouble(
    prefs, '', 16.0, debounce: Duration.zero,
  );
  @override
  late final readerBgColorIndex = persistedInt(
    prefs, '', 0, debounce: Duration.zero,
  );
  @override
  late final autoScroll = persistedBool(
    prefs, '', false, debounce: Duration.zero,
  );
  @override
  late final autoScrollSpeed = persistedInt(
    prefs, '', 30, debounce: Duration.zero,
  );
  @override
  late final letterSpacing = persistedDouble(
    prefs, '', 0.0, debounce: Duration.zero,
  );
  @override
  late final tapLayout = persistedEnum<TapLayout>(
    prefs, '', TapLayout.rightHanded,
    (name) => TapLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TapLayout.rightHanded,
    ),
    debounce: Duration.zero,
  );
  @override
  late final punctuationSqueeze = persistedBool(
    prefs, '', true, debounce: Duration.zero,
  );
  @override
  late final baselineAlign = persistedBool(
    prefs, '', true, debounce: Duration.zero,
  );
  @override
  final writingDirection = signal<WritingDirection>(WritingDirection.horizontal);
  @override
  final brightnessOverlay = signal<double>(0.0);

  @override
  double get pageMargin => padding.value;

  @override
  double get fontSizeValue => ReaderFontSize.fromSize(fontSize.value).size;

  @override
  Future<void> resetToDefault() async {
    theme.value = ReaderTheme.light;
    fontSize.value = ReaderFontSize.medium.size;
    lineHeight.value = 1.6;
    paragraphSpacing.value = 16.0;
    padding.value = 16.0;
    readerBgColorIndex.value = 0;
    autoScroll.value = false;
    autoScrollSpeed.value = 30;
    letterSpacing.value = 0.0;
    punctuationSqueeze.value = true;
    baselineAlign.value = true;
    tapLayout.value = TapLayout.rightHanded;
  }
}
// ===== Mock ViewModel =====

class MockReaderViewModel extends Mock implements ReaderViewModel {
  @override
  final config = _MockReaderConfig();
  @override
  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));
  @override
  final showToolbar = signal(false);
  @override
  final showSettings = signal(false);
  @override
  final showCatalog = signal(false);
  @override
  final showBookmarks = signal(false);
  @override
  final showSelectionToolbar = signal(false);
  @override
  final showSearch = signal(false);
  @override
  final bookId = signal('test_book');
  @override
  final chapterIndex = signal(0);
  @override
  final pageIndex = signal(0);
  @override
  final totalPages = signal(1);
  @override
  final readingMode = signal(ReadingMode.scroll);
  @override
  final chapterContent = asyncSignal<String>(AsyncState.data('Test content'));
  @override
  final isLoading = signal(false);
  @override
  final error = signal<String?>(null);
  @override
  final bilingualAlignment = asyncSignal<BilingualAlignment?>(
    AsyncState.data(null),
  );
  @override
  final autoScrollTick = signal(0);
  @override
  final highlights = signal<List<Note>>([]);
  @override
  final searchQuery = signal('');
  @override
  final searchCurrentIndex = signal(0);
  @override
  final toastMessage = signal('');
  @override
  final pendingJumpCharOffset = signal<int?>(null);
  @override
  late final ReadonlySignal<String> progressText = computed(() => '0%');
  @override
  late final ReadonlySignal<String> currentChapterTitle = computed(() => 'Chapter');
  @override
  late final ReadonlySignal<double> fontSizeDouble = computed(
    () => config.fontSize.value,
  );
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockReaderViewModel mockVm;

  setUp(() {
    mockVm = MockReaderViewModel();
  });

  group('useReaderBindings', () {
    testWidgets('绑定 ReaderViewModel 所有信号', (tester) async {
      late ReaderPageBindings bindings;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bindings = useReaderBindings(mockVm);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // 验证信号值同步
      expect(bindings.fontSize, equals(16.0));
      expect(bindings.lineHeight, equals(1.6));
      expect(bindings.bgIndex, equals(0));
      expect(bindings.showToolbar, isFalse);
      expect(bindings.showSettings, isFalse);
      expect(bindings.showCatalog, isFalse);
      expect(bindings.isLoading, isFalse);
      expect(bindings.currentBookId, equals('test_book'));
      expect(bindings.chapterIndex, equals(0));
      expect(bindings.pageIndex, equals(0));
      expect(bindings.totalPages, equals(1));
    });

    testWidgets('ViewModel 信号变化时绑定自动更新', (tester) async {
      late ReaderPageBindings bindings;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bindings = useReaderBindings(mockVm);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(bindings.fontSize, equals(16.0));

      // 更新 ViewModel 信号
      mockVm.config.fontSize.value = 20.0;
      await tester.pump();

      // 绑定应反映新值
      expect(bindings.fontSize, equals(20.0));
    });

    testWidgets('多个信号独立更新', (tester) async {
      late ReaderPageBindings bindings;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bindings = useReaderBindings(mockVm);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // 同时更新多个信号
      mockVm.config.fontSize.value = 18.0;
      mockVm.showToolbar.value = true;
      mockVm.chapterIndex.value = 5;
      await tester.pump();

      expect(bindings.fontSize, equals(18.0));
      expect(bindings.showToolbar, isTrue);
      expect(bindings.chapterIndex, equals(5));
    });

    testWidgets('useSignalEffect 在 mount 时触发', (tester) async {
      int effectCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              useSignalEffect(() {
                effectCallCount++;
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // effect 在 mount 时至少触发一次
      expect(effectCallCount, equals(1));
    });

    testWidgets('useSignalEffect 响应信号变化', (tester) async {
      int effectCallCount = 0;
      final trigger = signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              useSignalEffect(() {
                trigger.value; // 订阅
                effectCallCount++;
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(effectCallCount, equals(1));

      trigger.value = 1;
      await tester.pump();
      expect(effectCallCount, equals(2));

      trigger.value = 2;
      await tester.pump();
      expect(effectCallCount, equals(3));
    });
  });
}
