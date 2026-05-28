import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/app.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/init.dart';
import 'package:zephyr_reader/src/rust/api/search.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

import 'di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  final appDir = await getApplicationDocumentsDirectory();
  await initStorage(dataDir: '${appDir.path}/zephyr_reader/data');
  try {
    await initSearchEngine();
  } catch (e) {
    Logging.error('搜索索引初始化失败', exception: e);
  }
  await AppConfig.instance.init();
  await configureDependencies();
  // try {
  //   await getIt<FullTextSearchService>().init();
  // } catch (e) {
  //   debugPrint('initSearchEngine failed: $e');
  //   getIt<FullTextSearchService>().hasFailed = true;
  // }
  runApp(const MyApp());
}
