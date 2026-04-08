/// 笔记管理页面（简化版）
///
/// TODO: 等待 FRB 正确生成 DbNote 类型后完善
library;

import 'package:flutter/material.dart';

/// 笔记管理页面
class NoteManagePage extends StatelessWidget {
  final String bookId;
  final String bookTitle;

  const NoteManagePage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$bookTitle - 笔记'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '笔记功能开发中',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '等待 Rust DbNote 类型完善后可用',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
