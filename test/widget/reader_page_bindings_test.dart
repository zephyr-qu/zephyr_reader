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
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_page_bindings.dart';

// ===== Mock ViewModel =====

class MockReaderViewModel extends Mock implements ReaderViewModel {
  // 信号属性必须实现为真实 Signal，不能被 mocktail 拦截
  final fontSize = signal(16.0);
  final lineHeight = signal(1.6);
  final readerTheme = signal(ReaderTheme.light);
  final letterSpacing = signal(0.0);
  final paragraphSpacing = signal(0.0);
  final pageMargin = signal(0.0);
  final writingDirection = signal(WritingDirection.ltr);
  final readerBgColorIndex = signal(0);
  final brightnessOverlay = signal(0.0);
  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));
  final showToolbar = signal(false);
  final showSettings = signal(false);
  final showCatalog = signal(false);
  final showBookmarks = signal(false);
  final showSelectionToolbar = signal(false);
  final showSearch = signal(false);
  final bookId = signal('test_book');
  final chapterIndex = signal(0);
  final pageIndex = signal(0);
  final totalPages = signal(1);
  final readingMode = signal(ReadingMode.scroll);
  final chapterContent = asyncSignal<String>(AsyncState.data('Test content'));
  final isLoading = signal(false);
  final error = signal<String?>(null);
  final bilingualAlignment = asyncSignal<BilingualAlignment?>(
    AsyncState.data(null),
  );
  final autoScrollTick = signal(0);
  final highlights = signal<List<Note>>([]);
  final searchQuery = signal('');
  final searchCurrentIndex = signal(0);
  final searchResultMatches = signal(0);
  final toastMessage = signal('');
}

ReaderTheme _mockTheme() => ReaderTheme.light;

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
      mockVm.fontSize.value = 20.0;
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
      mockVm.fontSize.value = 18.0;
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
