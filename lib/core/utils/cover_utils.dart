// 封面路径解析工具
//
// DB 中只存文件名（相对路径），读取时拼接回完整路径。
import 'package:path/path.dart' as p;
import 'package:zephyr_reader/core/app_config.dart';

/// 将 DB 中存储的相对封面路径解析为完整文件系统路径。
///
/// 如果 [relativePath] 为 null，同样返回 null。
/// 返回的路径可直接用于 `File()` 构造。
String? resolveCoverPath(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) return null;
  return p.join(AppConfig.instance.coverDir, relativePath);
}
