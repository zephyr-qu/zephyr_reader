// test/features/reader/core_pagination_test.dart
//
// 核心分页管线集成测试 — 验证 Rust 引擎 parse → paginate → content 全流程。
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

import '../../helpers/integration_test_helper.dart';

const _fixtureFileName = 'test_book.txt';
const _fixtureContent = '''
第一章 混合内容

Today was the day he had been waiting for. 他站在窗前，看着这座城市的 sunrise。
The past few weeks had been challenging, but he knew that every setback was really just a setup for a comeback.

"加油！" 他对自己喊道。His voice echoed through the empty room.

学习新的语言就像 opening a door to another world。每一个词汇都是一把钥匙，每一句话都是一座桥梁。
他翻开笔记本，开始记录今天的学习计划：First, review yesterday's vocabulary; second, practice pronunciation; third, read a short article.

时间一分一秒地过去。The morning light gradually filled the room, casting long shadows across the floor.
他沉浸在学习的海洋中，完全忘记了时间的流逝。English and Chinese intertwined in his mind, creating a beautiful symphony of sounds and meanings.

窗外传来鸟儿的声音。A gentle breeze rustled the leaves outside. 他抬起头，深深地吸了一口气。The world was full of wonders waiting to be discovered.

他继续阅读手中的书。Page after page, he absorbed the knowledge and wisdom contained within. 每一个字都像一颗种子，在他的心中生根发芽。
''';

TypesetConfig _defaultConfig() {
  return const TypesetConfig(
    pageWidth: 800,
    pageHeight: 600,
    fontSize: 16,
    lineSpacing: 1.5,
    letterSpacing: 0,
    paragraphSpacing: 1.5,
    firstLineIndent: 2,
    punctuationSqueeze: true,
    language: LanguageType.mixed,
    autoSpaceRatio: 0.5,
    fontFamily: 'Noto Sans SC',
    calibration: null,
  );
}

