import 'package:flutter/widgets.dart';
import 'reading_viewport_adapter.dart';

/// Placeholder viewport that renders nothing.
///
/// Used when a reading session is created by the factory but the
/// real viewport is provided later by the shell (e.g. Builtin's
/// viewport needs UI-scoped signals).
class PlaceholderViewport implements ReadingViewportAdapter {
  const PlaceholderViewport();

  @override
  Widget buildViewport(BuildContext context) {
    return const SizedBox.shrink();
  }
}
