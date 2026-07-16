import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:zephyr_reader/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/service/tts_service.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_chrome.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_content_area.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_interaction_layer.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_ui_state.dart';
import 'package:zephyr_reader/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/features/reader/navigation/reader_navigation_drawer.dart';
import 'package:zephyr_reader/features/reader/annotations/presentation/reader_note_sidebar.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/animated_toolbar_panel.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_bottom_toolbar.dart';
// ignore: deprecated_member_use — ReaderProgressBar 已废弃，import 保留备查
// import 'package:zephyr_reader/features/reader/page/ui/reader_progress_bar.dart';

class ReaderScaffold extends HookWidget {
  const ReaderScaffold({
    super.key,
    required this.vm,
    required this.fontRepo,
    required this.config,
    required this.ttsService,
    required this.ttsVm,
    required this.uiState,
    required this.tapLayout,
    required this.scaffoldKey,
  });

  final ReaderViewModel vm;
  ChapterContentRepository get _content => vm.contentRepo;
  PaginationSession get _session => vm.session;
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
    final String bCurrentbookid = useSignalValue(vm.chapterManager.bookId);
    final int bChapterindex = useSignalValue(vm.chapterManager.chapterIndex);
    final String bCurrentchaptertitle = useSignalValue(
      vm.chapterManager.currentChapterTitle,
    );
    final bool showToolbar = useSignalValue(uiState.showToolbar);
    final ReaderPanelType? activePanel = useSignalValue(uiState.activePanel);

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
                        contentRepo: _content,
                        session: _session,
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
                      ReaderSelectionToolbarLayer(vm: vm, uiState: uiState),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedToolbarPanel(
                          visible: showToolbar && activePanel == null,
                          slideBeginY: 1,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ReaderProgressBar — 已废弃，底部进度条移除此处
                              // ReaderProgressBar(
                              //   pageIndex: pageIndex,
                              //   totalPages: totalPages,
                              //   onPageChanged: (targetPage) =>
                              //       vm.chapterManager.loadPage(targetPage),
                              // ),
                              ReaderBottomToolbar(
                                onShowCatalog: () =>
                                    scaffoldKey.currentState?.openDrawer(),
                                onShowNotes: () =>
                                    scaffoldKey.currentState?.openEndDrawer(),
                                onToggleTypesetting: () =>
                                    uiState.activePanel.value =
                                        uiState.activePanel.value ==
                                            ReaderPanelType.typesetting
                                        ? null
                                        : ReaderPanelType.typesetting,
                                onToggleDisplay: () =>
                                    uiState.activePanel.value =
                                        uiState.activePanel.value ==
                                            ReaderPanelType.display
                                        ? null
                                        : ReaderPanelType.display,
                                onToggleAssist: () =>
                                    uiState.activePanel.value =
                                        uiState.activePanel.value ==
                                            ReaderPanelType.assist
                                        ? null
                                        : ReaderPanelType.assist,
                              ),
                            ],
                          ),
                        ),
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
