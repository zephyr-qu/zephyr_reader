import 'dart:async';
import 'dart:typed_data';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/epub.dart' as epub_api;
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';

/// EPUB 块图片字节缓存（分页模式）。
///
/// 与 [PageBlocksCache] 的页块元数据预取配合：块预取完成后在此异步解码图片，
/// 避免翻到该页时 [EpubBlockImage] 才首次请求 Rust。
class EpubBlockImageCache {
  final Map<String, Uint8List> _ready = {};
  final Map<String, Future<Uint8List>> _inflight = {};

  static String cacheKey({
    required String filePath,
    required String assetId,
    required int maxWidthPx,
  }) =>
      '$filePath\x00$assetId\x00$maxWidthPx';

  Uint8List? get({
    required String filePath,
    required String assetId,
    required int maxWidthPx,
  }) =>
      _ready[cacheKey(
        filePath: filePath,
        assetId: assetId,
        maxWidthPx: maxWidthPx,
      )];

  Future<Uint8List> load({
    required String filePath,
    required String assetId,
    required int maxWidthPx,
  }) {
    final key = cacheKey(
      filePath: filePath,
      assetId: assetId,
      maxWidthPx: maxWidthPx,
    );
    final cached = _ready[key];
    if (cached != null) return Future.value(cached);

    return _inflight.putIfAbsent(key, () async {
      try {
        final bytes = await Future.microtask(
          () => epub_api.getProcessedEpubImageBytes(
            filePath: filePath,
            assetId: assetId,
            maxWidthPx: maxWidthPx,
          ),
        );
        if (bytes.isEmpty) {
          throw StateError('empty image bytes for asset $assetId');
        }
        _ready[key] = bytes;
        return bytes;
      } finally {
        _inflight.remove(key);
      }
    });
  }

  /// 页块列表中的 Image 切片后台预解码（与 session 滑动窗口同步触发）。
  void prefetchBlocks({
    required String filePath,
    required List<PageBlockSlice> blocks,
    required int maxWidthPx,
  }) {
    if (filePath.isEmpty || maxWidthPx <= 0) return;
    for (final block in blocks) {
      block.when(
        text: (_) {},
        image: (slice) {
          final key = cacheKey(
            filePath: filePath,
            assetId: slice.assetId,
            maxWidthPx: maxWidthPx,
          );
          if (_ready.containsKey(key) || _inflight.containsKey(key)) return;
          unawaited(
            load(
              filePath: filePath,
              assetId: slice.assetId,
              maxWidthPx: maxWidthPx,
            ).catchError((Object e) {
              Logging.debug(
                '[EpubBlockImageCache] prefetch failed asset=${slice.assetId}: $e',
              );
              return Uint8List(0);
            }),
          );
        },
      );
    }
  }

  void clear() {
    _ready.clear();
    _inflight.clear();
  }
}

/// 全局块图片缓存（随 pagination session dispose 清空）。
final epubBlockImageCache = EpubBlockImageCache();
