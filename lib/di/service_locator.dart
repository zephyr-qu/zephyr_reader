import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'service_locator.config.dart';

/// 全局服务定位器实例
final getIt = GetIt.instance;
@InjectableInit()
Future<void> configureDependencies() async {
  await GetIt.instance.init();
}
