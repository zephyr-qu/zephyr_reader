import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:zephyr_reader/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/settings/assist_panel.dart';
import 'package:zephyr_reader/features/reader/settings/display_panel.dart';
import 'package:zephyr_reader/features/reader/settings/more_panel.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/features/reader/settings/typesetting_panel.dart';

/// 阅读器设置浮层面板。
///
/// 根据 [panelType] 展示不同功能区块，替代原来单一臃肿的设置面板。
class ReaderSettingsOverlay extends StatelessWidget {
  final ReaderPanelType panelType;
  final ReaderConfig config;
  final ReadingMode readingMode;
  final bool isTtsPlaying;
  final bool isTtsPaused;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onPageMarginChanged;
  final VoidCallback onTtsToggle;
  final VoidCallback onClose;
  final FontRepository fontRepo;
  final TtsSettingsViewModel ttsVm;

  const ReaderSettingsOverlay({
    super.key,
    required this.panelType,
    required this.config,
    required this.readingMode,
    required this.isTtsPlaying,
    required this.isTtsPaused,
    required this.onReadingModeChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onPageMarginChanged,
    required this.onTtsToggle,
    required this.onClose,
    required this.ttsVm,
    required this.fontRepo,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: readerTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHandle(theme: readerTheme, onClose: onClose),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  switch (panelType) {
                    ReaderPanelType.typesetting => TypesettingPanel(
                      config: config,
                      readingMode: readingMode,
                      fontRepo: fontRepo,
                      onFontSizeChanged: onFontSizeChanged,
                      onLineHeightChanged: onLineHeightChanged,
                      onPageMarginChanged: onPageMarginChanged,
                      onReadingModeChanged: onReadingModeChanged,
                    ),
                    ReaderPanelType.display => DisplayPanel(config: config),
                    ReaderPanelType.more => MorePanel(config: config),
                    ReaderPanelType.assist => AssistPanel(
                      config: config,
                      ttsVm: ttsVm,
                      isTtsPlaying: isTtsPlaying,
                      isTtsPaused: isTtsPaused,
                      onTtsToggle: onTtsToggle,
                    ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
