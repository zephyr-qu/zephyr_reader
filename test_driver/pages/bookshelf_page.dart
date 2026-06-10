import 'dart:async';
// test_driver/pages/bookshelf_page.dart
//
// BookshelfPage Page Object — 封装书架页面的操作与查找逻辑
//
// 用于 E2E 和集成测试，隐藏 WidgetTester 选择器细节

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 等待 [finder] 匹配的 widget 出现，超时抛出 [TimeoutException]。
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 200),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TimeoutException('Timed out waiting for finder');
}

class BookshelfPageObject {
  final WidgetTester tester;

  BookshelfPageObject(this.tester);

  // ── 等待页面就绪 ──

  /// 等待书架网格渲染完成。
  Future<void> waitForReady() async {
    await _pumpUntil(
      tester,
      find.byKey(const Key('bookshelf_grid')),
      timeout: const Duration(seconds: 10),
    );
  }

  // ── 导航 ──

  /// 切换到书架 Tab
  Future<void> navigateToBookshelf() async {
    await tester.tap(find.text('书架').last);
    await tester.pumpAndSettle();
  }

  // ── 操作 ──

  /// 点击第一本书籍（进入详情/阅读页）。
  Future<void> tapFirstBook() async {
    final bookFinder = _bookWidgets();
    if (bookFinder.evaluate().isNotEmpty) {
      // 点第一个书籍的 InkWell
      final inkWell = find.descendant(
        of: bookFinder.first,
        matching: find.byType(InkWell),
      );
      if (inkWell.evaluate().isNotEmpty) {
        await tester.tap(inkWell.first);
        await tester.pumpAndSettle();
      }
    }
  }

  /// 按索引点击书籍（0-based）。
  Future<void> tapBookByIndex(int index) async {
    final bookFinder = _bookWidgets();
    if (index < bookFinder.evaluate().length) {
      final inkWell = find.descendant(
        of: bookFinder.at(index),
        matching: find.byType(InkWell),
      );
      if (inkWell.evaluate().isNotEmpty) {
        await tester.tap(inkWell.first);
        await tester.pumpAndSettle();
      }
    }
  }

  // ── 查询 ──

  /// 返回所有带 book_ Key 的 RepaintBoundary。
  Finder _bookWidgets() {
    return find.byWidgetPredicate(
      (w) =>
          w is RepaintBoundary &&
          w.key is ValueKey &&
          (w.key as ValueKey).value.toString().startsWith('book_'),
    );
  }

  // ── 断言 ──

  /// 书架网格是否有书籍。
  bool get hasBooks {
    if (find.byKey(const Key('bookshelf_grid')).evaluate().isEmpty) {
      return false;
    }
    return _bookWidgets().evaluate().isNotEmpty;
  }

  /// 书架上的书籍数量。
  int get bookCount => _bookWidgets().evaluate().length;

  /// 指定文本提示的书籍是否存在。
  bool bookExists(String titleHint) {
    return find.textContaining(titleHint).evaluate().isNotEmpty;
  }

  /// 当前是否在书架页面。
  bool get isOnBookshelfPage => find.text('书架').evaluate().isNotEmpty;
}
