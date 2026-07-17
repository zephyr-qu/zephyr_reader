import 'package:flutter/foundation.dart';
import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_key.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';
/// Session 对外发布的原子快照。
///
/// ADR-018：UI 每帧只能看到一个内部一致的不可变计划。
/// 禁止分别暴露可能错配的 IR、descriptors 和 config hash。
@immutable
class LayoutSnapshot {
  final int generation;
  final LayoutKey key;
  final ReaderChapterIr chapter;
  final List<BlockLayout> blocks;
  final List<PagePlan> pages;
  final bool isComplete;

  const LayoutSnapshot({
    required this.generation,
    required this.key,
    required this.chapter,
    this.blocks = const [],
    required this.pages,
    this.isComplete = false,
  });

  int get totalPages => pages.length;
}
