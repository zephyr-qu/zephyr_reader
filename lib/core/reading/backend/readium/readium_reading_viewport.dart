import 'package:flutter/material.dart';
import 'package:flureadium/flureadium.dart';

import '../reading_viewport_adapter.dart';
import 'readium_session.dart';

/// Readium viewport adapter wrapping [ReadiumReaderWidget].
class ReadiumReadingViewport implements ReadingViewportAdapter {
  final ReadiumSession session;
  final String filePath;

  ReadiumReadingViewport({
    required this.session,
    required this.filePath,
  });

  @override
  Widget buildViewport(BuildContext context) {
    return _ReadiumViewportWidget(
      session: session,
      filePath: filePath,
    );
  }
}

class _ReadiumViewportWidget extends StatefulWidget {
  final ReadiumSession session;
  final String filePath;

  const _ReadiumViewportWidget({
    required this.session,
    required this.filePath,
  });

  @override
  State<_ReadiumViewportWidget> createState() =>
      _ReadiumViewportWidgetState();
}

class _ReadiumViewportWidgetState extends State<_ReadiumViewportWidget> {
  @override
  Widget build(BuildContext context) {
    final pub = widget.session.publication;
    if (pub == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ReadiumReaderWidget(
      publication: pub,
      onReady: () => widget.session.signalViewportReady(),
    );
  }
}
