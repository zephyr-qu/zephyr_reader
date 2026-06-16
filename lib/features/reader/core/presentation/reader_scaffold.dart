import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/service/tts_service.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_chrome.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_content_area.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_interaction_layer.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_ui_state.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/navigation/reader_navigation_drawer.dart';
import 'package:zephyr_reader/features/reader/annotations/presentation/reader_note_sidebar.dart';

class ReaderScaffold extends HookWidget {
  const ReaderScaffold({
    super.key,
    required this.vm,
    required this.readRepo,
    required this.fontRepo,
    required this.config,
    required this.ttsService,
    required this.ttsVm,
    required this.uiState,
    required this.tapLayout,
    required this.scaffoldKey,
  });

  final ReaderViewModel vm;
  final ReaderRepository readRepo;
  final FontRepository fontRepo;
  final ReaderConfig config;
  final TtsService ttsService;
  final TtsSettingsViewModel ttsVm;
  final ReaderUiState uiState;
  final TapLayout tapLayout;
  final GlobalKey<ScaffoldState> scaffoldKey;

  @override
  Widget build(BuildContext context) {
    final ReaderTheme bReadertheme = useSignalValue(vm.config.theme.signal);
    final int bBgindex = useSignalValue(vm.config.readerBgColorIndex.signal);
    final String bCurrentbookid = useSignalValue(vm.state.bookId);
    final int bChapterindex = useSignalValue(vm.state.chapterIndex);
    final String bCurrentchaptertitle = useSignalValue(
      vm.chapterManager.currentChapterTitle,
    );

    final themeMode = switch (bReadertheme) {
      ReaderTheme.dark => ThemeMode.dark,
      ReaderTheme.sepia => ThemeMode.light,
      ReaderTheme.light => ThemeMode.light,
    };

    void withTimer(VoidCallback action) {
      uiState.withTimer(context, action);
    }

    final baseTheme = Theme.of(context);
    final readerExt = ReaderThemeExtension.resolve(bReadertheme);
    final readerData = baseTheme.copyWith(
      extensions: [readerExt, ...baseTheme.extensions.values],
    );

    return Theme(
      data: readerData,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final scaffold = scaffoldKey.currentState;
          if (scaffold != null && scaffold.isDrawerOpen) {
            scaffold.closeDrawer();
            return;
          }
          if (scaffold != null && scaffold.isEndDrawerOpen) {
            scaffold.closeEndDrawer();
            return;
          }
          uiState.cancelAutoHideTimer();
          vm.resetForNewBook();
          context.pop();
        },
        child: Scaffold(
          key: scaffoldKey,
          drawerEnableOpenDragGesture: false,
          endDrawerEnableOpenDragGesture: false,
          drawerEdgeDragWidth: 0,
          drawer: ReaderNavigationDrawer(
            chapters: vm.chapterManager.chapters.value.value ?? [],
            currentChapterIndex: bChapterindex,
            onChapterSelected: (idx) {
              vm.chapterManager.jumpToChapter(idx);
            },
            bookmarks: vm.bookmarks.bookmarks.value.value ?? [],
            onBookmarkSelected: (bm) => vm.jumpToBookmark(bm),
            onAddBookmark: () => vm.toggleBookmarkAtCurrentPosition(),
            onDeleteBookmark: (id) => vm.bookmarks.deleteBookmark(id),
            themeMode: themeMode,
            bookId: bCurrentbookid,
          ),
          endDrawer: ReaderNoteSidebar(
            bookId: bCurrentbookid,
            bookTitle: bCurrentchaptertitle,
            vm: vm,
            onNoteTap: (ci, co) => vm.chapterManager.jumpToPosition(ci, co),
          ),
          body: AnimatedContainer(
            duration: AnimTokens.slow,
            curve: Curves.easeInOut,
            color: bReadertheme == ReaderTheme.dark
                ? ReaderBgColors.darkBackground
                : ReaderBgColors.presets[bBgindex.clamp(
                    0,
                    ReaderBgColors.presets.length - 1,
                  )],
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                SafeArea(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ReaderContentArea(
                        vm: vm,
                        dataSource: readRepo,
                        fontRepo: fontRepo,
                        vocabWords: uiState.vocabWords,
                        selectionGlobalPos: uiState.selectionGlobalPos,
                        themeMode: themeMode,
                      ),
                      ReaderBottomChrome(
                        vm: vm,
                        config: config,
                        fontRepo: fontRepo,
                        ttsService: ttsService,
                        ttsVm: ttsVm,
                        uiState: uiState,
                      ),
                      ReaderSelectionToolbarLayer(
                        vm: vm,
                        uiState: uiState,
                      ),
                    ],
                  ),
                ),
                ReaderTopChrome(
                  vm: vm,
                  uiState: uiState,
                  themeMode: themeMode,
                  withTimer: withTimer,
                ),
                ReaderTapZoneLayer(
                  vm: vm,
                  uiState: uiState,
                  tapLayout: tapLayout,
                  withTimer: withTimer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
