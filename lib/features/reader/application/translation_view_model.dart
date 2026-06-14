import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:dio/dio.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/features/reader/domain/translation_service.dart';
import 'package:zephyr_reader/features/reader/data/translation/translation_cache.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';
import 'reader_page_state.dart';

/// 翻译视图模型。
///
/// 管理翻译 API 调用、双语对齐、双语高亮和翻译缓存。
/// 不持有 ViewModel 引用，所有依赖通过构造注入。
class TranslationViewModel {
  final ReaderPageState _pageState;
  final TranslationConfig _config;
  final TranslationService _service;
  final TranslationCache _cache;
  CancelToken? _cancelToken;

  final bilingualAlignment = asyncSignal<BilingualAlignment?>(
    AsyncState.data(null),
  );
  final translationContent = signal<String>('');

  TranslationViewModel(
    this._pageState,
    this._config,
    this._service,
  ) : _cache = TranslationCache();

  /// 翻译 API 是否已配置。
  bool get isConfigured => _config.isConfigured;

  /// 设置翻译内容（用户手动粘贴），同时取消进行中的 API 翻译。
  void setTranslationContent(String content) {
    _cancelToken?.cancel();
    translationContent.value = content;
    if (_pageState.readingMode.value == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

  /// 切换到双语模式时的处理逻辑。
  void onEnterBilingualMode() {
    if (translationContent.value.isNotEmpty) {
      _runBilingualAlignment();
    } else if (_config.isConfigured) {
      unawaited(translateChapter());
    }
  }

  /// 使用配置的翻译 API 翻译当前章节内容。
  ///
  /// 自动处理: 缓存命中、取消前次请求、错误回退。
  Future<void> translateChapter() async {
    final content = _pageState.chapterContent.value.value ?? '';
    if (content.isEmpty) return;

    final idx = _pageState.chapterIndex.value;

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
        throw const TranslationException('翻译结果为空');
      }

      _cache.put(idx, content, result.text);
      translationContent.value = result.text;
      await _runBilingualAlignment();
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      final msg = _translateErrorMessage(e);
      bilingualAlignment.value = AsyncState.error(TranslationException(msg));
    } on TranslationException catch (e) {
      bilingualAlignment.value = AsyncState.error(e);
    } catch (e) {
      bilingualAlignment.value = AsyncState.error(
        TranslationException('翻译失败: $e'),
      );
    }
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
    final content = _pageState.chapterContent.value.value ?? '';
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

  /// 创建双语对照高亮（同时高亮原文和译文中对应的文本）。
  Future<void> createBilingualHighlight(BilingualHighlightParams params) async {
    await createBilingualHighlightPair(params: params);
  }

  /// 删除与指定笔记关联的双语高亮对（幂等）。
  Future<void> deleteBilingualPair({required String noteId}) async {
    await deleteBilingualHighlightPair(noteId: noteId);
  }

  /// 重置所有信号到初始状态，取消进行中的翻译。
  Future<void> reset() async {
    _cancelToken?.cancel();
    _cancelToken = null;
    _cache.clear();
    translationContent.value = '';
    bilingualAlignment.value = AsyncState.data(null);
  }
}
