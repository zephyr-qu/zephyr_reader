import 'package:flutter/services.dart';
import 'package:zephyr_reader/features/reader/domain/service/tts_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';

void toggleReaderTts(ReaderViewModel vm, TtsService ttsService) {
  final c = vm.chapterManager.chapterContent.value.value;
  if (c == null || c.isEmpty) return;
  if (ttsService.isPlaying.value && !ttsService.isPaused.value) {
    ttsService.pause();
  } else if (ttsService.isPaused.value) {
    ttsService.resume();
  } else {
    startReaderTts(vm, ttsService);
  }
  HapticFeedback.mediumImpact();
}

void startReaderTts(ReaderViewModel vm, TtsService ttsService) {
  final c = vm.chapterManager.chapterContent.value.value;
  if (c == null || c.isEmpty) return;
  final ttsSettings = getIt<TtsSettingsViewModel>();
  final autoPage = ttsSettings.autoPage.value;
  ttsService.speak(
    c,
    originalOnly: ttsSettings.originalOnly.value,
    bilingualAlternate: ttsSettings.bilingualAlternate.value,
    switchIntervalMs: ttsSettings.switchInterval.value,
    onComplete: autoPage ? () => vm.chapterManager.nextPage() : null,
  );
}
