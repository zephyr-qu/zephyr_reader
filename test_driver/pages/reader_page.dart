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
    // 等待 loading 或 error 状态消失，内容 key 出现
    // content key 格式为 ValueKey('${readingMode}_${chapterId}_$pageIndex')
    // 无法预先知道内容 key，因此轮询直到 loading/error key 都消失
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (hasContent) return;
    }
  }

  // ── 操作 ──

  /// 点击屏幕中央（切换工具栏）。
  Future<void> tapCenter() async {
    final screenSize = tester.view.physicalSize;
    await tester.tapAt(Offset(screenSize.width / 2, screenSize.height / 2));
    await tester.pump();
  }

  /// 点击 TTS 按钮（底部工具栏中的"朗读"）。
  Future<void> tapTtsButton() async {
    await tester.tap(find.text('朗读').last);
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

  /// 阅读内容是否已加载（非 loading/error 状态）。
  bool get hasContent {
    if (find.byKey(const ValueKey('loading')).evaluate().isNotEmpty) {
      return false;
    }
    if (find.byKey(const ValueKey('error')).evaluate().isNotEmpty) {
      return false;
    }
    return true;
  }
}
