import 'package:flutter/material.dart';

// test_driver/pages/reader_page.dart
//
// ReaderPage Page Object — 封装阅读页面的操作与查找逻辑
//
// 用于 E2E 和集成测试，隐藏 WidgetTester 选择器细节

import 'package:flutter_test/flutter_test.dart';

class ReaderPageObject {
  final WidgetTester tester;

  ReaderPageObject(this.tester);

  // ── 等待页面就绪 ──

  /// 等待阅读页面加载完成
  Future<void> waitForReady() async {
    await tester.pump(const Duration(seconds: 2));
  }

  // ── 操作 ──

  /// 点击屏幕中央切换工具栏
  Future<void> tapCenter() async {
    final screenSize = tester.view.physicalSize;
    await tester.tapAt(Offset(screenSize.width / 2, screenSize.height / 2));
    await tester.pump();
  }

  /// 点击工具栏中的设置图标
  Future<void> tapSettingsIcon() async {
    await tester.tap(find.byIcon(Icons.settings).last);
    await tester.pumpAndSettle();
  }

  /// 点击返回按钮退出阅读
  Future<void> tapBack() async {
    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();
  }

  // ── 断言 ──

  /// 当前是否在阅读页面
  bool get isOnReaderPage => find.byType(Scaffold).evaluate().isNotEmpty;

  /// 阅读内容是否存在
  bool get hasContent => find.text('').evaluate().isNotEmpty; // placeholder
}
