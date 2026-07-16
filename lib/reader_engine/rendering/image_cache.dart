import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/reader_engine/pagination/packed_page.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as epub_api;

/// 解码 EPUB 图片字节（可注入以便测试）。
typedef EpubImageLoader =
    Future<Uint8List> Function({
      required String filePath,
      required String assetId,
      required int maxWidthPx,
    });

Future<Uint8List> _defaultEpubImageLoader({
  required String filePath,
  required String assetId,
  required int maxWidthPx,
}) => Future.microtask(
  () => epub_api.getProcessedEpubImageBytes(
    filePath: filePath,
    assetId: assetId,
    maxWidthPx: maxWidthPx,
  ),
);

class _ImageCacheEntry {
  const _ImageCacheEntry({required this.maxWidthPx, required this.bytes});

  final int maxWidthPx;
  final Uint8List bytes;
}

/// EPUB 块图片字节缓存（分页模式）。
///
/// 与 [PageBlocksCache] 的页块元数据预取配合：块预取完成后在此异步解码图片，
/// 避免翻到该页时 [EpubBlockImage] 才首次请求 Rust。
///
/// 按 `(filePath, assetId)` 存储已解码字节及对应 `maxWidthPx`；若缓存宽度 ≥
/// 请求宽度则直接命中（Flutter `BoxFit.contain` 可缩小显示），避免 margin /
/// 旋转导致 cache miss。
class EpubBlockImageCache {
  /// 最大缓存图片数；超出时淘汰最久未访问条目。
  static const _maxEntries = 50;

  EpubBlockImageCache({EpubImageLoader? loader})
    : _loader = loader ?? _defaultEpubImageLoader;

  final EpubImageLoader _loader;

  final Map<String, _ImageCacheEntry> _ready = {};
  final Map<String, Future<_ImageCacheEntry>> _inflight = {};
  final List<String> _lru = []; // access-order list for eviction
  int _gen = 0;

  static String assetKey({required String filePath, required String assetId}) =>
      '$filePath\x00$assetId';

  /// 精确宽度键（仅用于合并同宽度并发请求）。
  static String loadKey({
    required String filePath,
    required String assetId,
    required int maxWidthPx,
  }) => '${assetKey(filePath: filePath, assetId: assetId)}\x00$maxWidthPx';

  @visibleForTesting
  int? cachedMaxWidthPx({required String filePath, required String assetId}) =>
      _ready[assetKey(filePath: filePath, assetId: assetId)]?.maxWidthPx;

  Uint8List? get({
    required String filePath,
    required String assetId,
    required int maxWidthPx,
  }) {
    final aKey = assetKey(filePath: filePath, assetId: assetId);
    final entry = _ready[aKey];
    if (entry != null && entry.maxWidthPx >= maxWidthPx) {
      _bumpLru(aKey);
      return entry.bytes;
    }
    return null;
  }

  Future<Uint8List> load({
    required String filePath,
    required String assetId,
    required int maxWidthPx,
  }) async {
    final cached = get(
      filePath: filePath,
      assetId: assetId,
      maxWidthPx: maxWidthPx,
    );
    if (cached != null) return cached;

    final key = loadKey(
      filePath: filePath,
      assetId: assetId,
      maxWidthPx: maxWidthPx,
    );

    final entry = await _inflight.putIfAbsent(key, () async {
      final loadGen = _gen;
      try {
        final bytes = await _loader(
          filePath: filePath,
          assetId: assetId,
          maxWidthPx: maxWidthPx,
        );
        if (bytes.isEmpty) {
          throw StateError('empty image bytes for asset $assetId');
        }
        final result = _ImageCacheEntry(maxWidthPx: maxWidthPx, bytes: bytes);
        // 若 clear() 已发生（gen 递增），跳过存储避免死缓存。
        if (_gen == loadGen) {
          _storeIfBetter(filePath: filePath, assetId: assetId, entry: result);
        }
        return result;
      } finally {
        _inflight.removeWhere((k, _) => k == key);
      }
    });

    if (entry.maxWidthPx >= maxWidthPx) return entry.bytes;
    return get(filePath: filePath, assetId: assetId, maxWidthPx: maxWidthPx) ??
        entry.bytes;
  }

  void _storeIfBetter({
    required String filePath,
    required String assetId,
    required _ImageCacheEntry entry,
  }) {
    final aKey = assetKey(filePath: filePath, assetId: assetId);
    final prev = _ready[aKey];
    if (prev == null || prev.maxWidthPx < entry.maxWidthPx) {
      if (prev == null && _ready.length >= _maxEntries) {
        _evictOne();
      }
      _ready[aKey] = entry;
      _bumpLru(aKey);
    }
  }

  void _bumpLru(String key) {
    _lru.remove(key);
    _lru.add(key);
  }

  void _evictOne() {
    if (_lru.isEmpty) return;
    _ready.remove(_lru.removeAt(0));
  }

  /// 页块列表中的 Image 切片后台预解码（与 session 滑动窗口同步触发）。
  void prefetchBlocks({
    required String filePath,
    required List<PackedBlockSlice> blocks,
    required int maxWidthPx,
  }) {
    if (filePath.isEmpty || maxWidthPx <= 0) return;
    for (final block in blocks) {
      if (!block.isImage) continue;
      if (get(
            filePath: filePath,
            assetId: block.assetId!,
            maxWidthPx: maxWidthPx,
          ) !=
          null) {
        return;
      }
      final key = loadKey(
        filePath: filePath,
        assetId: block.assetId!,
        maxWidthPx: maxWidthPx,
      );
      if (_inflight.containsKey(key)) return;
      unawaited(
        load(
          filePath: filePath,
          assetId: block.assetId!,
          maxWidthPx: maxWidthPx,
        ).catchError((Object e) {
          Logging.debug(
            '[EpubBlockImageCache] prefetch failed asset=${block.assetId}: $e',
          );
          return Uint8List(0);
        }),
      );
    }
  }

  void clear() {
    _ready.clear();
    _inflight.clear();
    _lru.clear();
    _gen++;
  }
}

/// 全局块图片缓存（随 pagination session dispose 清空）。
final epubBlockImageCache = EpubBlockImageCache();
