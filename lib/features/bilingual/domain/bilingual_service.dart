import 'package:dio/dio.dart';

/// 翻译结果。
class BilingualResult {
  final String text;
  final String? detectedSourceLang;

  const BilingualResult({required this.text, this.detectedSourceLang});
}

/// 翻译异常，携带用户可读的错误消息。
class BilingualException implements Exception {
  final String message;
  final bool isAuthError;

  const BilingualException(this.message, {this.isAuthError = false});

  @override
  String toString() => 'BilingualException: $message';
}

/// 翻译服务抽象接口。
///
/// 实现类负责调用具体的翻译 API (OpenAI、DeepL、LibreTranslate 等)。
abstract class BilingualService {
  /// 提供商名称（如 "OpenAI"、"Custom"）。
  String get name;

  /// 翻译 [text] 到目标语言 [targetLang]。
  ///
  /// [sourceLang] 为 null 时自动检测源语言。
  /// [cancelToken] 用于取消进行中的请求。
  ///
  /// 抛出 [BilingualException] 表示业务层错误（认证失败、异常响应等）。
  /// 抛出 [DioException] 表示网络层错误（超时、断网等）。
  Future<BilingualResult> translate({
    required String text,
    String? sourceLang,
    required String targetLang,
    CancelToken? cancelToken,
  });
}
