import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

@lazySingleton
/// 文字转语音服务
///
/// 封装 [FlutterTts]，提供朗读、暂停、恢复、停止等控制功能。
/// 支持语速、音调、语言和语音切换，通过 signals 暴露播放状态信号。
/// 使用句子队列（[speakSentences]）实现逐句朗读，朗读完一句自动进入下一句。
class TtsService {
  final FlutterTts _tts = FlutterTts();
  final Completer<void> _ready = Completer<void>();
  final isPlaying = signal<bool>(false);
  final isPaused = signal<bool>(false);
  final currentSpeed = signal<double>(1.0);
  final currentPitch = signal<double>(1.0);
  final currentPauseBetween = signal<int>(300);
  final currentLanguage = signal<String>('zh-CN');

  /// 当前语音名称（由 [setVoice] 设置）。
  final voiceName = signal<String>('');

  // ==================== 句子队列状态 ====================

  final _sentenceQueue = <String>[];

  /// 当前正在朗读的句子索引。
  final currentSentenceIndex = signal<int>(0);

  /// 当前正在朗读的句子文本。
  final currentText = signal<String>('');

  bool _bilingualAlternate = false;
  int _switchIntervalMs = 500;
  VoidCallback? _onComplete;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    try {
      await _tts.setVolume(1.0);
      await _applyRate();
      await _applyPitch();
      _tts.setCompletionHandler(_onSentenceComplete);
      _tts.setErrorHandler((msg) {
        isPlaying.value = false;
        isPaused.value = false;
      });
    } finally {
      _ready.complete();
    }
  }

  /// 单句朗读完成回调：自动进入下一句，或标记播放结束。
  Future<void> _onSentenceComplete() async {
    if (_sentenceQueue.isEmpty) {
      isPlaying.value = false;
      isPaused.value = false;
      _onComplete?.call();
      return;
    }
    final nextIndex = currentSentenceIndex.value + 1;
    if (nextIndex < _sentenceQueue.length) {
      currentSentenceIndex.value = nextIndex;
      final pause = _bilingualAlternate && _isSwitchLanguage(
        _sentenceQueue[nextIndex - 1],
        _sentenceQueue[nextIndex],
      )
          ? _switchIntervalMs
          : currentPauseBetween.value;
      await _tts.setSilence(pause);
      await _speakCurrentSentence();
    } else {
      // 队列播完
      isPlaying.value = false;
      isPaused.value = false;
      currentSentenceIndex.value = 0;
      _sentenceQueue.clear();
      _onComplete?.call();
    }
  }

  /// 朗读当前索引位置的句子。
  Future<void> _speakCurrentSentence() async {
    if (_sentenceQueue.isEmpty ||
        currentSentenceIndex.value >= _sentenceQueue.length) {
      isPlaying.value = false;
      isPaused.value = false;
      return;
    }
    final text = _sentenceQueue[currentSentenceIndex.value];
    currentText.value = text;
    await _tts.speak(text);
  }

  /// 向后兼容的单文本朗读入口：自动分句后委托给 [speakSentences]。
  ///
  /// [originalOnly] — 仅朗读原文（跳过翻译句子，基于 CJK 字符检测）。
  /// [bilingualAlternate] — 语言切换时插入额外停顿。
  /// [switchIntervalMs] — 语言切换停顿毫秒数（仅 [bilingualAlternate] 时生效）。
  /// [onComplete] — 队列全部朗读完毕后的回调。
  Future<void> speak(
    String text, {
    bool originalOnly = false,
    bool bilingualAlternate = false,
    int switchIntervalMs = 500,
    VoidCallback? onComplete,
  }) async {
    await _ready.future;
    await stop();
    final sentences = _splitSentences(text);
    await speakSentences(
      sentences,
      originalOnly: originalOnly,
      bilingualAlternate: bilingualAlternate,
      switchIntervalMs: switchIntervalMs,
      onComplete: onComplete,
    );
  }

  /// 朗读句子列表。暂停后调用 [resume] 可从中断句子继续。
  ///
  /// [originalOnly] — 仅朗读原文（跳过翻译句子，基于 CJK 字符检测）。
  /// [bilingualAlternate] — 语言切换时插入额外停顿。
  /// [switchIntervalMs] — 语言切换停顿毫秒数（仅 [bilingualAlternate] 时生效）。
  /// [onComplete] — 队列全部朗读完毕后的回调。
  Future<void> speakSentences(
    List<String> sentences, {
    bool originalOnly = false,
    bool bilingualAlternate = false,
    int switchIntervalMs = 500,
    VoidCallback? onComplete,
  }) async {
    await _ready.future;
    await stop();
    if (sentences.isEmpty) return;

    var filtered = sentences;
    if (originalOnly) {
      filtered = _filterOriginalOnly(sentences);
    }
    if (filtered.isEmpty) return;

    _sentenceQueue
      ..clear()
      ..addAll(filtered);
    currentSentenceIndex.value = 0;
    _bilingualAlternate = bilingualAlternate;
    _switchIntervalMs = switchIntervalMs.clamp(200, 1500);
    _onComplete = onComplete;
    isPlaying.value = true;
    isPaused.value = false;
    await _speakCurrentSentence();
  }

  /// 检测字符串是否包含 CJK 字符。
  static bool _isCjk(String text) {
    return text.runes.any((r) =>
        (r >= 0x4E00 && r <= 0x9FFF) || // CJK 统一表意文字
        (r >= 0x3400 && r <= 0x4DBF)); // CJK 扩展 A
  }

  /// 判断前后两句是否发生了语言切换。
  bool _isSwitchLanguage(String prev, String next) {
    return _isCjk(prev) != _isCjk(next);
  }

  /// 过滤掉翻译语言句子，仅保留原文。
  ///
  /// 当句子内容以 CJK 字符为主时判定为中文，否则判定为英文。
  /// 在双语内容中，保留英文句子作为"原文"。
  List<String> _filterOriginalOnly(List<String> sentences) {
    return sentences.where((s) => !_isCjk(s)).toList();
  }

  /// 将文本按句末标点切分为句子列表。
  /// 先按双换行切分段落，再按句末标点（.!?。！？）+ 空白切分句子。
  /// 单句最长 500 字符，超长则暴力截断。
  List<String> _splitSentences(String text) {
    if (text.isEmpty) return [];

    // 先按双换行切分段
    final paragraphs = text.split(RegExp(r'\n{2,}'));

    final sentences = <String>[];
    for (final part in paragraphs) {
      if (part.trim().isEmpty) continue;

      final trimmed = part.trim();
      final buffer = StringBuffer();

      for (int i = 0; i < trimmed.length; i++) {
        buffer.write(trimmed[i]);
        if ((trimmed[i] == '.' ||
                trimmed[i] == '!' ||
                trimmed[i] == '?' ||
                trimmed[i] == '。' ||
                trimmed[i] == '！' ||
                trimmed[i] == '？') &&
            (i + 1 >= trimmed.length ||
                trimmed[i + 1] == ' ' ||
                trimmed[i + 1] == '\t')) {
          final sentence = buffer.toString().trim();
          buffer.clear();
          if (sentence.isNotEmpty) sentences.add(sentence);
          // 跳过标点后的空白
          while (i + 1 < trimmed.length &&
              (trimmed[i + 1] == ' ' || trimmed[i + 1] == '\t')) {
            i++;
          }
        }
      }

      final remaining = buffer.toString().trim();
      if (remaining.isNotEmpty) sentences.add(remaining);
    }

    if (sentences.isEmpty) return [text];

    // 单句不超过 500 字符
    final result = <String>[];
    for (final s in sentences) {
      if (s.length > 500) {
        for (int i = 0; i < s.length; i += 500) {
          result.add(s.substring(i, (i + 500).clamp(0, s.length)));
        }
      } else {
        result.add(s);
      }
    }

    return result;
  }

  Future<void> pause() async {
    await _ready.future;
    if (isPlaying.value && !isPaused.value) {
      await _tts.pause();
      isPaused.value = true;
    }
  }

  /// 恢复朗读。从中断的句子重新朗读（非跳过）。
  Future<void> resume() async {
    await _ready.future;
    if (isPaused.value && _sentenceQueue.isNotEmpty) {
      isPaused.value = false;
      await _speakCurrentSentence();
    }
  }

  Future<void> stop() async {
    await _ready.future;
    await _tts.stop();
    _sentenceQueue.clear();
    currentSentenceIndex.value = 0;
    currentText.value = '';
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
    voiceName.value = voice['name'] ?? voice['locale'] ?? '';
  }

  /// 设置句间停顿（毫秒）。
  /// 同时调用 [_tts.setSilence] 将停顿时长下发至平台层（Android）。
  void setPauseBetween(int ms) {
    currentPauseBetween.value = ms.clamp(0, 1500);
    _tts.setSilence(ms);
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
