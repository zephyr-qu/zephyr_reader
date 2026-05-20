library;

import 'dart:io';

import 'package:system_state/system_state.dart';

class BatteryStateService {
  BatteryStateService._internal();

  factory BatteryStateService() => _instance;
  static final BatteryStateService _instance = BatteryStateService._internal();

  Future<T> _guardAndroid<T>(Future<T> Function() fn, T defaultValue) async {
    if (!Platform.isAndroid) return defaultValue;
    try {
      return await fn();
    } catch (_) {
      return defaultValue;
    }
  }

  Future<bool> isCharging() async => _guardAndroid(
    () async => (await SystemState.battery.getBatteryState()).isCharging,
    false,
  );

  Future<int> getBatteryLevel() async => _guardAndroid(
    () async => (await SystemState.battery.getBatteryState()).batteryLevel,
    0,
  );

  Future<BatteryState> getBatteryState() async => _guardAndroid(
    () async => await SystemState.battery.getBatteryState(),
    BatteryState.fromMap({
      'batteryLevel': 0,
      'temperature': 0.0,
      'isCharging': false,
    }),
  );

  void listen(void Function(BatteryState state) callback) {
    if (!Platform.isAndroid) return;
    SystemState.battery.listen(callback);
  }
}
