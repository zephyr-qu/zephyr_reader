import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/service/tts_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_session.dart';
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart';
import 'package:zephyr_reader/features/reader/core/data/pagination_session_factory.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_notice.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_scaffold.dart';
import 'package:zephyr_reader/features/reader/core/presentation/reader_ui_state.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class ReaderShell extends HookWidget {
  const ReaderShell({
    super.key,
    required this.bookId,
    this.initialChapterId = 0,
  });

  final String bookId;
  final int initialChapterId;

  @override
  Widget build(BuildContext context) {
    final session = useMemoized(() => ReaderSessionFactory(
      getIt<ChapterContentRepository>(),
      getIt<ProgressRepository>(),
      getIt<PaginationSessionFactory>(),
      getIt<ReaderConfig>(),
    ).create());
    final vm = session.vm;
    final fontRepo = useMemoized(() => getIt<FontRepository>());
    final readRepo = vm.repo as ReaderRepository;
    final ttsService = useMemoized(() => getIt<TtsService>());
    final config = useMemoized(() => getIt<ReaderConfig>());
    final ttsVm = useMemoized(() => getIt<TtsSettingsViewModel>());
    final TapLayout tapLayout = useSignalValue(config.tapLayout.signal);
    final scaffoldKey = useMemoized(() => GlobalKey<ScaffoldState>());

    final showToolbar = useSignal(false);
    final activePanel = useSignal<ReaderPanelType?>(null);
    final selectionGlobalPos = useSignal<Offset?>(null);
    final vocabWords = useSignal<Set<String>>({});
    final autoHideTimer = useRef<Timer?>(null);

    final uiState = ReaderUiState(
      showToolbar: showToolbar,
      activePanel: activePanel,
      selectionGlobalPos: selectionGlobalPos,
      vocabWords: vocabWords,
      autoHideTimer: autoHideTimer,
    );

    useSignalEffect(() {
      final msg = vm.toastMessage.value;
      if (msg.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
            vm.toastMessage.value = '';
          }
        });
      }
    });

    useSignalEffect(() {
      final notice = vm.chapterManager.readerNotice.value;
      if (notice == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        final message = switch (notice) {
          ReaderNotice.epubRichSkipped => l10n.epubRichTextSkipped,
        };
        vm.toastMessage.value = message;
        vm.chapterManager.readerNotice.value = null;
      });
    });

    useSignalEffect(() {
      vm.chapterManager.updateFont(fontRepo.currentFontFamily);
    });

    useEffect(() {
      _loadVocabularyWords(uiState.vocabWords);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final mq = MediaQuery.of(context);
        vm.chapterManager.pageWidth = mq.size.width;
        vm.chapterManager.pageHeight = mq.size.height - mq.padding.vertical;
        vm.chapterManager.devicePixelRatio = mq.devicePixelRatio;
        vm.chapterManager.updateFont(fontRepo.currentFontFamily);
        vm.initialize(bookId, initialChapterId: initialChapterId);
      });
      return () {
        unawaited(session.dispose());
      };
    }, []);

    useEffect(() {
      return () => uiState.cancelAutoHideTimer();
    }, []);

    return ReaderScaffold(
      vm: vm,
      readRepo: readRepo,
      fontRepo: fontRepo,
      config: config,
      ttsService: ttsService,
      ttsVm: ttsVm,
      uiState: uiState,
      tapLayout: tapLayout,
      scaffoldKey: scaffoldKey,
    );
  }
}

Future<void> _loadVocabularyWords(Signal<Set<String>> out) async {
  final service = getIt<VocabularyMarkerService>();
  await service.ensureLoaded();
  out.value = service.allWords.toSet();
}
