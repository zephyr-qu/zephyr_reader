// test/features/reader/auto_spacing_test.dart
//
// CJK-Latin 自动间距集成测试 — 验证 Rust 排版引擎在不同字体大小
// 和不同语言混合内容下的自动间距行为。
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

import '../../helpers/integration_test_helper.dart';

/// 构建排版配置
TypesetConfig _makeConfig({
  required int fontSize,
  int width = 800,
  int height = 600,
}) {
  return TypesetConfig(
    pageWidth: width,
    pageHeight: height,
    fontSize: fontSize,
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

/// 生成足够长的内容以跨越多个分页
String _longParagraph(String base, {int repeat = 5}) {
  return List.filled(repeat, base).join('\n\n');
}

/// UTF-8 BOM 字符，确保 chardetng 检测 UTF-8
const _utf8Bom = '\uFEFF';

/// 用于区分 CJK 和混合页面数的窄页面配置
TypesetConfig _cjkCompareConfig() {
  return _makeConfig(fontSize: 18, width: 600, height: 500);
}

void main() {
  final ffiAvailable = isFfiAvailable();

  late String mixedFilePath;
  late String pureFilePath;
  late String mixedBookId;
  late String pureBookId;

  setUpAll(() async {
    if (!ffiAvailable) return;
    await setupTestStorage(label: 'autospacing');

    // 混合中英文 fixture — BOM 前缀确保 chardetng 检测 UTF-8
    const mixedBase = '''$_utf8Bom第一章 混合篇章

Morning light streamed through the window as 他睁开双眼，迎接新的一天。
这座城市充满了 contrasts and surprises. 古老的寺庙 stood alongside 摩天大楼,
传统的茶馆里飘散着茶香，而街角的咖啡馆则弥漫着浓郁的 coffee aroma。

他走在街上，耳边传来各种声音：小贩的吆喝声，汽车的喇叭声，还有 tourists
的欢笑声。A symphony of sounds filled the air. 他深深吸了一口气，感受着
这座城市独特的 rhythm and energy。

"这真是一个神奇的地方，" 他自言自语道。Every corner held a new discovery,
every street told a different story. 他掏出手机拍下沿途的风景。

中午时分，他来到一家小餐馆。Menu was written in both Chinese and English.
他点了一碗面条和一杯绿茶。The food was delicious, 每一口都充满了 local flavors。

下午他参观了一座博物馆。Ancient artifacts 与现代科技展品并列陈列，
creating a fascinating dialogue between past and present. 他在一幅古画前
驻足良久，画中的山水意境让他想起了王维的诗句。

傍晚，他登上城市的高处，俯瞰着脚下的万家灯火。The city skyline glittered
like a thousand stars. 他感受到了前所未有的平静与满足。This was the beauty
of cultural fusion, 传统与现代交相辉映的美。

夜深了，他回到住处，在日记本上写道：Today was a day of discoveries.
语言和文化的交融让这个世界变得更加丰富多彩。期待明天的 adventure。''';

    final mixedContent = _longParagraph(mixedBase, repeat: 6);
    mixedFilePath = await createTestFile('mixed_book.txt', mixedContent);
    final mixedParse = await parseTestBook(mixedFilePath);
    mixedFilePath = mixedParse.$2;
    mixedBookId = mixedParse.$1;

    // 纯中文 fixture（同样添加 BOM）
    const pureBase = '''$_utf8Bom第一章 纯中文篇章

清晨的阳光透过窗户洒进房间，他睁开双眼迎接新的一天。这座城市充满了古老与现代的交融，古老的寺庙旁边矗立着现代化的高楼大厦，传统的茶馆里飘散着清新的茶香。

他走在街上，耳边传来各种声音：小贩的吆喝声，汽车的喇叭声，还有行人的欢笑声。各种声音交织在一起，谱写着城市独有的交响乐。他深深吸了一口气，感受着这座城市独特的节奏和活力。

这真是一个神奇的地方。每一个角落都蕴藏着新的发现，每一条街道都诉说着不同的故事。他掏出手机拍下沿途的风景，想要记录下这些美好的瞬间。

中午时分，他来到一家小餐馆。墙上的菜单写满了各种特色菜品。他点了一碗热腾腾的面条和一杯清香的绿茶。食物的美味让他赞不绝口，每一口都充满了地方特色。

下午他参观了一座博物馆。古老的文物和现代的艺术品并排陈列，在古老与现代之间展开了一场引人入胜的对话。他在一幅古画前驻足良久，画中的山水意境让他沉浸在悠远的艺术氛围中。

傍晚，他登上城市的高处，俯瞰着脚下的万家灯火。整个城市像一片璀璨的星海。他感受到了前所未有的平静与满足。这是文化融合的美妙之处，传统与现代交相辉映。

夜深了，他回到住处，在日记本上写下今天的感悟。语言和文化的多样让这个世界变得更加丰富多彩。他期待着明天的旅程，期待着更多的发现和体验。''';

    final pureContent = _longParagraph(pureBase, repeat: 6);
    pureFilePath = await createTestFile('pure_book.txt', pureContent);
    final pureParse = await parseTestBook(pureFilePath);
    pureFilePath = pureParse.$2;
    pureBookId = pureParse.$1;
  });

  tearDownAll(() async {
    if (!ffiAvailable) return;
    await deleteTestBook(mixedBookId);
    await deleteTestBook(pureBookId);
    await teardownTestStorage();
  });

  group('auto-spacing integration tests', () {
    // ==================== Font-size scaling ====================

    group('Font-size scaling', () {
      test('page count increases with larger font size', () async {
        final smallFont = _makeConfig(fontSize: 14);
        final largeFont = _makeConfig(fontSize: 28);
        final smallPages = await core_api.paginateAllContent(
          filePath: mixedFilePath,
          chapterIndex: 0,
          config: smallFont,
        );
        final largePages = await core_api.paginateAllContent(
          filePath: mixedFilePath,
          chapterIndex: 0,
          config: largeFont,
        );
        expect(largePages.length, greaterThan(smallPages.length));
      });

      test('page content is non-empty at different font sizes', () async {
        for (final size in [14, 20, 28]) {
          final pages = await core_api.paginateAllContent(
            filePath: mixedFilePath,
            chapterIndex: 0,
            config: _makeConfig(fontSize: size),
          );
          for (int i = 0; i < pages.length; i++) {
            expect(
              pages[i].content,
              isNotEmpty,
              reason: 'page $i at fontSize=$size is empty',
            );
          }
        }
      });
    });

    // ==================== CJK vs mixed content ====================

    group('CJK vs mixed content', () {
      test(
        'pure CJK and mixed content produce different page layout',
        () async {
          final cfg = _cjkCompareConfig();
          final mixedPages = await core_api.paginateAllContent(
            filePath: mixedFilePath,
            chapterIndex: 0,
            config: cfg,
          );
          final purePages = await core_api.paginateAllContent(
            filePath: pureFilePath,
            chapterIndex: 0,
            config: cfg,
          );
          expect(mixedPages.length, isNot(equals(purePages.length)));
        },
      );
    });

    // ==================== Content cleanliness ====================

    group('Content cleanliness', () {
      test('paginated content preserves original characters', () async {
        final pages = await core_api.paginateAllContent(
          filePath: mixedFilePath,
          chapterIndex: 0,
          config: _makeConfig(fontSize: 16),
        );
        final allText = pages.map((p) => p.content).join('');
        expect(allText, contains('摩天大楼'));
        expect(allText, contains('茶香'));
        expect(allText, contains('cultural fusion'));
        expect(allText, contains('rhythm and energy'));
      });

      test(
        'no artificially inserted spaces within CJK consecutive characters',
        () async {
          final pages = await core_api.paginateAllContent(
            filePath: pureFilePath,
            chapterIndex: 0,
            config: _makeConfig(fontSize: 16),
          );
          final allText = pages.map((p) => p.content).join('');
          expect(allText, contains('城市'));
          expect(allText, contains('故事'));
          expect(allText, contains('清晨'));
          expect(allText, contains('现代'));
          expect(allText, contains('艺术'));
        },
      );
    });
  }, skip: !ffiAvailable);
}
