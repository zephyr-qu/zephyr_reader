library;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isPlaying = false;
  bool _isPaused = false;

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      _isPaused = false;
    });
    _tts.setErrorHandler((msg) {
      _isPlaying = false;
      _isPaused = false;
    });
  }

  Future<void> speak(String text, {double rate = 0.5}) async {
    await stop();
    _isPlaying = true;
    _isPaused = false;
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  Future<void> pause() async {
    if (_isPlaying && !_isPaused) {
      await _tts.pause();
      _isPaused = true;
    }
  }

  Future<void> resume() async {
    if (_isPlaying && _isPaused) {
      await _tts.speak('');
      _isPaused = false;
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    _isPlaying = false;
    _isPaused = false;
  }

  Future<void> setRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  void dispose() {
    _tts.stop();
  }
}
