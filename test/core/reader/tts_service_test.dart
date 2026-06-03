import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TtsService service;

  setUp(() {
    // Mock the flutter_tts platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'speak':
            case 'stop':
            case 'pause':
            case 'setVolume':
            case 'setSpeechRate':
            case 'setPitch':
            case 'setLanguage':
            case 'setCompletionHandler':
            case 'setErrorHandler':
              return null;
            case 'getVoices':
              return <dynamic>[];
            case 'getLanguages':
              return <dynamic>['zh-CN', 'en-US'];
            default:
              return null;
          }
        });

    service = TtsService();
  });

  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  group('TtsService 初始状态', () {
    test('isPlaying 初始为 false', () {
      expect(service.isPlaying.value, isFalse);
    });

    test('isPaused 初始为 false', () {
      expect(service.isPaused.value, isFalse);
    });

    test('currentSpeed 初始为 1.0', () {
      expect(service.currentSpeed.value, equals(1.0));
    });

    test('currentPitch 初始为 1.0', () {
      expect(service.currentPitch.value, equals(1.0));
    });

    test('currentPauseBetween 初始为 300', () {
      expect(service.currentPauseBetween.value, equals(300));
    });

    test('currentLanguage 初始为 zh-CN', () {
      expect(service.currentLanguage.value, equals('zh-CN'));
    });
  });

  group('setPauseBetween', () {
    test('设置有效值', () {
      service.setPauseBetween(500);
      expect(service.currentPauseBetween.value, equals(500));
    });

    test('负值被钳制为 0', () {
      service.setPauseBetween(-100);
      expect(service.currentPauseBetween.value, equals(0));
    });

    test('超过 1500 被钳制为 1500', () {
      service.setPauseBetween(2000);
      expect(service.currentPauseBetween.value, equals(1500));
    });

    test('边界值 0', () {
      service.setPauseBetween(0);
      expect(service.currentPauseBetween.value, equals(0));
    });

    test('边界值 1500', () {
      service.setPauseBetween(1500);
      expect(service.currentPauseBetween.value, equals(1500));
    });
  });

  group('setSpeed', () {
    test('设置有效速度', () async {
      await service.setSpeed(1.5);
      expect(service.currentSpeed.value, equals(1.5));
    });

    test('低于 0.5 被钳制为 0.5', () async {
      await service.setSpeed(0.1);
      expect(service.currentSpeed.value, equals(0.5));
    });

    test('高于 2.0 被钳制为 2.0', () async {
      await service.setSpeed(3.0);
      expect(service.currentSpeed.value, equals(2.0));
    });
  });

  group('setPitch', () {
    test('设置有效音调', () async {
      await service.setPitch(1.5);
      expect(service.currentPitch.value, equals(1.5));
    });

    test('低于 0.5 被钳制为 0.5', () async {
      await service.setPitch(0.1);
      expect(service.currentPitch.value, equals(0.5));
    });

    test('高于 2.0 被钳制为 2.0', () async {
      await service.setPitch(3.0);
      expect(service.currentPitch.value, equals(2.0));
    });
  });

  group('speak/pause/resume/stop', () {
    test('speak 设置 isPlaying 为 true', () async {
      await service.speak('test');
      expect(service.isPlaying.value, isTrue);
    });

    test('pause 设置 isPaused 为 true', () async {
      await service.speak('test');
      await service.pause();
      expect(service.isPaused.value, isTrue);
      expect(service.isPlaying.value, isTrue);
    });

    test('stop 重置播放状态', () async {
      await service.speak('test');
      await service.stop();
      expect(service.isPlaying.value, isFalse);
      expect(service.isPaused.value, isFalse);
    });
  });

  group('getVoices / getLanguages', () {
    test('getVoices 在无预设语音时返回空列表', () async {
      final voices = await service.getVoices();
      expect(voices, isEmpty);
    });

    test('getLanguages 返回模拟的语言列表', () async {
      final langs = await service.getLanguages();
      expect(langs, contains('zh-CN'));
      expect(langs, contains('en-US'));
    });
  });
}
