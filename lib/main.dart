import 'package:flutter/material.dart';
import 'package:zephyr_reader/app.dart';
import 'package:zephyr_reader/core/app_config.dart';

import 'di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.instance.init();
  await configureDependencies();
  runApp(const MyApp());
}