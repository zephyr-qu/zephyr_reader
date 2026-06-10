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

  // ── 等待页面就绪 ──

  /// 等待搜索页面加载完成。
  Future<void> waitForReady() async {
    await tester.pump(const Duration(seconds: 1));
  }

  // ── 导航 ──

  /// 切换到搜索 Tab。
  Future<void> navigateToSearch() async {
    await tester.tap(find.text('搜索').last);
    await tester.pumpAndSettle();
  }

  // ── 操作 ──

  /// 输入关键词并触发搜索。
  Future<void> search(String query) async {
    final textField = find.byType(TextField);
    if (textField.evaluate().isNotEmpty) {
      await tester.enterText(textField, query);
      await tester.pump(const Duration(seconds: 1));
      // 触发键盘搜索或 debounce
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(seconds: 2));
    }
  }

  /// 点击搜索结果中的第一项。
  Future<void> tapFirstResult() async {
    final results = find.byType(ListTile);
    if (results.evaluate().isNotEmpty) {
      await tester.tap(results.first);
      await tester.pumpAndSettle();
    }
  }

  // ── 断言 ──

  /// 搜索结果列表是否存在。
  bool get hasResults {
    return find.byKey(const Key('search_results')).evaluate().isNotEmpty;
  }

  /// 搜索结果数量（通过 SearchResultsView 内的 ListTile 数量估算）。
  int get resultCount {
    return find.byType(ListTile).evaluate().length;
  }

  /// 是否有包含指定文本的结果。
  bool hasResultContaining(String text) {
    return find.textContaining(text).evaluate().isNotEmpty;
  }

  /// 当前是否在搜索页面。
  bool get isOnSearchPage => find.text('搜索').evaluate().isNotEmpty;
}
