import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_bottom_toolbar.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_toolbar.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';
import 'package:zephyr_reader/features/reader/settings/reader_settings_overlay.dart';

import 'readium_reader_content.dart';
import 'readium_view_model.dart';

/// Readium EPUB reader shell (MVP).
class ReadiumReaderShell extends HookWidget {
  final String filePath;
  final String bookId;
  final int initialChapterIndex;

  const ReadiumReaderShell({
    super.key,
    required this.filePath,
    required this.bookId,
    this.initialChapterIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final ReaderConfig config = useMemoized(() => getIt<ReaderConfig>());
    final ReaderTheme selectedTheme =
        useSignalValue(config.theme.signal) as ReaderTheme;
    final readerTheme = ReaderThemeExtension.resolve(selectedTheme);
    final ReadiumViewModel vm = useMemoized(
      () => ReadiumViewModel(
        config: config,
        bookId: bookId,
        initialChapterIndex: initialChapterIndex,
      ),
      [bookId, initialChapterIndex],
    );

    final double progress = useSignalValue(vm.progress) as double;
    final String statusText = useSignalValue(vm.status) as String;
    final String bookTitle = useSignalValue(vm.title) as String;
    final List<Link> tocLinks = useSignalValue(vm.tocLinks) as List<Link>;
    final String currentHref = useSignalValue(vm.currentChapterHref) as String;
    final bool isTtsPlaying = useSignalValue(vm.isTtsPlaying) as bool;
    final bool isHighlighted = useSignalValue(vm.isHighlighted) as bool;
    final ReadingMode readingMode =
        useSignalValue(vm.readingMode) as ReadingMode;
    final String? errorMessage = useSignalValue(vm.error) as String?;

    final scaffoldKey = useRef(GlobalKey<ScaffoldState>());
    final chromeVisible = useState(true);

    // Lifecycle — clean up ViewModel resources
    useEffect(() {
      return () {
        unawaited(vm.close());
      };
    }, []);

    final String progressText = progress > 0 || statusText == 'ready'
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : statusText;

    void showSettings(ReaderPanelType panelType) {
      final ttsVm = getIt<TtsSettingsViewModel>();
      final baseTheme = Theme.of(context);
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Theme(
          data: baseTheme.copyWith(extensions: [readerTheme]),
          child: ReaderSettingsOverlay(
            panelType: panelType,
            config: config,
            readingMode: readingMode,
            onReadingModeChanged: (mode) => unawaited(vm.setReadingMode(mode)),
            isTtsPlaying: isTtsPlaying,
            onTtsToggle: () => unawaited(vm.toggleTts()),
            onClose: () => Navigator.pop(context),
            ttsVm: ttsVm,
            onPreferencesChanged: () => unawaited(vm.applyPreferences()),
          ),
        ),
      );
    }

    final isDark = selectedTheme == ReaderTheme.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: chromeVisible.value
            ? readerTheme.surfaceColor
            : readerTheme.backgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: chromeVisible.value
            ? readerTheme.surfaceColor
            : readerTheme.backgroundColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        key: scaffoldKey.value,
        backgroundColor: readerTheme.backgroundColor,
        drawer: _buildTocDrawer(
          context,
          tocLinks,
          currentHref,
          vm,
          readerTheme,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: ReadiumReaderContent(
                  vm: vm,
                  filePath: filePath,
                  onViewportTap: () {
                    chromeVisible.value = !chromeVisible.value;
                  },
                ),
              ),
            ),
            if (chromeVisible.value)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ReaderToolbar(
                  title: bookTitle,
                  progress: progressText,
                  readerTheme: readerTheme,
                  onClose: () => Navigator.maybePop(context),
                ),
              ),
            if (chromeVisible.value)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ReaderBottomToolbar(
                  readerTheme: readerTheme,
                  onShowCatalog: () =>
                      scaffoldKey.value.currentState?.openDrawer(),
                  onToggleTypesetting: () =>
                      showSettings(ReaderPanelType.typesetting),
                  onToggleDisplay: () => showSettings(ReaderPanelType.display),
                  onToggleAssist: () => showSettings(ReaderPanelType.assist),
                  onToggleHighlight: () => unawaited(vm.toggleHighlight()),
                  isTtsPlaying: isTtsPlaying,
                  isHighlighted: isHighlighted,
                ),
              ),
            if (errorMessage != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: chromeVisible.value ? 84 : 16,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      errorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTocDrawer(
    BuildContext context,
    List<Link> links,
    String currentHref,
    ReadiumViewModel vm,
    ReaderThemeExtension readerTheme,
  ) {
    return Drawer(
      backgroundColor: readerTheme.backgroundColor,
      child: Column(
        children: [
          Container(
            color: readerTheme.surfaceColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '目录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: readerTheme.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: links.length,
              itemBuilder: (context, index) {
                final link = links[index];
                final isCurrent = _sameResource(link.href, currentHref);
                return ListTile(
                  selected: isCurrent,
                  selectedTileColor: readerTheme.accentColor.withValues(
                    alpha: 0.1,
                  ),
                  title: Text(
                    link.title ?? 'Chapter ${index + 1}',
                    style: TextStyle(
                      color: isCurrent
                          ? readerTheme.accentColor
                          : readerTheme.textColor,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(vm.goToLink(link));
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameResource(String left, String right) {
    if (left.isEmpty || right.isEmpty) return false;
    final leftUri = Uri.tryParse(left);
    final rightUri = Uri.tryParse(right);
    return (leftUri?.path ?? left) == (rightUri?.path ?? right);
  }
}
