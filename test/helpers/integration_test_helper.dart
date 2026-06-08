// test/helpers/integration_test_helper.dart
//
// 集成测试辅助工具 — 在宿主平台（macOS/Windows/Linux）上设置和清理
// Rust FFI 所需的存储环境、创建测试文件、解析书籍。
//
// 使用前提: FFI 已通过 RustLib.init() 初始化。
// 这些测试不适用于 Android/iOS（需设备环境），仅用于宿主平台。

import 'dart:io';

import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/init.dart';
import 'package:zephyr_reader/src/rust/domain/types/metadata.dart';

/// 当前活动的临时目录，由 [setupTestStorage] 创建。
Directory? _tempDir;

/// 创建一个临时目录并初始化 SQLite 存储。
///
/// 返回临时目录的绝对路径，所有测试数据将写在此目录下。
/// 每调用一次都会创建新的子目录（包含毫秒时间戳），因此多次调用互不干扰。
Future<String> setupTestStorage({String? label}) async {
  final base = Directory.systemTemp.createTemp('zephyr_test_${label ?? ''}');
  _tempDir = await base;
  final dataDir = '${_tempDir!.path}/data';
  await Directory(dataDir).create(recursive: true);
  await initStorage(dataDir: dataDir);
  return _tempDir!.path;
}

/// 删除 [setupTestStorage] 创建的临时目录及其所有内容。
///
/// 重试最多 3 次以处理 SQLite 文件锁。
Future<void> teardownTestStorage() async {
  if (_tempDir != null) {
    for (int attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      try {
        if (await _tempDir!.exists()) {
          await _tempDir!.delete(recursive: true);
        }
        _tempDir = null;
        return;
      } on PathAccessException {
        // SQLite 锁尚未释放，继续重试
      }
    }
    // 最后一次尝试失败后记录但不影响测试结果
    _tempDir = null;
  }
}

/// 在测试临时目录中创建一个文本文件。
///
/// [name] 文件名（如 'test_book.txt'），[content] 文件内容。
/// 返回文件的绝对路径。
Future<String> createTestFile(String name, String content) async {
  if (_tempDir == null) {
    throw StateError(
      'createTestFile: call setupTestStorage() before creating files.',
    );
  }
  final file = File('${_tempDir!.path}/$name');
  await file.writeAsString(content, flush: true);
  return file.absolute.path;
}

/// 从项目 `test/fixtures/` 目录拷贝一个文件到临时目录。
///
/// [fixtureName] 是相对 `test/fixtures/` 的文件名（如 `'活着.txt'`）。
/// 返回目标文件的绝对路径。
Future<String> copyFixtureFile(String fixtureName) async {
  if (_tempDir == null) {
    throw StateError(
      'copyFixtureFile: call setupTestStorage() before copying files.',
    );
  }
  final src = File('test/fixtures/$fixtureName');
  if (!await src.exists()) {
    throw StateError('Fixture not found: test/fixtures/$fixtureName');
  }
  final dst = File('${_tempDir!.path}/$fixtureName');
  await src.copy(dst.path);
  return dst.absolute.path;
}

/// 解析测试文件并返回解析结果。
///
/// [filePath] 必须是 [createTestFile] 返回的绝对路径。
/// 返回 ([ParseResult], filePath) 元组。
Future<(ParseResult, String)> parseTestBook(String filePath) async {
  final result = await core_api.parseBook(filePath: filePath);
  return (result, filePath);
}

/// 从数据库中删除指定书籍（清理用）。
Future<void> deleteTestBook(String bookId) async {
  try {
    await book_api.deleteBook(bookId: bookId, coversDir: '');
  } catch (_) {
    // 删除失败不影响后续清理
  }
}

/// 检查 FFI 是否可用（宿主平台 + 已初始化）。
bool isFfiAvailable() {
  return Platform.isWindows ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isAndroid ||
      Platform.isIOS;
}
