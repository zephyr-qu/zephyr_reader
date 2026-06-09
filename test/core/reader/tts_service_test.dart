import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TtsService service;

  /// Track speak() arguments sent to the platform channel.
  final speakTexts = <String>[];

  setUp(() {
    speakTexts.clear();

    // Mock the flutter_tts platform channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'speak':
              if (methodCall.arguments is String) {
                speakTexts.add(methodCall.arguments as String);
              } else if (methodCall.arguments is Map) {
                speakTexts.add(
                  (methodCall.arguments as Map)['text'] as String? ?? '',
                );
              } else {
                speakTexts.add(methodCall.arguments.toString());
              }
              return null;
            case 'stop':
            case 'pause':
            case 'setVolume':
            case 'setSpeechRate':
            case 'setPitch':
            case 'setLanguage':
            case 'setSilence':
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

    test('voiceName 初始为空', () {
      expect(service.voiceName.value, equals(''));
    });

    test('currentSentenceIndex 初始为 0', () {
      expect(service.currentSentenceIndex.value, equals(0));
    });

    test('currentText 初始为空', () {
      expect(service.currentText.value, equals(''));
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

  group('speak / speakSentences / pause / resume / stop', () {
    test('speak 设置 isPlaying 为 true', () async {
      await service.speak('test');
      expect(service.isPlaying.value, isTrue);
    });

    test('speak 将文本分句后调用 speakSentences', () async {
      await service.speak('Hello world. Goodbye world.');
      expect(service.isPlaying.value, isTrue);
      // speakSentences 只朗读第一句，后续句在 completion 回调后朗读
      expect(speakTexts, contains('Hello world.'));
    });

    test('speakSentences 朗读第一句并设置 currentText', () async {
      await service.speakSentences(['First sentence.', 'Second sentence.']);
      expect(service.isPlaying.value, isTrue);
      expect(service.currentSentenceIndex.value, equals(0));
      expect(service.currentText.value, equals('First sentence.'));
      expect(speakTexts, contains('First sentence.'));
    });

    test('pause 设置 isPaused 为 true', () async {
      await service.speak('test');
      await service.pause();
      expect(service.isPaused.value, isTrue);
      expect(service.isPlaying.value, isTrue);
    });

    test('resume 从中断句子继续朗读（不调用 speak("")）', () async {
      await service.speakSentences(['Hello world.', 'Next sentence.']);
      speakTexts.clear();

      await service.pause();
      expect(service.isPaused.value, isTrue);

      await service.resume();
      expect(service.isPaused.value, isFalse);
      expect(service.isPlaying.value, isTrue);
      // resume 重新朗读当前句子，而不是调用 speak('')
      expect(speakTexts, isNotEmpty);
      expect(speakTexts, contains('Hello world.'));
      expect(speakTexts, isNot(contains('')));
    });

    test('play → pause → resume 完整循环（模拟 _toggleTts 调用模式）', () async {
      // Start (像 _toggleTts 一样调用 speak)
      await service.speak('Hello world.');
      expect(service.isPlaying.value, isTrue);
      expect(service.isPaused.value, isFalse);

      // Pause
      await service.pause();
      expect(service.isPaused.value, isTrue);
      expect(service.isPlaying.value, isTrue);

      // Resume
      await service.resume();
      expect(service.isPaused.value, isFalse);
      expect(service.isPlaying.value, isTrue);
      expect(speakTexts.last, isNot(''));

      // Stop
      await service.stop();
      expect(service.isPlaying.value, isFalse);
      expect(service.isPaused.value, isFalse);
    });
    test('多次调用 resume 安全（非暂停状态不下发）', () async {
      await service.speak('test');
      await service.resume();
      // 非暂停状态 resume 不操作
      expect(service.isPlaying.value, isTrue);
      expect(service.isPaused.value, isFalse);
    });

    test('stop 重置播放状态并清空队列', () async {
      await service.speakSentences(['A.', 'B.', 'C.']);
      await service.stop();
      expect(service.isPlaying.value, isFalse);
      expect(service.isPaused.value, isFalse);
      expect(service.currentSentenceIndex.value, equals(0));
      expect(service.currentText.value, equals(''));
    });

    test('空文本 speakSentences 不操作', () async {
      await service.speakSentences([]);
      expect(service.isPlaying.value, isFalse);
    });
  });

  group('setVoice', () {
    test('设置语音后 voiceName 更新', () async {
      await service.setVoice({'name': 'Google US English', 'locale': 'en-US'});
      expect(service.voiceName.value, equals('Google US English'));
    });

    test('voiceName 在 name 缺失时使用 locale', () async {
      await service.setVoice({'locale': 'zh-CN'});
      expect(service.voiceName.value, equals('zh-CN'));
    });

    test('voiceName 在 name 和 locale 都缺失时为空', () async {
      await service.setVoice(<String, String>{});
      expect(service.voiceName.value, equals(''));
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
