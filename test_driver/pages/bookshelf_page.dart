// test_driver/pages/bookshelf_page.dart
//
// BookshelfPage Page Object — 封装书架页面的操作与查找逻辑
//
// 用于 E2E 和集成测试，隐藏 WidgetTester 选择器细节

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class BookshelfPageObject {
  final WidgetTester tester;

  BookshelfPageObject(this.tester);

  // ── 等待页面就绪 ──

  /// 等待书架页面加载完成
  Future<void> waitForReady() async {
    await tester.pump(const Duration(seconds: 1));
  }

  // ── 导航 ──

  /// 切换到书架 Tab
  Future<void> navigateToBookshelf() async {
    // 底部导航栏第 2 项为书架
    await tester.tap(find.text('书架').last);
    await tester.pumpAndSettle();
  }

  /// 点击第一本书籍进入详情
  Future<void> tapFirstBook() async {
    final bookCards = find.byType(ListTile);
    if (bookCards.evaluate().isNotEmpty) {
      await tester.tap(bookCards.first);
      await tester.pumpAndSettle();
    }
  }

  // ── 断言 ──

  /// 当前是否在书架页面
  bool get isOnBookshelfPage =>
      find.text('书架').evaluate().isNotEmpty;
}
