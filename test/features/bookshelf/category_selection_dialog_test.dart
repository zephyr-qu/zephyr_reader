// test/features/bookshelf/category_selection_dialog_test.dart
//
// showCategorySelectionDialog — 分类选择弹窗（无 FFI）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_dialogs.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

Category _cat(String id, String name) => Category(
  id: id,
  name: name,
  description: null,
  color: '',
  sortOrder: 0,
  isSystem: false,
);

/// 通过点击按钮触发弹窗
Future<void> _openDialog(
  WidgetTester tester, {
  required List<Category> categories,
  Set<String> initialSelection = const {},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showCategorySelectionDialog(
                context,
                categories: categories,
                initialSelection: initialSelection,
                title: '选择分类',
                cancelText: '取消',
                confirmText: '确定',
              );
            },
            child: const Text('打开弹窗'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final categories = [_cat('a1', '小说'), _cat('a2', '历史'), _cat('a3', '科技')];

  group('showCategorySelectionDialog', () {
    testWidgets('shows all categories as checkboxes', (tester) async {
      await _openDialog(tester, categories: categories);

      expect(find.text('小说'), findsOneWidget);
      expect(find.text('历史'), findsOneWidget);
      expect(find.text('科技'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('shows title and action buttons', (tester) async {
      await _openDialog(tester, categories: categories);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('选择分类'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);
    });

    testWidgets('initial selection is reflected in checkboxes', (tester) async {
      await _openDialog(
        tester,
        categories: categories,
        initialSelection: {'a1', 'a3'},
      );

      final checkboxes = find.byType(CheckboxListTile);
      expect(checkboxes, findsNWidgets(3));

      expect(tester.widget<CheckboxListTile>(checkboxes.at(0)).value, isTrue);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(1)).value, isFalse);
      expect(tester.widget<CheckboxListTile>(checkboxes.at(2)).value, isTrue);
    });

    testWidgets('tapping checkbox toggles selection state', (tester) async {
      await _openDialog(tester, categories: categories);

      // 初始未选中
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isFalse,
      );

      // 点击第一个 checkbox
      await tester.tap(find.text('小说'));
      await tester.pump();

      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        isTrue,
      );
    });

    testWidgets('empty categories list shows no checkboxes', (tester) async {
      await _openDialog(tester, categories: []);

      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确定'), findsOneWidget);
    });
  });
}
