import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';
import 'package:zephyr_reader/features/reader/settings/reader_settings_overlay.dart';

import 'readium_reader_content.dart';
import 'readium_view_model.dart';

/// Readium EPUB reader shell (MVP).
class ReadiumReaderShell extends HookWidget {
  final String filePath;
  final String bookId;

  const ReadiumReaderShell({
    super.key,
    required this.filePath,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    final ReaderConfig config = useMemoized(() => getIt<ReaderConfig>());
    final ReadiumViewModel vm = useMemoized(
      () => ReadiumViewModel(config: config, bookId: bookId),
    );

    final double progress = useSignalValue(vm.progress) as double;
    final String statusText = useSignalValue(vm.status) as String;
    final String bookTitle = useSignalValue(vm.title) as String;
    final List<Link> tocLinks = useSignalValue(vm.tocLinks) as List<Link>;
    final String currentHref = useSignalValue(vm.currentChapterHref) as String;
    final bool isTtsPlaying = useSignalValue(vm.isTtsPlaying) as bool;

    final scaffoldKey = useRef(GlobalKey<ScaffoldState>());

    // Lifecycle — clean up ViewModel resources
    useEffect(() {
      return () {
        unawaited(vm.close());
        vm.dispose();
      };
    }, []);

    final String progressText = progress > 0
        ? '${(progress * 100).toStringAsFixed(0)}%'
        : statusText;

    void showSettings() {
      final ttsVm = getIt<TtsSettingsViewModel>();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ReaderSettingsOverlay(
          panelType: ReaderPanelType.display,
          config: config,
          isTtsPlaying: isTtsPlaying,
          isTtsPaused: false,
          onReadingModeChanged: (_) => vm.applyPreferences(),
          onFontSizeChanged: (_) => vm.applyPreferences(),
          onLineHeightChanged: (_) => vm.applyPreferences(),
          onPageMarginChanged: (_) => vm.applyPreferences(),
          onTtsToggle: () => vm.toggleTts(),
          onClose: () => Navigator.pop(context),
          ttsVm: ttsVm,
          onChanged: () => vm.applyPreferences(),
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey.value,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => scaffoldKey.value.currentState?.openDrawer(),
        ),
        title: Text(bookTitle, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: showSettings,
          ),
          IconButton(
            icon: Icon(
              isTtsPlaying ? Icons.pause : Icons.volume_up,
              color: Colors.white,
            ),
            onPressed: () => vm.toggleTts(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                progressText,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildTocDrawer(context, tocLinks, currentHref, vm),
      body: SafeArea(
        child: ReadiumReaderContent(vm: vm, filePath: filePath),
      ),
    );
  }

  Widget _buildTocDrawer(
    BuildContext context,
    List<Link> links,
    String currentHref,
    ReadiumViewModel vm,
  ) {
    return Drawer(
      child: Column(
        children: [
          Container(
            color: Colors.grey[900],
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '目录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
                final isCurrent =
                    link.href == currentHref || currentHref.contains(link.href);
                return ListTile(
                  title: Text(
                    link.title ?? 'Chapter ${index + 1}',
                    style: TextStyle(
                      color: isCurrent ? Colors.blue : Colors.white,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    vm.goToLink(link);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
