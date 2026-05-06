/// Rust 服务辅助工具
///
/// 提供统一的解包和转换辅助函数
library;

/// 在 FFI 桥接层使用的安全扩展
///
/// 用于从 RustOpaque ApiResult 类型中提取内部值。
/// 仅在 Dart↔Rust 桥接层使用，业务代码不应直接调用。
extension RustApiResultX<T> on T {
  /// 通过内部 FFI 通道获取值
  /// 仅在 Rust 服务包装类内部使用
  V unsafeExtract<V>() => (this as dynamic).value as V;
}

/// 解包 Rust ApiResult 的值
T unwrapResult<T>(dynamic result) {
  final value = (result as dynamic).value;
  if (value == null) {
    throw Exception('Rust API returned null');
  }
  return value as T;
}

/// 解包可空的 Rust ApiResult
T? unwrapNullableResult<T>(dynamic result) {
  return (result as dynamic).value as T?;
}

/// 将 int 转换为 BigInt
BigInt toBigInt(int value) {
  return BigInt.from(value);
}
