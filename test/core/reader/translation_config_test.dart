import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('TranslationConfig', () {
    test('default values', () {
      final config = TranslationConfig(prefs);

      expect(config.provider.value, 'openai');
      expect(config.apiUrl.value, 'https://api.openai.com');
      expect(config.apiKey.value, '');
      expect(config.model.value, 'gpt-4o-mini');
      expect(config.targetLang.value, 'zh');
      expect(config.sourceLang.value, 'auto');
      expect(config.timeoutSeconds.value, 30);
    });

    test('isConfigured returns false when apiKey empty', () {
      final config = TranslationConfig(prefs);
      config.apiUrl.value = 'https://api.example.com';
      config.apiKey.value = '';

      expect(config.isConfigured, false);
    });

    test('isConfigured returns false when apiUrl empty', () {
      final config = TranslationConfig(prefs);
      config.apiUrl.value = '';
      config.apiKey.value = 'sk-test-key';

      expect(config.isConfigured, false);
    });

    test('isConfigured returns true when both url and key set', () {
      final config = TranslationConfig(prefs);
      config.apiUrl.value = 'https://api.openai.com';
      config.apiKey.value = 'sk-test-key';

      expect(config.isConfigured, true);
    });

    test('provider can be toggled between openai and custom', () {
      final config = TranslationConfig(prefs);

      config.provider.value = 'custom';
      expect(config.provider.value, 'custom');

      config.provider.value = 'openai';
      expect(config.provider.value, 'openai');
    });

    test('values can be updated and persist in memory', () {
      final config = TranslationConfig(prefs);

      config.apiUrl.value = 'https://custom.api.com';
      config.model.value = 'gpt-4';
      config.targetLang.value = 'en';
      config.sourceLang.value = 'zh';
      config.timeoutSeconds.value = 60;

      expect(config.apiUrl.value, 'https://custom.api.com');
      expect(config.model.value, 'gpt-4');
      expect(config.targetLang.value, 'en');
      expect(config.sourceLang.value, 'zh');
      expect(config.timeoutSeconds.value, 60);
    });
  });
}
