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
