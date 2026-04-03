/// 自定义字体服务
///
/// 支持系统字体选择和本地字体导入
///
/// 功能特性:
/// - 系统字体切换 (默认/宋体/黑体/等宽/楷体)
/// - 本地 TTF/OTF/TTC 字体文件导入
/// - 自定义字体管理 (删除/清除)
/// - 字体下载服务 (支持从 URL 下载)
/// - 响应式字体状态 (使用 signals_flutter)
library;

import 'dart:io';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/error/app_error.dart';
import 'package:zephyr_reader/features/reader/domain/models/font_info.dart';

/// 自定义字体服务
///
/// 管理阅读器自定义字体的加载、切换和持久化
@injectable
class CustomFontService {
  CustomFontService(this._prefs) {
    _initialize();
  }
  final SharedPreferences _prefs;

  /// 当前字体
  final currentFont = signal<FontInfo?>(null);

  /// 可用字体列表
  final availableFonts = signal<List<FontInfo>>([]);

  /// 字体加载完成标志
  final isLoaded = signal(false);

  static const String _keyCurrentFont = 'custom_font.current';

  /// 初始化字体服务
  Future<void> _initialize() async {
    await loadFonts();
    isLoaded.value = true;
  }

  /// 加载字体
  Future<void> loadFonts() async {
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

    debugPrint('字体加载完成，共${fonts.length}个字体');
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
      debugPrint('加载本地字体失败：$e');
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

    debugPrint('设置字体：${font.name}');
  }

