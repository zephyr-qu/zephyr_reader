import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zephyr_reader/core/utils/logging.dart';

/// 内置词典管理。
///
/// 负责将 assets 中的词典文件（.mdx）解压到应用文档目录以供查询。
class BuiltinDictionary {
  static const _assetPath = 'assets/dictionary.mdx';
  static const _fileName = 'dictionary.mdx';

  static Future<String> ensureExtracted() async {
    final dir = await getApplicationDocumentsDirectory();
    final targetFile = File('${dir.path}/$_fileName');

    if (await targetFile.exists()) {
      return targetFile.path;
    }

    try {
      final byteData = await rootBundle.load(_assetPath);
      await targetFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      Logging.info('内置词典已解压至 ${targetFile.path}');
      return targetFile.path;
    } catch (e, st) {
      Logging.error('内置词典解压失败', exception: e, stackTrace: st);
      rethrow;
    }
  }
}
