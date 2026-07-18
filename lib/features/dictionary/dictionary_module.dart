import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/dictionary/dictionary_config.dart';
import 'package:zephyr_reader/features/dictionary/providers/custom_dictionary.dart';
import 'package:zephyr_reader/features/dictionary/providers/openai_dictionary.dart';
import 'package:zephyr_reader/features/dictionary/dictionary_service.dart';

/// 词典/翻译服务依赖注入模块。
///
/// 根据 [DictionaryConfig.provider] 的值动态绑定相应的翻译适配器。
@module
abstract class DictionaryModule {
  /// 提供词典查询服务实例，按配置选择实现。
  @lazySingleton
  DictionaryService dictionaryService(DictionaryConfig config, Dio dio) {
    return switch (config.provider.value) {
      'custom' => CustomDictionaryTranslator(config, dio) as DictionaryService,
      _ => OpenAIDictionaryTranslator(config, dio) as DictionaryService,
    };
  }
}
