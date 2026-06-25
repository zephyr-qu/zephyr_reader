import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:dio/dio.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/domain/bilingual_reader_delegate.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/bilingual/application/bilingual_config.dart';
import 'package:zephyr_reader/features/bilingual/data/bilingual_cache.dart';
import 'package:zephyr_reader/features/bilingual/domain/bilingual_service.dart';
import 'package:zephyr_reader/features/bilingual/presentation/bilingual_content_shell.dart';
import 'package:zephyr_reader/di/service_locator.dart';

/// 双语视图模型。
///
/// 管理翻译 API 调用、双语对齐、双语高亮和翻译缓存。
/// 从 [ChapterViewModel] 读取 chapterIndex/chapterContent。
/// 实现 [BilingualReaderDelegate] 供核心阅读器调用。
@injectable
class BilingualViewModel implements BilingualReaderDelegate {
  final ChapterViewModel _chapterVM;
  final BilingualConfig _config;
  final BilingualService _service;
  final BilingualCache _cache = BilingualCache();
  CancelToken? _cancelToken;

  final bilingualAlignment = asyncSignal<BilingualAlignment?>(
    AsyncState.data(null),
  );
  final translationContent = signal<String>('');

  BilingualViewModel(
    @factoryParam ChapterViewModel chapterVM, {
    BilingualConfig? config,
    BilingualService? service,
  }) : _chapterVM = chapterVM,
       _config = config ?? getIt<BilingualConfig>(),
       _service = service ?? getIt<BilingualService>();

  // ==================== BilingualReaderDelegate ====================

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  bool get isBilingualLoading => bilingualAlignment.value.isLoading;

  @override
  BilingualAlignment? get alignment => bilingualAlignment.value.value;

  @override
  String? get bilingualError {
    final err = bilingualAlignment.value.error;
    if (err == null) return null;
    return err is BilingualException ? err.message : err.toString();
  }

  @override
  void setTranslationContent(String content) {
    _cancelToken?.cancel();
    // 直接调对齐（无论当前阅读模式 — 上层决定是否需要切换到 bilingual 模式展示）
    _runBilingualAlignment();
  }

  @override
  void onEnterBilingualMode() {
    if (translationContent.value.isNotEmpty) {
      _runBilingualAlignment();
    } else if (_config.isConfigured) {
      unawaited(translateChapter());
    }
  }

  @override
  Future<void> translateChapter() async {
    final content = _chapterVM.chapterContent.value.value ?? '';
    if (content.isEmpty) return;

    final idx = _chapterVM.chapterIndex.value;

    // 缓存命中
    final cached = _cache.get(idx, content);
    if (cached != null) {
      translationContent.value = cached;
      await _runBilingualAlignment();
      return;
    }

    // 取消前次翻译
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    bilingualAlignment.value = AsyncState.loading();

    try {
      final result = await _service.translate(
        text: content,
        sourceLang: _config.sourceLang.value == 'auto'
            ? null
            : _config.sourceLang.value,
        targetLang: _config.targetLang.value,
        cancelToken: _cancelToken,
      );

      if (_cancelToken?.isCancelled ?? false) return;

      if (result.text.isEmpty) {
        throw const BilingualException('翻译结果为空');
      }

      _cache.put(idx, content, result.text);
      translationContent.value = result.text;
      await _runBilingualAlignment();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      final msg = _translateErrorMessage(e);
      bilingualAlignment.value = AsyncState.error(BilingualException(msg));
    } on BilingualException catch (e) {
      bilingualAlignment.value = AsyncState.error(e);
    } catch (e) {
      bilingualAlignment.value = AsyncState.error(
        BilingualException('翻译失败: $e'),
      );
    }
  }

  @override
  Widget buildBilingualContent(
    BuildContext context,
    ScrollController scrollController,
    ReaderRenderConfig config,
    List<Note> highlights,
    void Function(Note) onHighlightTap,
    void Function(String, int, int) onSelectionChanged,
    void Function(Offset?) onSelectionGlobalPosition,
  ) {
    return BilingualContentShell(
      delegate: this,
      scrollController: scrollController,
      config: config,
      highlights: highlights,
      onHighlightTap: onHighlightTap,
      onSelectionChanged: onSelectionChanged,
      onSelectionGlobalPosition: onSelectionGlobalPosition,
    );
  }

  /// 将 Dio 异常转为用户可读的错误消息。
  String _translateErrorMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout => '连接超时，请检查网络或 API 地址',
      DioExceptionType.receiveTimeout => '响应超时，请检查 API 地址或延长超时',
      DioExceptionType.connectionError => '无法连接服务器，请检查网络',
      DioExceptionType.badResponse => switch (e.response?.statusCode) {
        401 => 'API 密钥无效，请检查设置',
        403 => 'API 密钥无权限',
        429 => '请求过于频繁，请稍后重试',
        _ => '服务端错误 (${e.response?.statusCode})',
      },
      _ => '网络请求失败: ${e.message}',
    };
  }

  /// 运行双语对齐（将原文与译文按段落对齐）。
  Future<void> _runBilingualAlignment() async {
    final content = _chapterVM.chapterContent.value.value ?? '';
    final translation = translationContent.value;
    if (translation.isEmpty) return;
    await bilingualAlignment.loadAsync(
      () => alignBilingualContent(
        chineseContent: content,
        englishContent: translation,
        minSimilarity: 0.5,
      ),
      label: '双语对齐',
    );
  }

  @override
  Future<void> createBilingualHighlight(BilingualHighlightParams params) async {
    await createBilingualHighlightPair(params: params);
  }

  /// 删除与指定笔记关联的双语高亮对（幂等）。
  @override
  Future<void> deleteBilingualPair({required String noteId}) async {
    await deleteBilingualHighlightPair(noteId: noteId);
  }

  /// 重置所有信号到初始状态，取消进行中的翻译。
  @override
  Future<void> reset() async {
    _cancelToken?.cancel();
    _cancelToken = null;
    _cache.clear();
    translationContent.value = '';
    bilingualAlignment.value = AsyncState.data(null);
  }
}
