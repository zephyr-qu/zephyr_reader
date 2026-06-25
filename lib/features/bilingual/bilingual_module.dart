import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/bilingual/application/bilingual_config.dart';
import 'package:zephyr_reader/features/bilingual/data/providers/custom_translator.dart';
import 'package:zephyr_reader/features/bilingual/data/providers/openai_translator.dart';
import 'package:zephyr_reader/features/bilingual/domain/bilingual_service.dart';

/// 双语/翻译服务依赖注入模块。
///
/// 根据 [BilingualConfig.provider] 的值动态绑定相应的翻译适配器。
@module
abstract class BilingualModule {
  /// 提供翻译服务实例，按配置选择实现。
  @lazySingleton
  BilingualService bilingualService(BilingualConfig config, Dio dio) {
    return switch (config.provider.value) {
      'custom' => CustomBilingualTranslator(config, dio) as BilingualService,
      _ => OpenAIBilingualTranslator(config, dio) as BilingualService,
    };
  }
}
