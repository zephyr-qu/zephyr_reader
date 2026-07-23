import 'package:flutter/material.dart';
import 'backend/reading_viewport_adapter.dart';

/// Renders the engine-specific viewport widget.
///
/// A thin wrapper around [ReadingViewportAdapter.buildViewport] that
/// exists as a widget so the shell composition stays declarative.
/// The viewport adapter is chosen once at shell construction time and
/// never changes for the lifetime of the shell.
class ReadingViewportHost extends StatelessWidget {
  final ReadingViewportAdapter adapter;

  const ReadingViewportHost({super.key, required this.adapter});

  @override
  Widget build(BuildContext context) => adapter.buildViewport(context);
}
