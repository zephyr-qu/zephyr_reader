import 'package:flutter/material.dart';

/// 动画 Token
///
/// 集中管理全局动画 duration 和 curve，所有 widget 应引用此而非 magic number。
class AnimTokens {
  AnimTokens._();

  // ===== Duration =====

  /// 微交互（按钮反馈、选中态切换、小范围 fade）
  static const Duration fast = Duration(milliseconds: 150);

  /// 选择反馈、选项按钮过渡（200ms）
  static const Duration medium = Duration(milliseconds: 200);

  /// 面板显示/隐藏、容器过渡
  static const Duration normal = Duration(milliseconds: 250);

  /// 页面级切换、Tab 切换
  static const Duration slow = Duration(milliseconds: 300);

  /// 骨架屏 shimmer、Toast 等较长时间
  static const Duration persistent = Duration(seconds: 3);
  /// 滚动动画（scrollTo、scrollController.animateTo）
  static const Duration scroll = Duration(milliseconds: 500);

  // ===== Curve =====

  /// 默认缓动
  static const Curve defaultCurve = Curves.easeInOut;

  /// 强调入场（弹跳感、缩放）
  static const Curve emphasisCurve = Curves.easeOutBack;

  // ===== 典型映射 =====

  /// AnimatedSwitcher / AnimatedCrossFade
  static const switcher = normal;

  /// AnimatedContainer 属性变化
  static const container = normal;

  /// 列表 stagger 入场（需配合 animation-delay）
  static const stagger = Duration(milliseconds: 200);

  /// 骨架屏 shimmer 周期
  static const shimmer = persistent;
}
