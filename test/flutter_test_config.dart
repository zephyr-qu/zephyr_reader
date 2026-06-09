// test/flutter_test_config.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

bool _isFfiSupported() {
  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 确保 Flutter 测试绑定初始化
  TestWidgetsFlutterBinding.ensureInitialized();

  // 设置全局超时（Widget 测试需要更长时间）

  // 设置全局测试超时
  // 注意：这个设置需要通过其他方式实现，TimeOut 是 test 包的配置

  // 尝试初始化 FFI
  final ffiAvailable = _isFfiSupported();
  if (ffiAvailable) {
    try {
      await RustLib.init();
      // FFI 初始化成功
    } catch (e) {
      // FFI 初始化失败，测试会跳过 ffi 标签的测试
    }
  }

  await testMain();
}
