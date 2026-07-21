import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'readium_poc_reader.dart';

/// PoC 入口页面：选择测试书后打开 [ReadiumPocReader]。
///
/// 从 `assets/test_books/` 和外部目录加载测试书。
class PocEntry extends StatelessWidget {
  const PocEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Readium PoC — 测试书选择')),
      body: FutureBuilder<List<TestBook>>(
        future: _loadTestBooks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snapshot.data!;
          if (books.isEmpty) {
            return const Center(
              child: Text(
                '没有测试书。\n将 EPUB 文件放入 assets/test_books/ 或 external 目录。',
              ),
            );
          }
          return ListView.builder(
            itemCount: books.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '点击一本书开始 PoC 验证',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                );
              }
              final book = books[index - 1];
              return ListTile(
                leading: const Icon(Icons.book),
                title: Text(book.name),
                subtitle: Text(book.format),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReadiumPocReader(filePath: book.path),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickExternal(context),
        child: const Icon(Icons.folder_open),
      ),
    );
  }

  Future<void> _pickExternal(BuildContext context) async {
    // TODO: 使用 file_picker 或类似方式选择外部 EPUB 文件
  }
}

class TestBook {
  final String name;
  final String path;
  final String format;

  const TestBook({
    required this.name,
    required this.path,
    required this.format,
  });
}

Future<List<TestBook>> _loadTestBooks() async {
  final books = <TestBook>[];
  final dir = Directory('assets/test_books');
  if (await dir.exists()) {
    await for (final entity in dir.list()) {
      if (entity is File &&
          (entity.path.endsWith('.epub') || entity.path.endsWith('.txt'))) {
        books.add(
          TestBook(
            name: entity.path.split('/').last,
            path: entity.path,
            format: entity.path.endsWith('.epub') ? 'EPUB' : 'TXT',
          ),
        );
      }
    }
  }
  // 也检查 app 文档目录
  final docDir = await getApplicationDocumentsDirectory();
  final externalDir = Directory('${docDir.path}/poc_test_books');
  if (await externalDir.exists()) {
    await for (final entity in externalDir.list()) {
      if (entity is File &&
          (entity.path.endsWith('.epub') || entity.path.endsWith('.txt'))) {
        final name = entity.path.split('/').last;
        if (!books.any((b) => b.name == name)) {
          books.add(
            TestBook(
              name: name,
              path: entity.path,
              format: entity.path.endsWith('.epub') ? 'EPUB' : 'TXT',
            ),
          );
        }
      }
    }
  }
  return books;
}
