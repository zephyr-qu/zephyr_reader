import 'package:path/path.dart' as p;

/// 字体信息模型
///
/// 描述一个字体资源，包括内建字体和用户导入的自定义字体。
/// 通过 [isBuiltIn]、[isDownloaded] 区分字体来源。
class FontInfo {
  /// 字体唯一标识
  final String id;

  /// 字体显示名称
  final String name;

  /// 字体文件路径（自定义字体有此值，内建字体为 null）
  final String? path;

  /// 是否为内建系统字体
  final bool isBuiltIn;

  /// 是否从网络下载的字体
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
