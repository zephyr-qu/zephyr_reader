import 'package:flutter/widgets.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 双语阅读器委托。
///
/// 核心阅读器通过此接口与双语模块交互，不依赖具体实现。
/// [BilingualAlignment] 是 FRB 生成的共享领域类型，允许在此引用。
abstract class BilingualReaderDelegate {
  /// 翻译 API 是否已配置。
  bool get isConfigured;

  /// 双语对齐是否正在加载。
  bool get isBilingualLoading;

  /// 当前双语对齐结果。
  BilingualAlignment? get alignment;

  /// 当前双语错误消息（如有）。
  String? get bilingualError;

  /// 设置翻译内容（用户手动粘贴），同时取消进行中的 API 翻译。
  void setTranslationContent(String content);

  /// 使用配置的翻译 API 翻译当前章节内容。
  Future<void> translateChapter();

  /// 切换到双语模式时的处理逻辑。
  void onEnterBilingualMode();

  /// 构建双语内容组件 — 核心调用此方法，不关心渲染器内部实现。
  /// pairs 由 delegate 内部获取（`BilingualContentShell` 自行调用 `getBilingualHighlightPairs`）。
  Widget buildBilingualContent(
    BuildContext context,
    ScrollController scrollController,
    ReaderRenderConfig config,
    List<Note> highlights,
    void Function(Note) onHighlightTap,
    void Function(String, int, int) onSelectionChanged,
    void Function(Offset?) onSelectionGlobalPosition,
  );

  /// 创建双语对照高亮（同时高亮原文和译文中对应的文本）。
  Future<void> createBilingualHighlight(BilingualHighlightParams params);

  /// 删除与指定笔记关联的双语高亮对（幂等）。
  Future<void> deleteBilingualPair({required String noteId});

  /// 重置所有信号到初始状态，取消进行中的翻译。
  Future<void> reset();
}
