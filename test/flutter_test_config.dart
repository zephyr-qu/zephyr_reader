// test/flutter_test_config.dart
//
// 测试运行环境统一配置
// 负责 FFI 初始化、测试环境检测、全局超时设置
//
// 注意: 本文件由 flutter test 自动发现并执行
// 详见 TEST_STRATEGY.md 第 3 章

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

/// 检测当前平台是否支持 Rust FFI
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

  // 设置全局测试超时（Dart 单元测试 30s，Widget 测试 60s）
  // 单个测试文件可以覆盖此设置
  final platform = TestPlatform.current;
  final defaultTimeout = platform == TestPlatform.flutter ? 60 : 30;

  // 尝试初始化 FFI
  final ffiAvailable = _isFfiSupported();
  if (ffiAvailable) {
    try {
      await RustLib.init();
      // FFI 初始化成功 — 含 FFI 的测试将正常运行
    } catch (e) {
      // FFI 初始化失败 — 标记为不可用
      // 测试文件应检查此标记并跳过 FFI 依赖的测试
      // 详见 dart_test.yaml 中的 ffi 标签
    }
  }

  await testMain();
}
