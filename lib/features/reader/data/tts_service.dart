library;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

@lazySingleton
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final isPlaying = signal<bool>(false);
  final isPaused = signal<bool>(false);

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      isPlaying.value = false;
      isPaused.value = false;
    });
    _tts.setErrorHandler((msg) {
      isPlaying.value = false;
      isPaused.value = false;
    });
  }

  Future<void> speak(String text, {double rate = 0.5}) async {
    await stop();
    isPlaying.value = true;
    isPaused.value = false;
    await _tts.setSpeechRate(rate);
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

  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  void dispose() {
    _tts.stop();
  }
}
