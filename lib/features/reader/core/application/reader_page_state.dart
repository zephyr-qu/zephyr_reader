import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';

/// 阅读器页面级共享状态。
///
/// 持有多个子 ViewModel 共同消费的 page-level signals。
/// 由 ReaderViewModel 创建（constructor），在 resetForNewBook 时 reset。
class ReaderPageState {
  final bookId = signal<String>('');
  final chapterIndex = signal<int>(0);
  final currentCharOffset = signal<int>(0);
  final chapterContent = asyncSignal<String>(AsyncState.data(''));
  final readingMode = signal<ReadingMode>(ReadingMode.pagination);
  final pendingJumpCharOffset = signal<int?>(null);

  /// 重置所有信号到默认值（在两个 book session 之间调用）。
  void reset() {
    bookId.value = '';
    chapterIndex.value = 0;
    currentCharOffset.value = 0;
    chapterContent.value = AsyncState.data('');
    readingMode.value = ReadingMode.pagination;
    pendingJumpCharOffset.value = null;
  }
}
