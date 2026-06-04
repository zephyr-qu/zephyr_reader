import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 带自动日志的 try-catch 包装
///
/// 消除 ViewModel 中重复的 try/catch/Logging 模板代码。
/// 返回 null 表示加载失败（调用方按需处理）。
Future<T?> safeLoad<T>(Future<T> Function() loader, {String? label}) async {
  try {
    return await loader();
  } catch (e, stack) {
    Logging.error(label ?? '操作失败', exception: e, stackTrace: stack);
    return null;
  }
}

/// [Signal<AsyncState<T>>] 的安全加载扩展
///
/// 自动处理 loading → data/error 状态转换 + 日志，
/// 消除 ViewModel 中手写的 try/catch 模板。
extension AsyncStateSignalExt<T> on Signal<AsyncState<T>> {
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
