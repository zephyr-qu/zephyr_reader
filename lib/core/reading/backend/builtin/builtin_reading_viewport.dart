import 'package:zephyr_reader/features/reader/core/presentation/reader_content_area.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/core/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/engine.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:flutter/material.dart';

import '../reading_viewport_adapter.dart';

/// Builtin viewport adapter wrapping [ReaderContentArea].
class BuiltinReadingViewport implements ReadingViewportAdapter {
  final ReaderViewModel viewModel;
  final ChapterContentRepository contentRepo;
  final PaginationEngine engine;
  final FontRepository fontRepo;
  final Signal<Set<String>> vocabWords;
  final Signal<Offset?> selectionGlobalPos;
  final ThemeMode themeMode;

  BuiltinReadingViewport({
    required this.viewModel,
    required this.contentRepo,
    required this.engine,
    required this.fontRepo,
    required this.vocabWords,
    required this.selectionGlobalPos,
    required this.themeMode,
  });

  @override
  Widget buildViewport(BuildContext context) {
    return ReaderContentArea(
      vm: viewModel,
      contentRepo: contentRepo,
      engine: engine,
      fontRepo: fontRepo,
      vocabWords: vocabWords,
      selectionGlobalPos: selectionGlobalPos,
      themeMode: themeMode,
    );
  }
}
