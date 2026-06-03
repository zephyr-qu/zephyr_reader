import 'dart:io';

import 'package:system_state/system_state.dart';
import 'package:zephyr_reader/core/utils/platform_guard.dart';

class BatteryStateService {
  BatteryStateService._internal();

  factory BatteryStateService() => _instance;
  static final BatteryStateService _instance = BatteryStateService._internal();

  Future<bool> isCharging() async => guardAndroid(
    () async => (await SystemState.battery.getBatteryState()).isCharging,
    false,
  );

  Future<int> getBatteryLevel() async => guardAndroid(
    () async => (await SystemState.battery.getBatteryState()).batteryLevel,
    0,
  );

  Future<BatteryState> getBatteryState() async => guardAndroid(
    () async => await SystemState.battery.getBatteryState(),
    BatteryState.fromMap({'level': 0, 'temperature': 0, 'isCharging': false}),
  );

  void listen(void Function(BatteryState state) callback) {
    if (!Platform.isAndroid) return;
    SystemState.battery.listen(callback);
  }
}
