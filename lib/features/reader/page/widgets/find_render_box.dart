import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Resolves a [RenderBox] from [context], handling sliver-based contexts.
///
/// When [BuildContext.findRenderObject] returns a [RenderSliver] (e.g. inside
/// [ListView.builder] or [PageView.builder] itemBuilder callbacks), walks up
/// the render tree via [RenderObject.parent] to locate the enclosing
/// [RenderBox] (typically a [RenderViewport]).
RenderBox? findRenderBox(BuildContext context) {
  final renderObj = context.findRenderObject();
  if (renderObj == null) return null;
  if (renderObj is RenderBox) return renderObj;

  // Walk up the render tree. A RenderSliver's parent chain leads to
  // RenderViewportBase (a RenderBox) which provides reasonable screen
  // coordinates for toolbar positioning.
  RenderObject? current = renderObj.parent;
  while (current != null && current is! RenderBox) {
    current = current.parent;
  }
  return current as RenderBox?;
}
