import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:zephyr_reader/features/sync/application/services/webdav_sync_service.dart';

import 'service_locator.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  await getIt.init();
  getIt.registerLazySingleton<WebDavSyncService>(() => WebDavSyncService());
}
