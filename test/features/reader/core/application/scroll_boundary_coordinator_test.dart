import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/features/reader/core/application/scroll_boundary_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_notice.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';

class _MockRepo extends Mock implements ReaderRepositoryInterface {}

ScrollChapterSegment _seg(int chapter, String marker) {
  return ScrollSegmentFactory.fromPayload(
    chapter,
    scrollPlainPayload('$marker\n\nPara2'),
  );
}

ChapterContentIr _sampleIr() {
  const style = TextBlockStyle(
    isHeading: false,
    headingLevel: 0,
    textIndentEm: null,
    marginTopEm: null,
    marginBottomEm: null,
    fontFamily: null,
    lineHeight: null,
    textAlign: null,
  );
  return ChapterContentIr(
    plainText: 'Hello\uFFFC world',
    blocks: [
      ContentBlock.text(
        TextBlock(
          plain: BlockPlainRange(plainStart: 0, plainLen: 5),
          text: 'Hello',
          style: style,
          spans: const [],
        ),
      ),
      ContentBlock.image(
        ImageBlock(
          plain: BlockPlainRange(plainStart: 5, plainLen: 1),
          assetId: 'img1',
        ),
      ),
      ContentBlock.text(
        TextBlock(
          plain: BlockPlainRange(plainStart: 6, plainLen: 6),
          text: ' world',
          style: style,
          spans: const [],
        ),
      ),
    ],
  );
}

void main() {
  const layout = ScrollLayoutParams(
    textRowHeight: 88,
    paragraphSpacing: 12,
    contentWidth: 360,
    fontSize: 16,
  );

  late _MockRepo repo;
  late ScrollBoundaryCoordinator coord;
  late List<ScrollChapterSegment> emitted;
  int? lastChapter;
  int? lastOffset;

  setUpAll(() {
    registerFallbackValue(ReadingMode.scroll);
    registerFallbackValue(ReadingMode.bilingual);
  });

  setUp(() {
    repo = _MockRepo();
    when(() => repo.preloadChapter(any(), any())).thenAnswer((_) async {});
    emitted = [];
    lastChapter = null;
    lastOffset = null;
    coord = ScrollBoundaryCoordinator(
      repo: repo,
      onPositionChanged: (chapter, offset) {
        lastChapter = chapter;
        lastOffset = offset;
      },
      onChapterChanged: (chapter) {
        lastChapter = chapter;
      },
      onSegmentsChanged: (segments) {
        emitted = List.from(segments);
      },
    );
    coord.init(0, 'Ch0\n\nPara2');
  });

  group('ScrollBoundaryCoordinator', () {
    test('appendNext 基于 segments.last 而非 stale center', () async {
      coord.composer!.appendNext(_seg(1, 'Ch1'));
      // center 仍为 0，但 segments 已有章 1
      when(
        () => repo.loadScrollSegment(
          any(),
          2,
          readingMode: any(named: 'readingMode'),
        ),
      ).thenAnswer(
        (_) async => scrollPlainPayload('Ch2\n\nPara2'),
      );

      await coord.appendNext(
        bookId: 'book',
        readingMode: ReadingMode.scroll,
      );

      verify(
        () => repo.loadScrollSegment(
          'book',
          2,
          readingMode: ReadingMode.scroll,
        ),
      ).called(1);
      expect(emitted.last.chapterIndex, 2);
    });

    test('prependPrev 基于 segments.first 而非 stale center', () async {
      final local = ScrollBoundaryCoordinator(
        repo: repo,
        onPositionChanged: (_, _) {},
        onChapterChanged: (_) {},
        onSegmentsChanged: (segments) {
          emitted = List.from(segments);
        },
      );
      local.init(1, 'Ch1\n\nPara2');
      when(
        () => repo.loadScrollSegment(
          any(),
          0,
          readingMode: any(named: 'readingMode'),
        ),
      ).thenAnswer(
        (_) async => scrollPlainPayload('Ch0prev\n\nPara2'),
      );

      await local.prependPrev(
        bookId: 'book',
        readingMode: ReadingMode.scroll,
      );

      verify(
        () => repo.loadScrollSegment(
          'book',
          0,
          readingMode: ReadingMode.scroll,
        ),
      ).called(1);
      expect(emitted.first.chapterIndex, 0);
    });

    test('reportScrollPosition 跨章时触发 onSegmentChanged', () {
      coord.composer!.appendNext(_seg(1, 'Ch1'));
      // 2 段 × 2 段 ≈ 4 段，每段高 100px；offset 250 → 第 3 段（章 1）
      coord.reportScrollPosition(250, layout);
      expect(lastChapter, 1);
      expect(lastOffset, isNotNull);
      expect(coord.composer!.centerChapterIndex, 1);
    });

    test('appendNext scroll IR 段不触发 onReaderNotice', () async {
      when(
        () => repo.loadScrollSegment(
          any(),
          1,
          readingMode: any(named: 'readingMode'),
        ),
      ).thenAnswer(
        (_) async => scrollIrPayload(
          chapterIr: _sampleIr(),
          chapterFilePath: '/books/test.epub',
        ),
      );
      ReaderNotice? noticed;
      final local = ScrollBoundaryCoordinator(
        repo: repo,
        onPositionChanged: (_, _) {},
        onChapterChanged: (_) {},
        onSegmentsChanged: (segments) {
          emitted = List.from(segments);
        },
        onReaderNotice: (n) => noticed = n,
      );
      local.init(0, 'Ch0\n\nPara2');

      await local.appendNext(
        bookId: 'book',
        readingMode: ReadingMode.scroll,
      );

      expect(noticed, isNull);
      expect(emitted.last.isIr, isTrue);
      expect(emitted.last.chapterIndex, 1);
    });

    test('appendNext 双语大章降级仍触发 onReaderNotice', () async {
      when(
        () => repo.loadScrollSegment(
          any(),
          1,
          readingMode: any(named: 'readingMode'),
        ),
      ).thenAnswer(
        (_) async => scrollPlainPayload('Ch1\n\nPara2', epubRichSkipped: true),
      );
      ReaderNotice? noticed;
      final local = ScrollBoundaryCoordinator(
        repo: repo,
        onPositionChanged: (_, _) {},
        onChapterChanged: (_) {},
        onSegmentsChanged: (_) {},
        onReaderNotice: (n) => noticed = n,
      );
      local.init(0, 'Ch0\n\nPara2');

      await local.appendNext(
        bookId: 'book',
        readingMode: ReadingMode.bilingual,
      );

      expect(noticed, ReaderNotice.epubRichSkipped);
    });

    test('appendNext scroll 带 epubRichSkipped 标记也不触发 notice', () async {
      when(
        () => repo.loadScrollSegment(
          any(),
          1,
          readingMode: any(named: 'readingMode'),
        ),
      ).thenAnswer(
        (_) async => scrollPlainPayload('Ch1\n\nPara2', epubRichSkipped: true),
      );
      ReaderNotice? noticed;
      final local = ScrollBoundaryCoordinator(
        repo: repo,
        onPositionChanged: (_, _) {},
        onChapterChanged: (_) {},
        onSegmentsChanged: (_) {},
        onReaderNotice: (n) => noticed = n,
      );
      local.init(0, 'Ch0\n\nPara2');

      await local.appendNext(
        bookId: 'book',
        readingMode: ReadingMode.scroll,
      );

      expect(noticed, isNull);
    });

    test('reportScrollPosition 同章内只更新 offset', () {
      coord.reportScrollPosition(50, layout);
      expect(lastChapter, 0);
      expect(coord.composer!.centerChapterIndex, 0);
    });
  });
}
