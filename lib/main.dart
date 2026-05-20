import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/app.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/features/search/application/services/full_text_search_service.dart';
import 'package:zephyr_reader/src/rust/api/storage.dart' as storage;
import 'package:zephyr_reader/src/rust/frb_generated.dart';

import 'di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final appDir = await getApplicationDocumentsDirectory();
  await storage.initStorage(dataDir: '${appDir.path}/zephyr_reader/data');
  await AppConfig.instance.init();
  await configureDependencies();
  try {
    await getIt<FullTextSearchService>().init();
  } catch (e) {
    debugPrint('initSearchEngine failed: $e');
  }
  runApp(const MyApp());
}
