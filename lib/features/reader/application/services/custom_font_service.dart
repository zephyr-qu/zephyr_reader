/// 自定义字体管�?///
/// 支持系统字体选择和本地字体导�?
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 字体信息
class FontInfo {
  final String id;
  final String name;
  final String? path;
  final bool isBuiltIn;
  final bool isDownloaded;

  FontInfo({
    required this.id,
    required this.name,
    this.path,
    this.isBuiltIn = false,
    this.isDownloaded = false,
  });
}

/// 自定义字体服�?
class CustomFontService {
  final SharedPreferences _prefs;

  /// 当前字体
  final currentFont = signal<FontInfo?>(null);

  /// 可用字体列表
  final availableFonts = signal<List<FontInfo>>([]);

  CustomFontService(this._prefs) {
    _loadFonts();
  }

  static const String _keyCurrentFont = 'custom_font.current';
  static const String _keyFontDir = 'custom_font.dir';

  /// 加载字体
  Future<void> _loadFonts() async {
    final fonts = <FontInfo>[];

    // 系统字体
    fonts.addAll([
      FontInfo(id: 'system', name: '系统默认', isBuiltIn: true),
      FontInfo(id: 'serif', name: '宋体', isBuiltIn: true),
      FontInfo(id: 'sans', name: '黑体', isBuiltIn: true),
      FontInfo(id: 'mono', name: '等宽字体', isBuiltIn: true),
      FontInfo(id: 'kai', name: '楷体', isBuiltIn: true),
    ]);

    // 加载本地字体
    final customFonts = await _loadCustomFonts();
    fonts.addAll(customFonts);

    availableFonts.value = fonts;

    // 加载当前字体
    final currentFontId = _prefs.getString(_keyCurrentFont);
    if (currentFontId != null) {
      currentFont.value = fonts.firstWhere(
        (f) => f.id == currentFontId,
        orElse: () => fonts.first,
      );
    } else {
      currentFont.value = fonts.first;
    }
  }

  /// 加载本地字体
  Future<List<FontInfo>> _loadCustomFonts() async {
    final fonts = <FontInfo>[];

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');

      if (await fontDir.exists()) {
        final files = fontDir.listSync().whereType<File>().where(
          (f) =>
              f.path.endsWith('.ttf') ||
              f.path.endsWith('.otf') ||
              f.path.endsWith('.ttc'),
        );

        for (final file in files) {
          fonts.add(
            FontInfo(
              id: 'custom_${file.path}',
              name: file.path.split('/').last,
              path: file.path,
              isDownloaded: true,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('加载本地字体失败�?e');
    }

    return fonts;
  }

  /// 设置当前字体
  Future<void> setCurrentFont(String fontId) async {
    final font = availableFonts.value.firstWhere(
      (f) => f.id == fontId,
      orElse: () => availableFonts.value.first,
    );

    currentFont.value = font;
    await _prefs.setString(_keyCurrentFont, fontId);

    debugPrint('设置字体�?{font.name}');
  }

  /// 导入本地字体
  Future<bool> importFont(File fontFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');

      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }

      // 复制字体文件
      final fileName = fontFile.path.split('/').last;
      final destPath = '${fontDir.path}/$fileName';
      await fontFile.copy(destPath);

      // 重新加载字体列表
      await _loadFonts();

      debugPrint('字体导入成功�?fileName');
      return true;
    } catch (e) {
      debugPrint('字体导入失败�?e');
      return false;
    }
  }

  /// 删除自定义字�?
  ///
   Future<bool> deleteCustomFont(String fontId) async {
    if (!fontId.startsWith('custom_')) {
      return false;
    }

    try {
      final filePath = fontId.substring('custom_'.length);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();

        // 如果当前使用的是该字体，切换回系统默�?
        if (currentFont.value?.id == fontId) {
          await setCurrentFont('system');
        }

        // 重新加载字体列表
        await _loadFonts();

        debugPrint('字体删除成功�?filePath');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('字体删除失败�?e');
      return false;
    }
  }

  /// 获取字体文件路径
  String? getFontPath(String fontId) {
    final font = availableFonts.value.firstWhere(
      (f) => f.id == fontId,
      orElse: () => availableFonts.value.first,
    );
    return font.path;
  }

  /// 清除所有自定义字体
  Future<void> clearAllCustomFonts() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');

      if (await fontDir.exists()) {
        await fontDir.delete(recursive: true);
      }

      // 切换回系统默�?      await setCurrentFont('system');

      debugPrint('清除所有自定义字体完成');
    } catch (e) {
      debugPrint('清除字体失败�?e');
    }
  }
}

/// 字体下载服务（可选）
class FontDownloadService {
  /// 下载字体
  Future<bool> downloadFont({required String url, required String name}) async {
    // TODO: 实现字体下载
    debugPrint('下载字体�?name, URL: $url');
    return false;
  }

  /// 获取推荐字体列表
  List<Map<String, String>> getRecommendedFonts() {
    return [
      {
        'name': '思源宋体',
        'url': 'https://github.com/adobe-fonts/source-han-serif',
        'description': 'Adobe 开源字�?',
      },
      {
        'name': '思源黑体',
        'url': 'https://github.com/adobe-fonts/source-han-sans',
        'description': 'Adobe 开源字�?',
      },
      {
        'name': '霞鹜文楷',
        'url': 'https://github.com/lxgw/LxgwWenKai',
        'description': '开源楷�?',
      },
    ];
  }
}
