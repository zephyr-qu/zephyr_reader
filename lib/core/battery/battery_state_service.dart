/// 电池状态服务
///
/// 使用 system_state 包检测电池充电状态
library;

import 'dart:io';

import 'package:system_state/system_state.dart';

/// 电池状态服务单例
class BatteryStateService {
  static final BatteryStateService _instance =
      BatteryStateService._internal();

  factory BatteryStateService() => _instance;

  BatteryStateService._internal();

  /// 检查是否正在充电
  Future<bool> isCharging() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final state = await SystemState.battery.getBatteryState();
      return state.isCharging;
    } catch (e) {
      // 如果无法获取电池状态，默认返回 false
      return false;
    }
  }

  /// 获取当前电池电量 (0 - 100)
  Future<int> getBatteryLevel() async {
    if (!Platform.isAndroid) {
      return 0;
    }
    try {
      final state = await SystemState.battery.getBatteryState();
      return state.batteryLevel;
    } catch (e) {
      return 0;
    }
  }

  /// 获取电池状态
  Future<BatteryState> getBatteryState() async {
    if (!Platform.isAndroid) {
      // 返回默认状态
      return BatteryState.fromMap({
        'batteryLevel': 0,
        'temperature': 0.0,
        'isCharging': false,
      });
    }
    try {
      return await SystemState.battery.getBatteryState();
    } catch (e) {
      return BatteryState.fromMap({
        'batteryLevel': 0,
        'temperature': 0.0,
        'isCharging': false,
      });
    }
  }

  /// 监听电池状态变化
  void listen(void Function(BatteryState state) callback) {
    if (!Platform.isAndroid) {
      return;
    }
    SystemState.battery.listen(callback);
  }
}
