import 'package:dio/dio.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/dictionary/dictionary_config.dart';
import 'package:zephyr_reader/features/dictionary/dictionary_service.dart';

/// OpenAI-compatible API 翻译适配器。
///
/// 兼容 OpenAI、Azure OpenAI、以及任何 OpenAI 协议兼容的服务。
/// 使用 Chat Completions API（POST /v1/chat/completions）。
class OpenAIDictionaryTranslator implements DictionaryService {
  final DictionaryConfig _config;
  final Dio _dio;

  OpenAIDictionaryTranslator(this._config, this._dio);

  @override
  String get name => 'OpenAI';

  /// 语言代码到完整名称的映射（用于 prompt）
  static const _promptLanguageNames = {
    'zh': 'Chinese',
    'en': 'English',
    'ja': 'Japanese',
    'ko': 'Korean',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ar': 'Arabic',
  };

  String _languageName(String code) {
    return _promptLanguageNames[code] ?? code;
  }

  @override
  Future<DictionaryResult> translate({
    required String text,
    String? sourceLang,
    required String targetLang,
    CancelToken? cancelToken,
  }) async {
    final targetName = _languageName(targetLang);

    // 构建 system prompt
    final systemPrompt = StringBuffer('You are a professional translator.');
    if (sourceLang != null && sourceLang != 'auto') {
      final sourceName = _languageName(sourceLang);
      systemPrompt.write(' Translate from $sourceName to $targetName.');
    } else {
      systemPrompt.write(' Translate the following text to $targetName.');
    }
    systemPrompt.write(
      ' Preserve all paragraph breaks. Return only the translation, no explanations.',
    );
    final response = await _dio.post<dynamic>(
      '${_config.apiUrl.value}/v1/chat/completions',
      options: Options(
        headers: {'Authorization': 'Bearer ${_config.apiKey.value}'},
        sendTimeout: Duration(seconds: _config.timeoutSeconds.value),
        receiveTimeout: Duration(seconds: _config.timeoutSeconds.value),
      ),
      data: {
        'model': _config.model.value,
        'messages': [
          {'role': 'system', 'content': systemPrompt.toString()},
          {'role': 'user', 'content': text},
        ],
        'temperature': 0.1,
      },
      cancelToken: cancelToken,
    );

    final translated = _extractContent(response.data);
    if (translated == null || translated.isEmpty) {
      throw const DictionaryException('API 返回的翻译结果为空');
    }

    return DictionaryResult(text: translated);
  }

  /// 从 Chat Completions 响应中提取文本内容。
  String? _extractContent(dynamic data) {
    try {
      return data['choices']?[0]?['message']?['content'] as String?;
    } catch (e) {
      Logging.warning('翻译响应内容提取失败: $e');
      return null;
    }
  }
}
