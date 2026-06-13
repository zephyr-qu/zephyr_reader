// test_driver/pages/reader_page.dart
//
// ReaderPage Page Object — 封装阅读页面的操作与查找逻辑
//
// 用于 E2E 和集成测试，隐藏 WidgetTester 选择器细节

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class ReaderPageObject {
  final WidgetTester tester;

  ReaderPageObject(this.tester);

  // ── 等待页面就绪 ──

  /// 等待阅读页面加载完成（loading 状态消失，内容出现）。
  Future<void> waitForReady() async {
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (hasContent && !_isLoading) return;
    }
  }

  // ── 操作 ──

  /// 点击屏幕右侧 1/3 触发翻下一页。
  Future<void> tapNextPage() async {
    final screenSize = tester.view.physicalSize;
    await tester.tapAt(Offset(screenSize.width * 0.85, screenSize.height / 2));
    await tester.pump();
    // 给足够时间让内容加载和渲染
    await tester.pump(const Duration(seconds: 1));
  }

  /// 点击屏幕左侧 1/3 触发翻上一页。
  Future<void> tapPrevPage() async {
    final screenSize = tester.view.physicalSize;
    await tester.tapAt(Offset(screenSize.width * 0.15, screenSize.height / 2));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// 向左滑动翻下一页。
  Future<void> swipeLeft() async {
    final screenSize = tester.view.physicalSize;
    await tester.drag(
      find.byType(Scaffold),
      Offset(-screenSize.width * 0.4, 0),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  /// 向右滑动翻上一页。
  Future<void> swipeRight() async {
    final screenSize = tester.view.physicalSize;
    await tester.drag(find.byType(Scaffold), Offset(screenSize.width * 0.4, 0));
    await tester.pump(const Duration(seconds: 1));
  }

  /// 点击屏幕中央（切换顶部工具栏）。
  Future<void> tapCenter() async {
    final screenSize = tester.view.physicalSize;
    await tester.tapAt(Offset(screenSize.width / 2, screenSize.height / 2));
    await tester.pump();
  }

  /// 点击返回按钮退出阅读。
  Future<void> tapBack() async {
    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();
  }

  // ── 断言 ──

  /// 当前是否在阅读页面。
  bool get isOnReaderPage => find.byType(Scaffold).evaluate().isNotEmpty;

  /// 是否处于加载中状态。
  bool get _isLoading =>
      find.byKey(const ValueKey('reader_loading')).evaluate().isNotEmpty;

  /// 是否处于错误状态。
  bool get hasError =>
      find.byKey(const ValueKey('reader_error')).evaluate().isNotEmpty;

  /// 阅读内容是否已加载（非 loading/error 状态）。
  bool get hasContent {
    if (_isLoading) return false;
    if (hasError) return false;
    return true;
  }
}