void main() {
  final ffiAvailable = isFfiAvailable();

  late String? filePath;
  late String? bookId;
  late List<Chapter> chapters = [];

  setUpAll(() async {
    if (!ffiAvailable) return;
    await setupTestStorage(label: 'pagination');
    filePath = await createTestFile('pagination_test.txt', _fixtureContent);
    final parse = await parseTestBook(filePath!);
    filePath = parse.$2;
    bookId = parse.$1;
    chapters = await chapter_api.listChaptersByBook(bookId: bookId!);
  });

  tearDownAll(() async {
    if (!ffiAvailable) return;
    if (bookId != null) await deleteTestBook(bookId!);
    await teardownTestStorage();
  });

  group('core pagination integration tests', () {
    // ==================== Parse pipeline ====================

    test('parseBook returns valid book metadata and chapters', () async {
      final book = await book_api.getBook(bookId: bookId!);
      expect(book!.title, isNotEmpty);
      expect(book.filePath, isNotEmpty);
      expect(chapters.length, greaterThan(0));
      expect(chapters.first.chapterIndex, 0);
    });

    test('parseBook chapter bounds are valid', () {
      final c0 = chapters.firstWhere((c) => c.chapterIndex == 0);
      expect(c0.startIndex, greaterThanOrEqualTo(0));
      expect(
        c0.endIndex,
        greaterThan(c0.startIndex),
        reason:
            'Chapter 0: startIndex=${c0.startIndex}, endIndex=${c0.endIndex}',
      );
    });

    // ==================== PaginationSessionHandle API ====================

    group('PaginationSessionHandle API', () {
      test('create, fetch page, dispose', () async {
        final (handle, result) = await core_api.createPaginationSession(
          filePath: filePath!,
          chapterIndex: 0,
          config: _defaultConfig(),
        );
        expect(handle.sessionId, greaterThan(BigInt.zero));
        expect(result.descriptors, isNotEmpty);

        final pageText = core_api.getSessionPageContent(
          handle: handle,
          pageIndex: 0,
        );
        expect(pageText, isNotEmpty);

        core_api.disposePaginationSession(handle: handle);
      });

      test('partial session upgrades via paginateSessionFull', () async {
        final (handle, partial) = await core_api.createPaginationSession(
          filePath: filePath!,
          chapterIndex: 0,
          config: _defaultConfig(),
          maxChars: BigInt.from(500),
        );
        expect(partial.isPartial, isTrue);

        final full = await core_api.paginateSessionFull(handle: handle);
        expect(full.isPartial, isFalse);
        expect(
          full.descriptors.length,
          greaterThanOrEqualTo(partial.descriptors.length),
        );

        final pageText = core_api.getSessionPageContent(
          handle: handle,
          pageIndex: 0,
        );
        expect(pageText, isNotEmpty);

        core_api.disposePaginationSession(handle: handle);
      });
    });

    // ==================== paginateChapter (lightweight descriptors) ====================

    group('paginateChapter with TypesetConfig', () {
      late PaginateResult paginateResult;

      setUp(() async {
        paginateResult = await core_api.paginateChapter(
          filePath: filePath!,
          chapterIndex: 0,
          config: _defaultConfig(),
        );
      });

      test('produces at least 1 page descriptor', () {
        expect(paginateResult.descriptors.length, greaterThanOrEqualTo(1));
      });

      test('descriptors have monotonic byte offsets', () {
        for (final d in paginateResult.descriptors) {
          expect(
            d.startOffset,
            lessThanOrEqualTo(d.endOffset),
            reason:
                'Page ${d.pageIndex}: start=${d.startOffset}, end=${d.endOffset}',
          );
          if (d.pageIndex > 0) {
            final prev = paginateResult.descriptors[d.pageIndex - 1];
            expect(
              d.startOffset,
              greaterThanOrEqualTo(prev.endOffset),
              reason:
                  'Page ${d.pageIndex} start ${d.startOffset} < prev end ${prev.endOffset}',
            );
          }
        }
      });

      test('last page has isLastPage=true', () {
        final last = paginateResult.descriptors.last;
        expect(last.isLastPage, isTrue);
      });

      test('configHash is supported (non-zero BigInt)', () {
        expect(paginateResult.configHash, isA<BigInt>());
        expect(paginateResult.configHash > BigInt.zero, isTrue);
      });
    });

    // ==================== paginateAllContent (full page content) ====================

    group('paginateAllContent returns page content', () {
      late List<PageContent> pages;

      setUp(() async {
        pages = await core_api.paginateAllContent(
          filePath: filePath!,
          chapterIndex: 0,
          config: _defaultConfig(),
        );
      });

      test('produces at least 1 page', () {
        expect(pages.length, greaterThanOrEqualTo(1));
      });

      test('pages have non-empty text content', () {
        for (final p in pages) {
          expect(
            p.content,
            isNotEmpty,
            reason: 'Page ${p.pageIndex} text is empty',
          );
        }
      });

      test('pages cover the full chapter text range', () {
        final c0 = chapters.firstWhere((c) => c.chapterIndex == 0);
        final first = pages.first;
        final last = pages.last;
        expect(first.startOffset, equals(0));
        expect(last.endOffset, greaterThan(0));
        expect(last.endOffset, lessThanOrEqualTo(c0.endIndex));
      });

      test('last page has isLastPage=true', () {
        final last = pages.last;
        expect(last.isLastPage, isTrue);
      });

      test('page content contains expected CJK and Latin strings', () {
        final allText = pages.map((p) => p.content).join('');
        expect(allText, contains('Today was the day'));
        expect(allText, contains('他站在窗前'));
        expect(allText, contains('学习新的语言就像'));
        expect(allText, contains('加油'));
        expect(allText, contains('comeback'));
      });
    });

    // ==================== Real-book pipeline (using 活着.txt) ====================

    group('Real book (活着.txt)', () {
      late String huozhePath;
      late List<Chapter> huozheChapters;
      late String huozheBookId;

      setUpAll(() async {
        huozhePath = await copyFixtureFile('活着.txt');
        final result = await parseTestBook(huozhePath);
        huozheBookId = result.$1;
        huozhePath = result.$2;
        huozheChapters = await chapter_api.listChaptersByBook(
          bookId: huozheBookId,
        );
      });

      tearDownAll(() async {
        await deleteTestBook(huozheBookId);
      });

      test('parses without error and has valid metadata', () async {
        final book = await book_api.getBook(bookId: huozheBookId);
        expect(book!.title, isNotEmpty);
        expect(huozheChapters.length, greaterThanOrEqualTo(1));
      });
      test('detects multiple chapters (中文版自序, 韩文版自序)', () {
        expect(huozheChapters.length, greaterThanOrEqualTo(2));
        expect(huozheChapters[0].title, contains('中文版自序'));
        expect(huozheChapters[1].title, contains('韩文版自序'));
        expect(
          huozheChapters[0].endIndex,
          lessThan(huozheChapters[1].endIndex),
        );
      });

      test('paginateChapter produces at least 1 descriptor', () async {
        final result = await core_api.paginateChapter(
          filePath: huozhePath,
          chapterIndex: 0,
          config: _defaultConfig(),
        );
        expect(result.descriptors.length, greaterThanOrEqualTo(1));
        for (final d in result.descriptors) {
          expect(d.startOffset, lessThan(d.endOffset));
        }
        expect(result.descriptors.last.isLastPage, isTrue);
      });

      test('paginateAllContent returns non-empty pages', () async {
        final pages = await core_api.paginateAllContent(
          filePath: huozhePath,
          chapterIndex: 0,
          config: _defaultConfig(),
        );
        expect(pages.length, greaterThanOrEqualTo(1));
        for (final p in pages) {
          expect(p.content, isNotEmpty);
        }
      });

      test('page content contains real Chinese text from the book', () async {
        final pages = await core_api.paginateAllContent(
          filePath: huozhePath,
          chapterIndex: 0,
          config: _defaultConfig(),
        );
        final allText = pages.map((p) => p.content).join('');
        expect(allText, contains('自序'));
        expect(allText, contains('作家'));
        expect(allText, contains('作品'));
        expect(allText.length, greaterThan(100));
      });

      test(
        'page content of chapter 1 (韩文版自序) is non-empty and contains Korean preface',
        () async {
          final pages = await core_api.paginateAllContent(
            filePath: huozhePath,
            chapterIndex: 1,
            config: _defaultConfig(),
          );
          expect(pages.length, greaterThanOrEqualTo(1));
          final allText = pages.map((p) => p.content).join('');
          expect(allText, contains('自序'));
          expect(allText.length, greaterThan(100));
        },
      );

      // ==================== Real-book pipeline (using 活着.epub) ====================

      group('Real book (活着.epub)', () {
        late String huozheEpubPath;
        late List<Chapter> huozheEpubChapters;
        late String huozheEpubBookId;

        setUpAll(() async {
          huozheEpubPath = await copyFixtureFile('活着.epub');
          final result = await parseTestBook(huozheEpubPath);
          huozheEpubBookId = result.$1;
          huozheEpubPath = result.$2;
          huozheEpubChapters = await chapter_api.listChaptersByBook(
            bookId: huozheEpubBookId,
          );
        });

        tearDownAll(() async {
          await deleteTestBook(huozheEpubBookId);
        });

        test('parses without error and has valid metadata', () async {
          final book = await book_api.getBook(bookId: huozheEpubBookId);
          expect(book!.title, isNotEmpty);
          expect(huozheEpubChapters.length, greaterThanOrEqualTo(1));
        });

        test('chapter bounds are valid', () {
          for (final c in huozheEpubChapters) {
            expect(c.startIndex, greaterThanOrEqualTo(0));
            expect(
              c.endIndex,
              greaterThanOrEqualTo(c.startIndex),
              reason:
                  'Chapter ${c.chapterIndex}: start=${c.startIndex}, end=${c.endIndex}',
            );
          }
        });

        test('paginateChapter produces at least 1 descriptor', () async {
          final result = await core_api.paginateChapter(
            filePath: huozheEpubPath,
            chapterIndex: 0,
            config: _defaultConfig(),
          );
          expect(result.descriptors.length, greaterThanOrEqualTo(1));
          for (final d in result.descriptors) {
            expect(d.startOffset, lessThan(d.endOffset));
          }
          expect(result.descriptors.last.isLastPage, isTrue);
        });

        test('paginateAllContent returns non-empty pages', () async {
          final pages = await core_api.paginateAllContent(
            filePath: huozheEpubPath,
            chapterIndex: 0,
            config: _defaultConfig(),
          );
          expect(pages.length, greaterThanOrEqualTo(1));
          for (final p in pages) {
            expect(p.content, isNotEmpty);
          }
        });

        test('page content contains real Chinese text from the EPUB', () async {
          final pages = await core_api.paginateAllContent(
            filePath: huozheEpubPath,
            chapterIndex: 0,
            config: _defaultConfig(),
          );
          final allText = pages.map((p) => p.content).join('');
          expect(allText, contains('自序'));
          expect(allText, isNotEmpty);
          expect(allText.length, greaterThan(100));
        });
      });

      // ==================== Real-book pipeline (using mixed_content.md) ====================

      group('Real book (mixed_content.md)', () {
        late String mdPath;
        late List<Chapter> mdChapters;
        late String mdBookId;

        setUpAll(() async {
          mdPath = await copyFixtureFile('mixed_content.md');
          final result = await parseTestBook(mdPath);
          mdBookId = result.$1;
          mdPath = result.$2;
          mdChapters = await chapter_api.listChaptersByBook(bookId: mdBookId);
        });

        tearDownAll(() async {
          await deleteTestBook(mdBookId);
        });

        test('parses without error and has valid metadata', () async {
          final book = await book_api.getBook(bookId: mdBookId);
          expect(book!.title, isNotEmpty);
          expect(mdChapters.length, greaterThanOrEqualTo(1));
        });

        test('chapter bounds are valid', () {
          for (final c in mdChapters) {
            expect(c.startIndex, greaterThanOrEqualTo(0));
            expect(
              c.endIndex,
              greaterThanOrEqualTo(c.startIndex),
              reason:
                  'Chapter ${c.chapterIndex}: start=${c.startIndex}, end=${c.endIndex}',
            );
          }
        });

        test('chapter titles match H2 headings', () {
          final titles = mdChapters.map((c) => c.title).toList();
          expect(titles.length, 5);
          expect(titles[0], '前言');
          expect(titles[1], '代码块示例');
          expect(titles[2], '中英文混合段落');
          expect(titles[3], '表格示例');
          expect(titles[4], '结语');
        });

        test('paginateChapter produces at least 1 descriptor', () async {
          final result = await core_api.paginateChapter(
            filePath: mdPath,
            chapterIndex: 0,
            config: _defaultConfig(),
          );
          expect(result.descriptors.length, greaterThanOrEqualTo(1));
          for (final d in result.descriptors) {
            expect(d.startOffset, lessThan(d.endOffset));
          }
          expect(result.descriptors.last.isLastPage, isTrue);
        });

        test('paginateAllContent returns non-empty pages', () async {
          final pages = await core_api.paginateAllContent(
            filePath: mdPath,
            chapterIndex: 0,
            config: _defaultConfig(),
          );
          expect(pages.length, greaterThanOrEqualTo(1));
          for (final p in pages) {
            expect(p.content, isNotEmpty);
          }
        });

        test(
          'paginate chapter 1 (代码块示例) contains code block content',
          () async {
            final pages = await core_api.paginateAllContent(
              filePath: mdPath,
              chapterIndex: 1,
              config: _defaultConfig(),
            );
            final allText = pages.map((p) => p.content).join('');
            expect(allText, contains('下面是一个 Python 代码块'));
            expect(allText, contains('def hello'));
            expect(allText, contains('Welcome to the future'));
          },
        );

        test(
          'paginate chapter 2 (中英文混合段落) contains CJK and Latin content',
          () async {
            final pages = await core_api.paginateAllContent(
              filePath: mdPath,
              chapterIndex: 2,
              config: _defaultConfig(),
            );
            final allText = pages.map((p) => p.content).join('');
            expect(allText, contains('敏捷的棕色狐狸'));
            expect(allText, contains('The quick brown fox'));
            expect(allText, contains('删除线'));
          },
        );
      });
    });
  }, skip: !ffiAvailable);
}
