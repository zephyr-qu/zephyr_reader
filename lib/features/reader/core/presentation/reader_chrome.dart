import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/service/tts_service.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_tts_helpers.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_ui_state.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';
import 'package:zephyr_reader/features/reader/settings/reader_settings_overlay.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/animated_toolbar_panel.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_toolbar.dart';

/// Top toolbar positioned outside [SafeArea].
class ReaderTopChrome extends HookWidget {
  const ReaderTopChrome({
    super.key,
    required this.vm,
    required this.uiState,
    required this.themeMode,
    required this.withTimer,
  });

  final ReaderViewModel vm;
  final ReaderUiState uiState;
  final ThemeMode themeMode;
  final void Function(VoidCallback action) withTimer;

  @override
  Widget build(BuildContext context) {
    final showToolbar = useSignalValue<bool, Signal<bool>>(uiState.showToolbar);
    final activePanel = useSignalValue<ReaderPanelType?, Signal<ReaderPanelType?>>(
      uiState.activePanel,
    );
    final String bCurrentbookid = useSignalValue(vm.state.bookId);
    final String bCurrentchaptertitle = useSignalValue(
      vm.chapterManager.currentChapterTitle,
    );
    final String bProgresstext = useSignalValue(
      vm.chapterManager.progressText,
    );

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedToolbarPanel(
        visible: showToolbar,
        slideBeginY: -1,
        child: ReaderToolbar(
          title: bCurrentchaptertitle,
          progress: bProgresstext,
          themeMode: themeMode,
          onClose: () {
            vm.resetForNewBook();
            context.pop();
          },
          onToggleToolbar: () =>
              withTimer(() => uiState.showToolbar.value = !showToolbar),
          onSearchBook: () {
            uiState.activePanel.value = null;
            uiState.showToolbar.value = false;
            context.pushNamed(
              AppRoute.bookSearch.name,
              queryParameters: {'bookId': bCurrentbookid},
            );
          },
          onToggleBookmarks: () =>
              withTimer(vm.toggleBookmarkAtCurrentPosition),
          onToggleMore: () => withTimer(() {
            uiState.activePanel.value = activePanel == ReaderPanelType.more
                ? null
                : ReaderPanelType.more;
          }),
        ),
      ),
    );
  }
}

/// Bottom settings overlay and dimmer, placed inside [SafeArea].
class ReaderBottomChrome extends HookWidget {
  const ReaderBottomChrome({
    super.key,
    required this.vm,
    required this.config,
    required this.fontRepo,
    required this.ttsService,
    required this.ttsVm,
    required this.uiState,
  });

  final ReaderViewModel vm;
  final ReaderConfig config;
  final FontRepository fontRepo;
  final TtsService ttsService;
  final TtsSettingsViewModel ttsVm;
  final ReaderUiState uiState;

  @override
  Widget build(BuildContext context) {
    final activePanel = useSignalValue<ReaderPanelType?, Signal<ReaderPanelType?>>(
      uiState.activePanel,
    );
    final ReadingMode bCurrentreadingmode = useSignalValue(
      vm.readingMode,
    );
    final isTtsPlaying = useSignalValue<bool, Signal<bool>>(ttsService.isPlaying);
    final isTtsPaused = useSignalValue<bool, Signal<bool>>(ttsService.isPaused);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (activePanel != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => uiState.activePanel.value = null,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 300) {
                  uiState.activePanel.value = null;
                }
              },
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ),
        AnimatedSlide(
          offset: activePanel != null ? Offset.zero : const Offset(0, 1),
          duration: AnimTokens.slow,
          curve: Curves.easeOut,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: activePanel != null
                ? ReaderSettingsOverlay(
                    panelType: activePanel,
                    config: config,
                    readingMode: bCurrentreadingmode,
                    fontRepo: fontRepo,
                    isTtsPlaying: isTtsPlaying,
                    isTtsPaused: isTtsPaused,
                    onReadingModeChanged: vm.setReadingMode,
                    onFontSizeChanged: vm.setFontSize,
                    onLineHeightChanged: vm.setLineHeight,
                    onPageMarginChanged: (m) => vm.setPageMargin(m),
                    onTtsToggle: () => toggleReaderTts(vm, ttsService),
                    ttsVm: ttsVm,
                    onClose: () => uiState.activePanel.value = null,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
