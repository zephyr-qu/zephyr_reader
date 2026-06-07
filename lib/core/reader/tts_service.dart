import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

@lazySingleton
/// 文字转语音服务
///
/// 封装 [FlutterTts]，提供朗读、暂停、恢复、停止等控制功能。
/// 支持语速、音调、语言和语音切换，通过 signals 暴露播放状态信号。
class TtsService {

  final FlutterTts _tts = FlutterTts();
  final Completer<void> _ready = Completer<void>();
  final isPlaying = signal<bool>(false);
  final isPaused = signal<bool>(false);
  final currentSpeed = signal<double>(1.0);
  final currentPitch = signal<double>(1.0);
  final currentPauseBetween = signal<int>(300);
  final currentLanguage = signal<String>('zh-CN');

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _tts.setVolume(1.0);
      await _applyRate();
      await _applyPitch();
      _tts.setCompletionHandler(() {
        isPlaying.value = false;
        isPaused.value = false;
      });
      _tts.setErrorHandler((msg) {
        isPlaying.value = false;
        isPaused.value = false;
      });
    } finally {
      _ready.complete();
    }
  }

  Future<void> speak(String text) async {
    await _ready.future;
    await stop();
    isPlaying.value = true;
    isPaused.value = false;
    await _tts.speak(text);
  }

  Future<void> pause() async {
    await _ready.future;
    if (isPlaying.value && !isPaused.value) {
      await _tts.pause();
      isPaused.value = true;
    }
  }

  Future<void> resume() async {
    await _ready.future;
    if (isPlaying.value && isPaused.value) {
      await _tts.speak('');
      isPaused.value = false;
    }
  }

  Future<void> stop() async {
    await _ready.future;
    await _tts.stop();
    isPlaying.value = false;
    isPaused.value = false;
  }

  Future<void> setSpeed(double rate) async {
    await _ready.future;
    currentSpeed.value = rate.clamp(0.5, 2.0);
    await _applyRate();
  }

  double get _normalizedRate => (currentSpeed.value - 0.5) / 1.5;

  Future<void> _applyRate() async {
    await _tts.setSpeechRate(_normalizedRate.clamp(0.0, 1.0));
  }

  Future<void> setPitch(double pitch) async {
    await _ready.future;
    currentPitch.value = pitch.clamp(0.5, 2.0);
    await _applyPitch();
  }

  Future<void> _applyPitch() async {
    await _tts.setPitch(currentPitch.value.clamp(0.5, 2.0));
  }

  Future<void> setLanguage(String lang) async {
    await _ready.future;
    currentLanguage.value = lang;
    await _tts.setLanguage(lang);
  }

  /// 设置语音（通过 `flutter_tts` 的 `setVoice`）。
  /// [voice] 是 [getVoices] 返回的条目，至少需包含 `"name"` 键。
  Future<void> setVoice(Map<String, String> voice) async {
    await _ready.future;
    await _tts.setVoice(voice);
  }

  void setPauseBetween(int ms) {
    currentPauseBetween.value = ms.clamp(0, 1500);
  }

  Future<List<dynamic>> getVoices() async {
    await _ready.future;
    return (await _tts.getVoices) as List<dynamic>? ?? [];
  }

  Future<Set<String>> getLanguages() async {
    await _ready.future;
    final langs = await _tts.getLanguages as List<dynamic>?;
    return {...?langs?.cast<String>()};
  }

  void dispose() {
    _tts.stop();
  }
}
