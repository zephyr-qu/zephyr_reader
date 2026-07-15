import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/domain/stats/models.dart';


/// 个人中心 ViewModel。
///
/// 管理全局阅读统计和生词统计的异步加载。
class ProfileViewModel {
  final globalStats = asyncSignal<GlobalStats?>(AsyncState.loading());

  ProfileViewModel();

  /// 加载全局阅读统计和生词统计。
  Future<void> loadStats() async {
    await Future.wait([
      globalStats.loadAsync(
        () => stats_api.getGlobalReadingStats(),
        label: 'globalStats',
      ),
    ]);
  }

  /// 释放所有 signal 资源。
  void dispose() {
    globalStats.dispose();
  }
}
