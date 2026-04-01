import 'package:path/path.dart' as p;

/// 字体信息
class FontInfo {
  final String id;
  final String name;
  final String? path;
  final bool isBuiltIn;
  final bool isDownloaded;
  final DateTime? createTime;

  FontInfo({
    required this.id,
    required this.name,
    this.path,
    this.isBuiltIn = false,
    this.isDownloaded = false,
    this.createTime,
  });

  /// 是否为自定义字体
  bool get isCustom => !isBuiltIn && !isDownloaded;

  /// 获取显示名称
  String get displayName => isBuiltIn ? name : p.basename(path ?? name);
}
