import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';

/// Local UI signals and auto-hide timer helpers for the reader shell.
class ReaderUiState {
  ReaderUiState({
    required this.showToolbar,
    required this.activePanel,
    required this.selectionGlobalPos,
    required this.vocabWords,
    required this.autoHideTimer,
  });

  final Signal<bool> showToolbar;
  final Signal<ReaderPanelType?> activePanel;
  final Signal<Offset?> selectionGlobalPos;
  final Signal<Set<String>> vocabWords;
  final ObjectRef<Timer?> autoHideTimer;

  void cancelAutoHideTimer() {
    autoHideTimer.value?.cancel();
  }

  void resetHideTimer(BuildContext context) {
    autoHideTimer.value?.cancel();
    if (!context.mounted) return;
    autoHideTimer.value = Timer(const Duration(seconds: 4), () {
      if (!context.mounted) return;
      if (showToolbar.value && activePanel.value == null) {
        showToolbar.value = false;
      }
    });
  }

  void withTimer(BuildContext context, VoidCallback action) {
    action();
    resetHideTimer(context);
  }
}
