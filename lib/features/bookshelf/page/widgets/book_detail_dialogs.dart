import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 显示分类选择弹窗（多选 CheckboxListTile）。
///
/// 返回选中分类的 ID 集合，取消返回 `null`。
Future<Set<String>?> showCategorySelectionDialog(
  BuildContext context, {
  required List<Category> categories,
  Set<String> initialSelection = const {},
  required String title,
  required String cancelText,
  required String confirmText,
}) async {
  final tempSelected = Set<String>.from(initialSelection);
  return showDialog<Set<String>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialogState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: categories
              .map(
                (cat) => CheckboxListTile(
                  title: Text(cat.name),
                  value: tempSelected.contains(cat.id),
                  onChanged: (v) {
                    if (v == true) {
                      tempSelected.add(cat.id);
                    } else {
                      tempSelected.remove(cat.id);
                    }
                    setDialogState(() {});
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, Set<String>.from(tempSelected)),
            child: Text(confirmText),
          ),
        ],
      ),
    ),
  );
}

/// 显示删除书籍确认对话框
Future<bool> showDeleteBookDialog(BuildContext context, Book book) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.deleteBook),
      content: Text(l10n.confirmDeleteBookMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(c).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await book_api.deleteBook(
        bookId: book.bookId,
        coversDir: AppConfig.instance.coverDir,
      );
    } catch (e) {
      Logging.error('Failed to delete book', exception: e);
      if (context.mounted) {
        showErrorSnack(context, l10n.deleteFailed(e.toString()));
      }
      return false;
    }
    return true;
  }
  return false;
}

/// 显示编辑元数据对话框
Future<Book?> showEditMetadataDialog(BuildContext context, Book book) async {
  final l10n = AppLocalizations.of(context)!;
  final nameController = TextEditingController(text: book.title);
  final authorController = TextEditingController(text: book.author ?? '');
  final publisherController = TextEditingController(text: book.publisher ?? '');
  final translatorController = TextEditingController(
    text: book.translator ?? '',
  );
  final isbnController = TextEditingController(text: book.isbn ?? '');
  final descController = TextEditingController(text: book.description ?? '');

  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.editMetadata),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.bookTitle),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: authorController,
              decoration: InputDecoration(labelText: l10n.author),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: publisherController,
              decoration: InputDecoration(labelText: l10n.publisher),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: translatorController,
              decoration: InputDecoration(labelText: l10n.translator),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: isbnController,
              decoration: InputDecoration(labelText: l10n.isbn),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: InputDecoration(labelText: l10n.introLabel),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () {
            Navigator.pop(c, {
              'title': nameController.text,
              'author': authorController.text,
              'publisher': publisherController.text,
              'translator': translatorController.text,
              'isbn': isbnController.text,
              'description': descController.text,
            });
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );

  if (result != null) {
    try {
      final updated = book.copyWith(
        title: result['title'] ?? book.title,
        author: result['author']?.isNotEmpty == true ? result['author'] : null,
        description: result['description']?.isNotEmpty == true
            ? result['description']
            : null,
        publisher: result['publisher']?.isNotEmpty == true
            ? result['publisher']
            : null,
        translator: result['translator']?.isNotEmpty == true
            ? result['translator']
            : null,
        isbn: result['isbn']?.isNotEmpty == true ? result['isbn'] : null,
      );
      await book_api.upsertBook(book: updated);
      return updated;
    } catch (e) {
      Logging.error('Failed to save book metadata', exception: e);
      return null;
    }
  }
  return null;
}
