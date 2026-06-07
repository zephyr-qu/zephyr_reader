/// [Signal<AsyncState<T>>] 的安全加载扩展。
///
/// 为 ViewModel 中的异步加载提供状态管理，自动处理 loading → data/error 状态转换及日志记录。
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// [Signal<AsyncState<T>>] 的安全加载扩展。
///
/// 自动处理 loading → data/error 状态转换 + 日志，
/// 消除 ViewModel 中手写的 try/catch 模板。
extension AsyncStateSignalExt<T> on Signal<AsyncState<T>> {
  /// 安全执行异步加载操作，自动管理 [AsyncState] 状态机。
  ///
  /// [loader] 返回需要加载的数据 Future；
  /// [label] 用于异常日志标记，建议传有辨识度的操作名。
  Future<T?> loadAsync(Future<T> Function() loader, {String? label}) async {
    value = AsyncState<T>.loading();
    try {
      final data = await loader();
      value = AsyncState<T>.data(data);
      return data;
    } catch (e, stack) {
      value = AsyncState<T>.error(e);
      Logging.error(label ?? '数据加载失败', exception: e, stackTrace: stack);
      return null;
    }
  }
}
