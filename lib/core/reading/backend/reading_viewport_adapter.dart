import 'package:flutter/widgets.dart';

/// Viewport adapter that builds an engine-specific body widget.
/// - [BuiltinReadingViewport] returns [ReaderContentArea]
/// - ReadiumReadingViewport returns [ReadiumReaderWidget]
///
/// The page shell calls [buildViewport] without knowing which engine
/// produced the widget. All engine-specific imports live inside the
/// adapter implementation — never in the page shell.
abstract interface class ReadingViewportAdapter {
  /// Build the body widget for this engine's viewport.
  Widget buildViewport(BuildContext context);
}
