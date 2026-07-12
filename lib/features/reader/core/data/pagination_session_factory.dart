import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_pagination_session.dart';

@injectable
class PaginationSessionFactory {
  /// ADR-016：产品路径固定为 Flutter 精确装箱。
  /// [RustPaginationSession] 保留为 DEAD PATH（对照/删除前）。
  PaginationSession create({void Function()? onCacheUpdated}) {
    return FlutterPaginationSession(onCacheUpdated: onCacheUpdated);
  }
}
