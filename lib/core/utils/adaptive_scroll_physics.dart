/// 根据平台返回适配的 [ScrollPhysics]。
///
/// iOS/macOS → [BouncingScrollPhysics]（弹性回弹）；
/// Android/others → [ClampingScrollPhysics]（边界卡停）。
///
/// [context] 用于读取平台信息；[physics] 为可选的父级物理效果链。

import 'package:flutter/material.dart';

/// 根据平台返回适配的 [ScrollPhysics]。
///
/// iOS/macOS → [BouncingScrollPhysics]（弹性回弹）；
/// Android/others → [ClampingScrollPhysics]（边界卡停）。
///
/// [context] 用于读取平台信息；[physics] 为可选的父级物理效果链。
ScrollPhysics adaptiveScrollPhysics(
  BuildContext context, {
  ScrollPhysics? physics,
}) {
  switch (Theme.of(context).platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return BouncingScrollPhysics(parent: physics);
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return ClampingScrollPhysics(parent: physics);
  }
}
