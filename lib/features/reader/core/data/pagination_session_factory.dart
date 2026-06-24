import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/core/data/rust_pagination_session.dart';
import 'package:zephyr_reader/features/reader/core/domain/pagination_session.dart';

@injectable
class PaginationSessionFactory {
  PaginationSession create({void Function()? onCacheUpdated}) =>
      RustPaginationSession(onCacheUpdated: onCacheUpdated);
}
