import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('short text fits on one page', () {
    const ir = ChapterContentIr(blocks: [], plainText: '你好世界');
    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 360,
      contentHeightDp: 600,
    );
    expect(pages, hasLength(1));
    expect(pages.single.startOffset, 0);
    expect(pages.single.endOffset, ir.plainText.length);
    expect(pages.single.isLastPage, isTrue);
  });

  test('tall viewport packs many CJK chars into contiguous pages', () {
    final plain = List.filled(80, '这是一段用来测试分页装箱的中文内容。').join();
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

    // 很矮的视口 → 多页
    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 200,
      contentHeightDp: 80,
    );

    expect(pages.length, greaterThan(1));
    expect(pages.first.startOffset, 0);
    expect(pages.last.endOffset, plain.length);
    expect(pages.last.isLastPage, isTrue);

    // 无重叠、无空洞：相邻页首尾相接
    for (var i = 1; i < pages.length; i++) {
      expect(pages[i].startOffset, pages[i - 1].endOffset);
    }

    // 拼接还原全文
    final rebuilt = pages.map((p) => plain.substring(p.startOffset, p.endOffset)).join();
    expect(rebuilt, plain);
  });

  test('empty IR yields one empty page', () {
    const ir = ChapterContentIr(blocks: [], plainText: '');
    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 360,
      contentHeightDp: 600,
    );
    expect(pages, hasLength(1));
    expect(pages.single.endOffset, 0);
  });

  test('multi-block plain ranges stay contiguous', () {
    const a = '第一段文字。';
    const b = '第二段继续。';
    final ir = const ChapterContentIr(
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: a.length),
            text: a,
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ),
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: a.length, plainLen: b.length),
            text: b,
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ),
      ],
      plainText: '$a$b',
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 360,
      contentHeightDp: 600,
    );
    expect(pages, hasLength(1));
    expect(pages.single.endOffset, a.length + b.length);
    expect(pages.single.slices, hasLength(2));
  });

  test('stopAfterPlainOffset fills current page then stops', () {
    final plain = List.filled(40, '这是一段用来测试首屏截断的中文内容。').join();
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
      contentHeightDp: 80,
      stopAfterPlainOffset: 80,
    );

    expect(pages, isNotEmpty);
    expect(pages.last.isLastPage, isFalse);
    expect(pages.last.endOffset, lessThan(plain.length));
    // 越过 stop 后仍装满当前页，故末页终点应明显大于 stop 阈值。
    expect(pages.last.endOffset, greaterThan(80));
  });

  test('paginateAsync cancel throws PaginationCancelledException', () async {
    final plain = List.filled(30, '取消测试内容块。').join();
    final chunk = plain.length ~/ 12;
    final ir = ChapterContentIr(
      blocks: [
        for (var i = 0; i < 12; i++)
          ContentBlock.text(
            TextBlock(
              plain: BlockPlainRange(plainStart: i * chunk, plainLen: chunk),
              text: plain.substring(i * chunk, (i + 1) * chunk),
              style: const TextBlockStyle(isHeading: false, headingLevel: 0),
              spans: const [],
            ),
          ),
      ],
      plainText: plain.substring(0, 12 * chunk),
    );

    // 启动前即取消：第一次 checkCancel 抛出
    await expectLater(
      FlutterBlockPaginator.paginateAsync(
        ir,
        config: config,
        contentWidthDp: 200,
        contentHeightDp: 60,
        yieldEveryChunks: 1,
        isCancelled: () => true,
      ),
      throwsA(isA<PaginationCancelledException>()),
    );
  });

  test('paginateAsync without cancel matches sync pages', () async {
    final plain = List.filled(20, '异步与同步一致。').join();
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

    final sync = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 200,
      contentHeightDp: 80,
    );
    final async = await FlutterBlockPaginator.paginateAsync(
      ir,
      config: config,
      contentWidthDp: 200,
      contentHeightDp: 80,
      yieldEveryChunks: 1,
    );
    expect(async.isPartial, isFalse);
    expect(async.pages.length, sync.length);
    expect(async.pages.last.endOffset, sync.last.endOffset);
  });
}