  /// 导入本地字体
  ///
  /// 支持从文件选择器导入字体文件
  /// 自动处理文件名冲突
  Future<Result<FontInfo>> importFont(File fontFile) async {
    return Result.guardAsync(() async {
      // 验证文件是否存在
      if (!await fontFile.exists()) {
        throw AppError.file(message: '字体文件不存在', path: fontFile.path);
      }

      // 验证文件扩展名
      final extension = p.extension(fontFile.path).toLowerCase();
      if (!['.ttf', '.otf', '.ttc'].contains(extension)) {
        throw AppError.validation(
          message: '不支持的字体格式：$extension',
          detail: '仅支持 TTF、OTF、TTC 格式',
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');

      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }

      // 处理文件名冲突
      final baseName = p.basenameWithoutExtension(fontFile.path);
      final destPath = _getUniqueFilePath(fontDir.path, baseName, extension);

      // 复制字体文件
      await fontFile.copy(destPath);

      // 重新加载字体列表
      await loadFonts();

      // 返回导入的字体信息
      final fontName = p.basename(destPath);
      final fontId = 'custom_$destPath';

      return FontInfo(
        id: fontId,
        name: fontName,
        path: destPath,
        isDownloaded: false,
        createTime: DateTime.now(),
      );
    });
  }

  /// 生成唯一文件路径
  String _getUniqueFilePath(String dirPath, String baseName, String extension) {
    var destPath = p.join(dirPath, '$baseName$extension');
    var counter = 1;

    while (File(destPath).existsSync()) {
      destPath = p.join(dirPath, '${baseName}_$counter$extension');
      counter++;
    }

    return destPath;
  }

  /// 删除自定义字体
  ///
  /// 仅支持删除用户导入的字体，系统字体不可删除
  /// 删除成功后会自动切换回系统默认字体
  Future<Result<void>> deleteCustomFont(String fontId) async {
    return Result.guardAsync(() async {
      if (!fontId.startsWith('custom_')) {
        throw AppError.validation(message: '仅支持删除自定义字体', detail: '系统字体无法删除');
      }

      final filePath = fontId.substring('custom_'.length);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();

        // 如果当前使用的是该字体，切换回系统默认
        if (currentFont.value?.id == fontId) {
          await setCurrentFont('system');
        }

        // 重新加载字体列表
        await loadFonts();
      } else {
        throw AppError.file(message: '字体文件不存在', path: filePath);
      }
    });
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
      debugPrint('获取字体路径失败：$e');
      return null;
    }
  }

  /// 清除所有自定义字体
  ///
  /// 删除 fonts 目录下的所有字体文件，并切换回系统默认
  Future<void> clearAllCustomFonts() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');

      if (await fontDir.exists()) {
        await fontDir.delete(recursive: true);
      }

      // 切换回系统默认
      await setCurrentFont('system');

      debugPrint('清除所有自定义字体完成');
    } catch (e) {
      debugPrint('清除字体失败：$e');
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

/// 字体下载服务
///
/// 支持从 URL 下载字体文件并自动导入到自定义字体库
@injectable
class FontDownloadService {
  final Dio _dio;
  final CustomFontService _fontService;

  FontDownloadService(this._dio, this._fontService);

  /// 下载字体
  ///
  /// 参数:
  ///   - url: 字体文件 URL
  ///   - name: 字体名称
  ///   - onProgress: 下载进度回调 (0.0 - 1.0)
  ///
  /// 返回：是否下载成功
  Future<Result<FontInfo>> downloadFont({
    required String url,
    required String name,
    void Function(double progress)? onProgress,
  }) async {
    return Result.guardAsync(() async {
      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');
      if (!await fontDir.exists()) {
        await fontDir.create(recursive: true);
      }

      // 从 URL 提取文件扩展名
      final extension = _getExtensionFromUrl(url);
      final savePath =
          '${fontDir.path}/${name.replaceAll(' ', '_')}.$extension';

      // 检查文件是否已存在
      if (await File(savePath).exists()) {
        // 重新加载字体列表以获取最新状态
        await _fontService.loadFonts();
        final existingFont = _fontService.availableFonts.value.firstWhere(
          (f) => f.path == savePath,
          orElse: () => FontInfo(
            id: 'custom_$savePath',
            name: name,
            path: savePath,
            isDownloaded: true,
            createTime: DateTime.now(),
          ),
        );
        return existingFont;
      }

      // 使用 dio 下载字体
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress?.call(received / total);
          }
        },
      );

      // 验证下载的文件
      final downloadedFile = File(savePath);
      if (!await downloadedFile.exists()) {
        throw AppError.file(message: '字体下载失败', detail: '下载后文件不存在');
      }

      // 文件大小检查（字体文件通常至少 100KB）
      final fileSize = await downloadedFile.length();
      if (fileSize < 1024 * 100) {
        await downloadedFile.delete();
        throw AppError.validation(
          message: '字体文件大小异常',
          detail: '文件过小 (${fileSize ~/ 1024} KB)，可能不是有效的字体文件',
        );
      }

      // 导入到字体库
      final result = await _fontService.importFont(downloadedFile);
      if (result.isFailure) {
        throw result.error!;
      }

      return result.value!;
    });
  }

  /// 从 URL 获取文件扩展名
  String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.contains('.')) {
        final ext = path.split('.').last.toLowerCase();
        if (['ttf', 'otf', 'ttc'].contains(ext)) {
          return ext;
        }
      }
    } catch (_) {
      // 忽略解析错误
    }
    // 默认返回 ttf
    return 'ttf';
  }

  /// 获取推荐字体列表
  ///
  /// 返回开源字体资源列表，包含思源系列、霞鹜文楷等
  List<FontRecommendation> getRecommendedFonts() {
    return [
      FontRecommendation(
        name: '思源宋体',
        url: 'https://github.com/adobe-fonts/source-han-serif/releases',
        description: 'Adobe 开源宋体，支持简繁日韩',
        family: 'serif',
      ),
      FontRecommendation(
        name: '思源黑体',
        url: 'https://github.com/adobe-fonts/source-han-sans/releases',
        description: 'Adobe 开源黑体，支持简繁日韩',
        family: 'sans',
      ),
      FontRecommendation(
        name: '霞鹜文楷',
        url: 'https://github.com/lxgw/LxgwWenKai/releases',
        description: '开源楷体，书写风格',
        family: 'kai',
      ),
      FontRecommendation(
        name: '得意黑',
        url: 'https://github.com/zenithstars/ZenithStar/releases',
        description: '开源美术字',
        family: 'art',
      ),
      FontRecommendation(
        name: '更纱黑体',
        url: 'https://github.com/be5invis/Sarasa-Gothic/releases',
        description: '中英文合排优化',
        family: 'sans',
      ),
    ];
  }

  /// 检查字体是否已下载
  Future<bool> isFontDownloaded(String fontName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fontDir = Directory('${dir.path}/fonts');

      if (!await fontDir.exists()) {
        return false;
      }

      final files = fontDir.listSync().whereType<File>();
      return files.any(
        (f) =>
            p.basenameWithoutExtension(f.path).toLowerCase() ==
            fontName.toLowerCase(),
      );
    } catch (e) {
      debugPrint('检查字体下载状态失败：$e');
      return false;
    }
  }
}

/// 字体推荐信息
class FontRecommendation {
  FontRecommendation({
    required this.name,
    required this.url,
    required this.description,
    required this.family,
  });
  final String name;
  final String url;
  final String description;
  final String family;

  /// 获取显示文本
  String get displayText => '$name - $description';
}
