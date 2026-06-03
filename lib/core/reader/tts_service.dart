import 'package:flutter_tts/flutter_tts.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

@lazySingleton
class TtsService {
  final FlutterTts _tts = FlutterTts();
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
  }

  Future<void> speak(String text) async {
    await stop();
    isPlaying.value = true;
    isPaused.value = false;
    await _tts.speak(text);
  }

  Future<void> pause() async {
    if (isPlaying.value && !isPaused.value) {
      await _tts.pause();
      isPaused.value = true;
    }
  }

  Future<void> resume() async {
    if (isPlaying.value && isPaused.value) {
      await _tts.speak('');
      isPaused.value = false;
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    isPlaying.value = false;
    isPaused.value = false;
  }

  Future<void> setSpeed(double rate) async {
    currentSpeed.value = rate.clamp(0.5, 2.0);
    await _applyRate();
  }

  double get _normalizedRate => (currentSpeed.value - 0.5) / 1.5;

  Future<void> _applyRate() async {
    await _tts.setSpeechRate(_normalizedRate.clamp(0.0, 1.0));
  }

  Future<void> setPitch(double pitch) async {
    currentPitch.value = pitch.clamp(0.5, 2.0);
    await _applyPitch();
  }

  Future<void> _applyPitch() async {
    await _tts.setPitch(currentPitch.value.clamp(0.5, 2.0));
  }

  Future<void> setLanguage(String lang) async {
    currentLanguage.value = lang;
    await _tts.setLanguage(lang);
  }

  void setPauseBetween(int ms) {
    currentPauseBetween.value = ms.clamp(0, 1500);
  }

  Future<List<dynamic>> getVoices() async =>
      (await _tts.getVoices) as List<dynamic>? ?? [];

  Future<Set<String>> getLanguages() async {
    final langs = await _tts.getLanguages as List<dynamic>?;
    return {...?langs?.cast<String>()};
  }

  void dispose() {
    _tts.stop();
  }
}
