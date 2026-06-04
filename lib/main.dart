import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/app.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/init.dart';
import 'package:zephyr_reader/src/rust/api/search.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

import 'di/service_locator.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await RustLib.init();
      final appDir = await getApplicationDocumentsDirectory();
      await initStorage(dataDir: '${appDir.path}/zephyr_reader/data');

      try {
        await initSearchEngine();
      } catch (e) {
        Logging.error('搜索索引初始化失败', exception: e);
      }
      await AppConfig.instance.init(
        coverDir: '${appDir.path}/zephyr_reader/covers',
      );
      await configureDependencies();

      FlutterError.onError = (details) {
        Logging.error(
          'Flutter framework 错误',
          exception: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        Logging.error('未捕获的平台错误', exception: error, stackTrace: stack);
        return true;
      };

      ErrorWidget.builder = (details) {
        Logging.error(
          'Widget 构建错误',
          exception: details.exception,
          stackTrace: details.stack,
        );
        return const Material(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '出现了一些问题，应用即将重新启动。',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      };

      runApp(const ZephyrReaderApp());
    },
    (Object error, StackTrace stack) {
      Logging.error('Zone 未捕获错误', exception: error, stackTrace: stack);
    },
  );
}
