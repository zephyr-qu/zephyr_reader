// test_driver/pages/search_page.dart
//
// SearchPage Page Object — 封装搜索页面的操作与查找逻辑
//
// 用于 E2E 和集成测试，隐藏 WidgetTester 选择器细节

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class SearchPageObject {
  final WidgetTester tester;

  SearchPageObject(this.tester);

  /// 等待搜索页面加载完成
  Future<void> waitForReady() async {
    await tester.pump(const Duration(seconds: 1));
  }

  /// 切换到搜索 Tab
  Future<void> navigateToSearch() async {
    await tester.tap(find.text('搜索').last);
    await tester.pumpAndSettle();
  }

  /// 输入搜索关键词
  Future<void> enterSearchQuery(String query) async {
    final textField = find.byType(TextField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField, query);
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  /// 点击搜索结果中的第一项
  Future<void> tapFirstResult() async {
    final results = find.byType(ListTile);
    if (results.evaluate().isNotEmpty) {
      await tester.tap(results.first);
      await tester.pumpAndSettle();
    }
  }

  /// 等待搜索结果加载且非空
  Future<bool> get hasResults async {
    await tester.pump(const Duration(milliseconds: 300));
    return find.byType(ListTile).evaluate().isNotEmpty;
  }

  /// 当前是否在搜索页面
  bool get isOnSearchPage => find.text('搜索').evaluate().isNotEmpty;
}
