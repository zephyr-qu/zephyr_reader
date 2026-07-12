import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/spike/flutter_block_paginator.dart';
import 'package:zephyr_reader/features/reader/spike/spike_pagination_session.dart';
import 'package:zephyr_reader/features/reader/spike/spike_staging_store.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(SpikeStagingStore.clearAll);

  test('installFromReady restores descriptors and page blocks', () {
    final config = lineBreakMeasureRenderConfig(
      fontSize: 16,
      lineHeight: 1.5,
      fontFamily: 'Roboto',
      letterSpacing: 0,
      paragraphSpacing: 8,
      pageMargin: 16,
      firstLineIndent: false,
      baselineAlign: true,
    );
    final plain = List.filled(40, '跨章预装箱测试内容。').join();
    final ir = ChapterContentIr(
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: plain.length),
            text: plain,
            style: const TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: const [],
          ),
        ),
      ],
      plainText: plain,
    );
    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 200,
      contentHeightDp: 90,
    );
    expect(pages.length, greaterThan(1));

    final ready = SpikeChapterReady(
      bookId: 'b1',
      chapterIndex: 2,
      filePath: '/tmp/book.epub',
      ir: ir,
      pages: pages,
      contentWidthDp: 200,
      contentHeightDp: 90,
    );
    SpikeStagingStore.next = ready;

    final session = SpikePaginationSession();
    final taken = SpikeStagingStore.takeForChapter(2, forward: true);
    expect(taken, isNotNull);
    final result = session.installFromReady(taken!);
    expect(result.totalPages, pages.length);
    expect(session.sessionChapterIndex, 2);
    expect(session.sessionFilePath, '/tmp/book.epub');
    expect(session.descriptors, hasLength(pages.length));
    expect(session.pageBlocks(0), isNotNull);
    expect(session.pageBlocks(0), isNotEmpty);
  });
}
