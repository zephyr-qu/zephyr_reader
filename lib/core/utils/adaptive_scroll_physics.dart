/// 根据平台返回适配的滚动物理效果。
///
/// iOS/macOS → [BouncingScrollPhysics]（弹性回弹）
/// Android/others → [ClampingScrollPhysics]（边界卡停）
///
/// 传入可选的 [physics] 作为父级物理效果链。
library;

import 'package:flutter/material.dart';

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
