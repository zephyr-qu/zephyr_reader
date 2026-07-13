// test/features/reader/flutter_pagination/flutter_pagination_session_test.dart
//
// FlutterPaginationSession 单元测试。
// 测试不依赖 FRB 的行为：installFromReady、缓存管理、dispose、工具方法。
// FRB 依赖路径（beginPaginate, expandToFullChapter）在集成测试中验证。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_staging_store.dart';
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PaginationStagingStore.clearAll);

  group('FlutterPaginationSession', () {
    late FlutterPaginationSession session;
    final sampleIr = const ChapterContentIr(
      plainText: 'Hello World',
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: 11),
            text: 'Hello World',
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ),
      ],
    );
    final samplePages = [
      const PackedPage(
        pageIndex: 0,
        startOffset: 0,
        endOffset: 6,
        isLastPage: false,
        slices: [
          PackedBlockSlice.text(
            blockIndex: 0,
            text: 'Hello ',
            isBlockStart: true,
            isBlockEnd: false,
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ],
      ),
      const PackedPage(
        pageIndex: 1,
        startOffset: 6,
        endOffset: 11,
        isLastPage: true,
        slices: [
          PackedBlockSlice.text(
            blockIndex: 0,
            text: 'World',
            isBlockStart: false,
            isBlockEnd: true,
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ],
      ),
    ];

    setUp(() {
      session = FlutterPaginationSession();
    });

    test('初态所有 getter 返回 null/default', () {
      expect(session.descriptors, isNull);
      expect(session.sessionConfigHash, isNull);
      expect(session.sessionChapterIndex, isNull);
      expect(session.sessionIsPartial, isFalse);
      expect(session.sessionFilePath, isNull);
      expect(session.sessionMode, ChapterPaginationMode.contentBlocks);
      expect(session.pageBlocks(0), isNull);
      expect(session.pageContent(0), isNull);
      expect(session.resolvePageIndexForCharOffset(0), isNull);
    });

    group('installFromReady', () {
      test('从 staging ready 安装后 getter 正确', () {
        final ready = PaginationChapterReady(
          bookId: 'b1',
          chapterIndex: 3,
          filePath: '/book.epub',
          ir: sampleIr,
          pages: samplePages,
          contentWidthDp: 300,
          contentHeightDp: 500,
        );
        PaginationStagingStore.next = ready;

        final taken = PaginationStagingStore.takeForChapter(3, forward: true);
        expect(taken, isNotNull);
        final result = session.installFromReady(taken!);

        expect(result.totalPages, 2);
        expect(result.isPartial, isFalse);
        expect(session.sessionChapterIndex, 3);
        expect(session.sessionFilePath, '/book.epub');
        expect(session.sessionIsPartial, isFalse);
        expect(session.descriptors, hasLength(2));
        expect(session.descriptors![0].pageIndex, 0);
        expect(session.descriptors![1].pageIndex, 1);
      });

      test('installFromReady 后 descriptors 可读', () {
        final ready = PaginationChapterReady(
          bookId: 'b1',
          chapterIndex: 0,
          filePath: '/book.epub',
          ir: sampleIr,
          pages: samplePages,
          contentWidthDp: 300,
          contentHeightDp: 500,
        );
        PaginationStagingStore.next = ready;
        final taken = PaginationStagingStore.takeForChapter(0, forward: true);
        session.installFromReady(taken!);

        final d0 = session.descriptors![0];
        expect(d0.startOffset, 0);
        expect(d0.endOffset, 6);
        expect(d0.isLastPage, isFalse);

        final d1 = session.descriptors![1];
        expect(d1.startOffset, 6);
        expect(d1.endOffset, 11);
        expect(d1.isLastPage, isTrue);
      });
    });

    group('expandToFullChapter', () {
      test('非 partial 时直接返回当前页数', () async {
        final ready = PaginationChapterReady(
          bookId: 'b1',
          chapterIndex: 0,
          filePath: '/book.epub',
          ir: sampleIr,
          pages: samplePages,
          contentWidthDp: 300,
          contentHeightDp: 500,
        );
        PaginationStagingStore.next = ready;
        final taken = PaginationStagingStore.takeForChapter(0, forward: true);
        session.installFromReady(taken!);

        final result = await session.expandToFullChapter(
          bookId: 'b1',
          chapterIndex: 0,
          params: const PaginationParams(
            fontSize: 16,
            lineHeight: 1.5,
            width: 400,
            height: 600,
            padding: 20,
            devicePixelRatio: 1.0,
          ),
        );

        expect(result.totalPages, 2);
        expect(result.isPartial, isFalse);
      });
    });

    group('ensureWindow / warmPageCache / pageContent', () {
      test('ensureWindow 填充 window 范围页内容', () {
        final ready = PaginationChapterReady(
          bookId: 'b1',
          chapterIndex: 0,
          filePath: '/book.epub',
          ir: sampleIr,
          pages: samplePages,
          contentWidthDp: 300,
          contentHeightDp: 500,
        );
        PaginationStagingStore.next = ready;
        final taken = PaginationStagingStore.takeForChapter(0, forward: true);
        session.installFromReady(taken!);

        session.ensureWindow(0);

        expect(session.pageContent(0), isNotNull);
        expect(session.pageContent(1), isNotNull);
      });

      test('warmPageCache 手动写入缓存后可读取', () {
        session.warmPageCache(5, 'custom content');
        expect(session.pageContent(5), 'custom content');
      });

      test('pageBlocks 返回 InstallFromReady 后的块', () {
        final ready = PaginationChapterReady(
          bookId: 'b1',
          chapterIndex: 0,
          filePath: '/book.epub',
          ir: sampleIr,
          pages: samplePages,
          contentWidthDp: 300,
          contentHeightDp: 500,
        );
        PaginationStagingStore.next = ready;
        final taken = PaginationStagingStore.takeForChapter(0, forward: true);
        session.installFromReady(taken!);

        final blocks0 = session.pageBlocks(0);
        expect(blocks0, isNotNull);
        expect(blocks0, isNotEmpty);
        expect(
          blocks0!.any(
            (b) => b.when(
              text: (t) => t.text.contains('Hello'),
              image: (_) => false,
            ),
          ),
          isTrue,
        );
      });
    });

    group('resolvePageIndexForCharOffset', () {
      test('install 后可用 charOffset 定位页码', () {
        final ready = PaginationChapterReady(
          bookId: 'b1',
          chapterIndex: 0,
          filePath: '/book.epub',
          ir: sampleIr,
          pages: samplePages,
          contentWidthDp: 300,
          contentHeightDp: 500,
        );
        PaginationStagingStore.next = ready;
        final taken = PaginationStagingStore.takeForChapter(0, forward: true);
        session.installFromReady(taken!);

        expect(session.resolvePageIndexForCharOffset(0), 0);
        expect(session.resolvePageIndexForCharOffset(3), 0);
        expect(session.resolvePageIndexForCharOffset(6), 1);
        expect(session.resolvePageIndexForCharOffset(10), 1);
      });
    });

    group('dispose', () {
      test('dispose 后所有状态重置', () {
        final ready = PaginationChapterReady(
          bookId: 'b1',
          chapterIndex: 0,
          filePath: '/book.epub',
          ir: sampleIr,
          pages: samplePages,
          contentWidthDp: 300,
          contentHeightDp: 500,
        );
        PaginationStagingStore.next = ready;
        final taken = PaginationStagingStore.takeForChapter(0, forward: true);
        session.installFromReady(taken!);

        expect(session.descriptors, isNotNull);
        session.dispose();

        expect(session.descriptors, isNull);
        expect(session.sessionChapterIndex, isNull);
        expect(session.sessionIsPartial, isFalse);
        expect(session.pageContent(0), isNull);
        expect(session.pageBlocks(0), isNull);
      });
    });

    group('slicesToPageBlocks', () {
      test('文本切片转换为 PageBlockSlice.text', () {
        final slices = [
          const PackedBlockSlice.text(
            blockIndex: 0,
            text: 'Hello',
            isBlockStart: true,
            isBlockEnd: false,
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ];
        final blocks = FlutterPaginationSession.slicesToPageBlocks(slices);
        expect(blocks, hasLength(1));
        blocks[0].when(
          text: (t) {
            expect(t.text, 'Hello');
            expect(t.isBlockStart, isTrue);
          },
          image: (_) => fail('expected text block'),
        );
      });

      test('图片切片转换为 PageBlockSlice.image', () {
        final slices = [
          const PackedBlockSlice.image(
            blockIndex: 1,
            assetId: 'img_001',
            imageLayout: ImageBlockLayout.inlineContain,
            alt: 'test image',
          ),
        ];
        final blocks = FlutterPaginationSession.slicesToPageBlocks(slices);
        expect(blocks, hasLength(1));
        blocks[0].when(
          text: (_) => fail('expected image block'),
          image: (i) {
            expect(i.assetId, 'img_001');
          },
        );
      });
    });
  });
}
