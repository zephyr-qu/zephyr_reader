import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/epub_block_image_cache.dart';
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';

void main() {
  group('EpubBlockImageCache', () {
    late int loadCalls;
    late EpubBlockImageCache cache;

    setUp(() {
      loadCalls = 0;
      cache = EpubBlockImageCache(
        loader:
            ({
              required String filePath,
              required String assetId,
              required int maxWidthPx,
            }) async {
              loadCalls++;
              return Uint8List.fromList([maxWidthPx & 0xFF]);
            },
      );
    });

    test(
      'wider cached entry satisfies narrower request without reload',
      () async {
        await cache.load(
          filePath: '/book.epub',
          assetId: 'img1',
          maxWidthPx: 800,
        );
        expect(loadCalls, 1);

        final hit = cache.get(
          filePath: '/book.epub',
          assetId: 'img1',
          maxWidthPx: 400,
        );
        expect(hit, isNotNull);

        await cache.load(
          filePath: '/book.epub',
          assetId: 'img1',
          maxWidthPx: 400,
        );
        expect(loadCalls, 1);
      },
    );

    test('narrower cache triggers reload for wider request', () async {
      await cache.load(
        filePath: '/book.epub',
        assetId: 'img1',
        maxWidthPx: 400,
      );
      expect(loadCalls, 1);

      final bytes = await cache.load(
        filePath: '/book.epub',
        assetId: 'img1',
        maxWidthPx: 800,
      );
      expect(loadCalls, 2);
      expect(bytes.first, 800 & 0xFF);
      expect(
        cache.cachedMaxWidthPx(filePath: '/book.epub', assetId: 'img1'),
        800,
      );
    });

    test(
      'prefetchBlocks skips assets already covered by cache width',
      () async {
        await cache.load(
          filePath: '/book.epub',
          assetId: 'img1',
          maxWidthPx: 600,
        );
        loadCalls = 0;

        cache.prefetchBlocks(
          filePath: '/book.epub',
          maxWidthPx: 400,
          blocks: const [
            PageBlockSlice.image(
              PageImageBlockSlice(
                blockIndex: 0,
                assetId: 'img1',
                layout: ImageBlockLayout.inlineContain,
              ),
            ),
          ],
        );

        await Future<void>.delayed(Duration.zero);
        expect(loadCalls, 0);
      },
    );
  });
}
