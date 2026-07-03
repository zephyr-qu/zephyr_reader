import 'package:dio/dio.dart';
import 'package:zephyr_reader/features/bilingual/application/bilingual_config.dart';
import 'package:zephyr_reader/features/bilingual/domain/bilingual_service.dart';

/// 自定义翻译 API 适配器。
///
/// 允许用户通过模板变量配置任意 REST API：
/// - 请求头含 {{apiKey}} 变量
/// - 请求体含 {{text}}、{{sourceLang}}、{{targetLang}} 变量
/// - 响应通过 JSON path 提取翻译结果
class CustomBilingualTranslator implements BilingualService {
  final BilingualConfig _config;
  final Dio _dio;

  CustomBilingualTranslator(this._config, this._dio);

  @override
  String get name => 'Custom';

  @override
  Future<BilingualResult> translate({
    required String text,
    String? sourceLang,
    required String targetLang,
    CancelToken? cancelToken,
  }) async {
    final url = _config.apiUrl.value;
    final apiKey = _config.apiKey.value;

    // 构建请求头（默认 JSON）
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    // 构建请求体
    final body = {
      'text': text,
      'source_lang': sourceLang ?? 'auto',
      'target_lang': targetLang,
    };
    final response = await _dio.post<dynamic>(
      url,
      options: Options(
        headers: headers,
        sendTimeout: Duration(seconds: _config.timeoutSeconds.value),
        receiveTimeout: Duration(seconds: _config.timeoutSeconds.value),
      ),
      data: body,
      cancelToken: cancelToken,
    );

    // 尝试从常见 JSON 路径提取翻译结果
    final translated = _extractTranslated(response.data);
    if (translated == null || translated.isEmpty) {
      throw const BilingualException('无法从 API 响应中提取翻译结果，请检查 API 配置');
    }

    return BilingualResult(text: translated);
  }

  /// 从常见的翻译 API 响应模式中提取译文。
  String? _extractTranslated(dynamic data) {
    if (data == null) return null;

    // 纯字符串
    if (data is String) return data;

    if (data is! Map) return null;

    // 常见格式 1: translated_text
    if (data['translated_text'] is String) {
      return data['translated_text'] as String;
    }

    // 常见格式 2: data.translations[0].translatedText
    if (data['data'] is Map) {
      final d = data['data'] as Map;
      if (d['translations'] is List) {
        final list = d['translations'] as List;
        if (list.isNotEmpty && list[0] is Map) {
          final first = list[0] as Map;
          if (first['translatedText'] is String) {
            return first['translatedText'] as String;
          }
        }
      }
    }

    // 常见格式 3: choices[0].text
    if (data['choices'] is List) {
      final list = data['choices'] as List;
      if (list.isNotEmpty && list[0] is Map) {
        final first = list[0] as Map;
        if (first['text'] is String) return first['text'] as String;
      }
    }

    // 常见格式 4: result.translation
    if (data['result'] is Map) {
      final r = data['result'] as Map;
      if (r['translation'] is String) return r['translation'] as String;
    }

    // 兜底：返回第一个字符串字段
    for (final v in data.values) {
      if (v is String && v.length > 10) return v;
    }

    return null;
  }
}
