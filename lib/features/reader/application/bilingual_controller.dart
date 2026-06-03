import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';

/// 双语对照控制器
///
/// 管理双语对齐结果、翻译内容、加载状态。
/// 对齐计算由 Coordinator 层传入章节内容和译文文本。
@injectable
class BilingualController {
  /// 双语对齐结果
  /// 双语对齐结果
  final bilingualAlignment = asyncSignal<BilingualAlignment?>(
    AsyncState.data(null),
  );

  /// 对照译文内容（由外部设置）
  final translationContent = signal<String>('');

  /// 执行双语对齐
  Future<void> runAlignment(
    String chapterContent,
    String translationContent, {
    double minSimilarity = 0.5,
  }) async {
    if (translationContent.isEmpty) return;
    bilingualAlignment.value = AsyncState.loading();
    try {
      if (chapterContent.isEmpty) return;
      final result = await alignBilingualContent(
        chineseContent: chapterContent,
        englishContent: translationContent,
        minSimilarity: minSimilarity,
      );
      bilingualAlignment.value = AsyncState.data(result);
    } catch (e) {
      bilingualAlignment.value = AsyncState.error(
        Exception('双语对齐失败：$e'),
        StackTrace.current,
      );
    }
  }

  void dispose() {
    bilingualAlignment.dispose();
    translationContent.dispose();
  }
}
