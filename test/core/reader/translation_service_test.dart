import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/reader/data/translation/providers/openai_translator.dart';
import 'package:zephyr_reader/features/reader/data/translation/providers/custom_translator.dart';
import 'package:zephyr_reader/features/reader/domain/translation_service.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';

class MockDio extends Mock implements Dio {}

class MockCancelToken extends Mock implements CancelToken {}

void main() {
  late TranslationConfig config;
  late MockDio mockDio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    config = TranslationConfig(SharedPreferencesService(prefs));
    config.apiKey.value = 'sk-test-key';
    mockDio = MockDio();
  });

  group('OpenAITranslator', () {
    test('translates text successfully', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'choices': [
              {
                'message': {'content': '你好世界'},
              },
            ],
          },
          statusCode: 200,
        ),
      );

      final translator = OpenAITranslator(config, mockDio);
      final result = await translator.translate(
        text: 'Hello World',
        sourceLang: 'en',
        targetLang: 'zh',
      );

      expect(result.text, '你好世界');
    });

    test('throws TranslationException when response is empty', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'choices': [
              {
                'message': {'content': ''},
              },
            ],
          },
          statusCode: 200,
        ),
      );

      final translator = OpenAITranslator(config, mockDio);

      expect(
        () => translator.translate(text: 'Hi', targetLang: 'zh'),
        throwsA(isA<TranslationException>()),
      );
    });

    test('forwards cancelToken to Dio', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'choices': [
              {
                'message': {'content': '你好'},
              },
            ],
          },
          statusCode: 200,
        ),
      );

      final cancelToken = CancelToken();
      final translator = OpenAITranslator(config, mockDio);
      await translator.translate(
        text: 'Hi',
        targetLang: 'zh',
        cancelToken: cancelToken,
      );

      verify(
        () => mockDio.post<dynamic>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
          cancelToken: cancelToken,
        ),
      ).called(1);
    });

    test('name is OpenAI', () {
      final translator = OpenAITranslator(config, mockDio);
      expect(translator.name, 'OpenAI');
    });
  });

  group('CustomTranslator', () {
    test('translates text with translated_text response', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {'translated_text': '你好世界'},
          statusCode: 200,
        ),
      );

      final translator = CustomTranslator(config, mockDio);
      final result = await translator.translate(
        text: 'Hello World',
        targetLang: 'zh',
      );

      expect(result.text, '你好世界');
    });

    test('handles data.translations[0].translatedText format', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {
            'data': {
              'translations': [
                {'translatedText': 'Bonjour'},
              ],
            },
          },
          statusCode: 200,
        ),
      );

      final translator = CustomTranslator(config, mockDio);
      final result = await translator.translate(
        text: 'Hello',
        sourceLang: 'en',
        targetLang: 'fr',
      );

      expect(result.text, 'Bonjour');
    });

    test('throws when response has unknown format', () async {
      when(
        () => mockDio.post<dynamic>(
          any(),
          options: any(named: 'options'),
          data: any(named: 'data'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: ''),
          data: {'status': 'ok'},
          statusCode: 200,
        ),
      );

      final translator = CustomTranslator(config, mockDio);

      expect(
        () => translator.translate(text: 'Hello', targetLang: 'zh'),
        throwsA(isA<TranslationException>()),
      );
    });

    test('name is Custom', () {
      final translator = CustomTranslator(config, mockDio);
      expect(translator.name, 'Custom');
    });
  });
}
