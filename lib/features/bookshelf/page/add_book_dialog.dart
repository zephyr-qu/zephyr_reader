import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/src/rust/api.dart' as rust_api;

/// 添加书籍对话框（文件选择方式
class AddBookDialog extends StatefulWidget {
  const AddBookDialog({super.key});

  @override
  State<AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends State<AddBookDialog> {
  String? _selectedFilePath;
  String? _bookTitle;
  String? _bookAuthor;
  String? _bookDescription;
  String? _coverPath;
  int _chapterCount = 0;
  bool _isParsing = false;
  String? _parseError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      color: theme.colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '添加书籍',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '选择本地 TXT EPUB 文件',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 文件选择区域
              _buildFileSelector(theme),

              if (_selectedFilePath != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // 书籍信息预览
                if (_bookTitle != null) _buildInfoRow('书名', _bookTitle!, theme),
                if (_bookAuthor != null)
                  _buildInfoRow('作者', _bookAuthor!, theme),
                if (_chapterCount > 0)
                  _buildInfoRow('章节数', '$_chapterCount 章', theme),

                const SizedBox(height: 24),
              ],

              // 错误信息
              if (_parseError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _parseError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_selectedFilePath != null && !_isParsing)
                          ? _handleSubmit
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isParsing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('添加到书架'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelector(ThemeData theme) {
    return InkWell(
      onTap: _isParsing ? null : _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedFilePath != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: 2,
            style: _selectedFilePath != null
                ? BorderStyle.solid
                : BorderStyle.none,
          ),
          color: _selectedFilePath != null
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              _selectedFilePath != null
                  ? Icons.check_circle
                  : Icons.upload_file,
              size: 48,
              color: _selectedFilePath != null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilePath != null ? '已选择文件' : '点击选择 TXT EPUB 文件',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _selectedFilePath != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedFilePath != null) ...[
              const SizedBox(height: 8),
              Text(
                _selectedFilePath!.split(Platform.pathSeparator).last,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isParsing = true;
      _parseError = null;
    });

    try {
      // 打开文件选择
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isParsing = false;
        });
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        setState(() {
          _isParsing = false;
          _parseError = '无法获取文件路径';
        });
        return;
      }

      // 调用 Rust 解析文件
      try {
        final bookInfoResult = rust_api.parseLocalBook(filePath: filePath);
        final bookInfo = (bookInfoResult as dynamic).value;

        if (bookInfo == null) {
          throw Exception('解析失败：返回空');
        }

        setState(() {
          _selectedFilePath = filePath;
          _bookTitle = bookInfo.title;
          _bookAuthor = bookInfo.author;
          _bookDescription = bookInfo.description.isNotEmpty
              ? bookInfo.description
              : null;
          _coverPath = bookInfo.coverPath;
          _chapterCount = bookInfo.chapterCount;
          _isParsing = false;
        });
      } catch (e) {
        setState(() {
          _isParsing = false;
          _parseError = '解析失败e';
        });
      }
    } catch (e) {
      setState(() {
        _isParsing = false;
        _parseError = '解析失败e';
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isParsing = true;
    });

    try {
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      // 复制文件到应用目
      final fileName = _selectedFilePath!.split(Platform.pathSeparator).last;
      final destPath = '${booksDir.path}/$fileName';
      await File(_selectedFilePath!).copy(destPath);

      // 提取封面（如果是 EPUB
      String? savedCoverPath;
      if (fileName.toLowerCase().endsWith('.epub') && _coverPath != null) {
        try {
          final coversDir = Directory('${booksDir.path}/covers');
          if (!await coversDir.exists()) {
            await coversDir.create(recursive: true);
          }

          final coverResult = rust_api.extractBookCover(
            filePath: _selectedFilePath!,
            outputDir: coversDir.path,
          );

          try {
            savedCoverPath = (coverResult as dynamic).value;
          } catch (e) {
            debugPrint('提取封面失败e');
          }
        } catch (e) {
          debugPrint('提取封面失败e');
        }
      }

      // 创建书籍记录
      final book = BooksCompanion(
        title: drift.Value(_bookTitle ?? '未知书籍'),
        author: drift.Value(_bookAuthor ?? '未知作'),
        coverPath: savedCoverPath != null
            ? drift.Value(savedCoverPath)
            : const drift.Value.absent(),
        description: _bookDescription != null && _bookDescription!.isNotEmpty
            ? drift.Value(_bookDescription!)
            : const drift.Value.absent(),
        filePath: drift.Value(destPath),
        status: drift.Value('reading'),
        totalChapters: drift.Value(_chapterCount),
        createdAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      );

      // 通过 Navigator 返回数据
      if (mounted) {
        Navigator.pop(context, book);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _parseError = '添加失败e';
        });
      }
    }
  }
}
