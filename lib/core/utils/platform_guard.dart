import 'dart:io';

Future<T> guardAndroid<T>(Future<T> Function() fn, T defaultValue) async {
  if (!Platform.isAndroid) return defaultValue;
  try {
    return await fn();
  } catch (_) {
    return defaultValue;
  }
}
