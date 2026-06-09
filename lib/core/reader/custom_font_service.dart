/// 自定义字体服务
///
/// 支持系统字体选择和本地字体导入。
/// 功能包括系统字体切换、本地 TTF/OTF/TTC 字体文件导入、
/// 自定义字体管理和 URL 下载服务。
/// 使用 signals_flutter 实现响应式字体状态管理。
library;

import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/models/font_info.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 字体仓库
///
/// 管理阅读器自定义字体的加载、切换和持久化
@injectable
class FontRepository {
  final SharedPreferences _prefs;
  final Completer<void> _ready = Completer<void>();

  FontRepository(this._prefs);

  @PostConstruct()
  Future<void> init() async {
    try {
      await loadFonts();
      await _registerFonts();
      isLoaded.value = true;
    } finally {
      _ready.complete();
    }
  }

  late final _currentFontId = persistedNullableString(
    _prefs,
    SettingsKeys.currentFont,
  );

  /// 当前字体
  final currentFont = signal<FontInfo?>(null);

  /// 可用字体列表
  final availableFonts = signal<List<FontInfo>>([]);

  /// 字体加载完成标志
  final isLoaded = signal(false);

  /// 已注册到 Flutter 的字体系列名
  final _registeredFamilies = <String>{};


  /// 获取当前字体的系列名（用于 TextStyle.fontFamily）
  String get currentFontFamily {
    final font = currentFont.value;
    if (font == null) return '';
    return familyNameFor(font);
  }

  /// 获取字体系列名
  String familyNameFor(FontInfo font) {
    if (font.isBuiltIn) {
      switch (font.id) {
        case 'serif':
          return 'serif';
        case 'sans':
          return 'sans-serif';
        default:
          return '';
      }
    }
    final name = p.basenameWithoutExtension(font.path ?? font.name);
    return 'custom_$name';
  }

  /// 注册所有自定义字体到 Flutter FontLoader
  Future<void> _registerFonts() async {
    for (final font in availableFonts.value) {
      if (font.isBuiltIn || font.path == null) continue;
      final family = familyNameFor(font);
      if (_registeredFamilies.contains(family)) continue;
      final file = File(font.path!);
      if (!await file.exists()) continue;
      try {
        final data = await file.readAsBytes();
        final loader = FontLoader(family)
          ..addFont(Future.value(data.buffer.asByteData()));
        await loader.load();
        _registeredFamilies.add(family);
      } catch (e) {
        Logging.error('字体注册失败 $family: $e');
      }
    }
  }

  Future<void> loadFonts() async {
    final fonts = <FontInfo>[];

    // 系统字体
    fonts.addAll([
      FontInfo(id: 'system', name: '系统默认', isBuiltIn: true),
      FontInfo(id: 'serif', name: '宋体', isBuiltIn: true),
      FontInfo(id: 'sans', name: '黑体', isBuiltIn: true),
    ]);

    // 加载本地字体
    final customFonts = await _loadCustomFonts();
    fonts.addAll(customFonts);

    availableFonts.value = fonts;

    // 加载当前字体
    final currentFontId = _currentFontId.value;
    if (currentFontId != null) {
      currentFont.value = fonts.firstWhere(
        (f) => f.id == currentFontId,
        orElse: () => fonts.first,
      );
    } else {
      currentFont.value = fonts.first;
    }

    Logging.info('字体加载完成，共${fonts.length}个字体');
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
          final stat = await file.stat();
          fonts.add(
            FontInfo(
              id: 'custom_${file.path}',
              name: file.path.split(Platform.pathSeparator).last,
              path: file.path,
              isDownloaded: false,
              createTime: stat.modified,
            ),
          );
        }
      }
    } catch (e) {
      Logging.error('加载本地字体失败：$e');
    }

    return fonts;
  }

  Future<void> setCurrentFont(String fontId) async {
    await _ready.future;
    final font = availableFonts.value.firstWhere(
      (f) => f.id == fontId,
      orElse: () => availableFonts.value.first,
    );

    currentFont.value = font;
    _currentFontId.value = fontId;

    Logging.info('设置字体：${font.name}');
  }

  /// 导入本地字体
  Future<FontInfo?> importFont(File fontFile) async {
    await _ready.future;
    if (!await fontFile.exists()) return null;

    final extension = p.extension(fontFile.path).toLowerCase();
    if (!['.ttf', '.otf', '.ttc'].contains(extension)) return null;

    final dir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${dir.path}/fonts');
    if (!await fontDir.exists()) await fontDir.create(recursive: true);

    final baseName = p.basenameWithoutExtension(fontFile.path);
    final destPath = await _getUniqueFilePath(
      fontDir.path,
      baseName,
      extension,
    );

    await fontFile.copy(destPath);
    await loadFonts();
    await _registerFonts();

    final fontName = p.basename(destPath);
    return FontInfo(
      id: 'custom_$destPath',
      name: fontName,
      path: destPath,
      isDownloaded: false,
      createTime: DateTime.now(),
    );
  }

  /// 生成唯一文件路径
  Future<String> _getUniqueFilePath(
    String dirPath,
    String baseName,
    String extension,
  ) async {
    var destPath = p.join(dirPath, '$baseName$extension');
    var counter = 1;

    while (await File(destPath).exists()) {
      destPath = p.join(dirPath, '${baseName}_$counter$extension');
      counter++;
    }

    return destPath;
  }

  /// 删除自定义字体
  Future<bool> deleteCustomFont(String fontId) async {
    await _ready.future;
    if (!fontId.startsWith('custom_')) return false;

    final filePath = fontId.substring('custom_'.length);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
      if (currentFont.value?.id == fontId) await setCurrentFont('system');
      await loadFonts();
      return true;
    }
    return false;
  }

  /// 获取字体文件路径
  String? getFontPath(String fontId) {
    try {
      final font = availableFonts.value.firstWhere(
        (f) => f.id == fontId,
        orElse: () => availableFonts.value.first,
      );
      return font.path;
    } catch (e) {
      Logging.error('获取字体路径失败：$e');
      return null;
    }
  }

  /// 清除所有自定义字体
  ///
  /// 删除 fonts 目录下的所有字体文件，并切换回系统默认
  Future<void> clearAllCustomFonts() async {
    await _ready.future;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');

      if (await fontDir.exists()) {
        await fontDir.delete(recursive: true);
      }

      // 切换回系统默认
      await setCurrentFont('system');

      Logging.info('清除所有自定义字体完成');
    } catch (e) {
      Logging.error('清除字体失败：$e');
    }
  }

  /// 获取自定义字体数量
  int get customFontCount {
    return availableFonts.value.where((f) => f.isCustom).length;
  }

  /// 检查是否为系统字体
  bool isBuiltInFont(String fontId) {
    final font = availableFonts.value.firstWhere(
      (f) => f.id == fontId,
      orElse: () => availableFonts.value.first,
    );
    return font.isBuiltIn;
  }
}
