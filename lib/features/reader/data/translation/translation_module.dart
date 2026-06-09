import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/domain/translation_service.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';
import 'package:zephyr_reader/features/reader/data/translation/providers/openai_translator.dart';
import 'package:zephyr_reader/features/reader/data/translation/providers/custom_translator.dart';

/// 翻译服务依赖注入模块。
///
/// 根据 [TranslationConfig.provider] 的值动态绑定相应的翻译适配器。
@module
abstract class TranslationModule {
  /// 提供翻译服务实例，按配置选择实现。
  @lazySingleton
  TranslationService translationService(TranslationConfig config, Dio dio) {
    return switch (config.provider.value) {
      'custom' => CustomTranslator(config, dio) as TranslationService,
      _ => OpenAITranslator(config, dio) as TranslationService,
    };
  }
}
