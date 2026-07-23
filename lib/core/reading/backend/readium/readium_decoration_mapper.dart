import 'dart:ui' show Color;

import 'package:flureadium/flureadium.dart';
import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import '../../position/reading_position.dart';
import '../../position/readium_position_mapper.dart';

/// Maps [Note] (highlight/annotation) to [ReaderDecoration] for the
/// Readium rendering engine.
///
/// ## Conversion chain
///
/// ```
/// Note (chapterIndex, charOffset, selectedText, highlightColor)
///   → ReadingPosition (chapterIndex, charOffsetUtf16)
///   → ReadiumPositionMapper.positionToLocator
///   → Locator
///   → ReaderDecoration
/// ```
class ReadiumDecorationMapper {
  const ReadiumDecorationMapper();

  /// Convert a single highlight [Note] to a [ReaderDecoration].
  ///
  /// Returns `null` if the note can't be mapped (e.g. not a highlight,
  /// or mapping to Locator fails).
  ReaderDecoration? noteToDecoration({
    required Note note,
    required Map<int, String> hrefMapping,
    required String Function(int chapterIndex) getChapterPlainText,
  }) {
    if (note.noteType != NoteType.highlight) return null;

    final locator = _buildLocator(
      chapterIndex: note.chapterIndex.toInt(),
      charOffset: note.charOffset.toInt(),
      selectedText: note.selectedText,
      hrefMapping: hrefMapping,
      getChapterPlainText: getChapterPlainText,
    );
    if (locator == null) return null;

    return ReaderDecoration(
      id: note.id,
      locator: locator,
      style: ReaderDecorationStyle(
        style: DecorationStyle.highlight,
        tint: _mapColor(note.highlightColor?.toInt()),
      ),
    );
  }

  /// Convert all highlight [Note]s to [ReaderDecoration]s.
  List<ReaderDecoration> notesToDecorations({
    required List<Note> notes,
    required Map<int, String> hrefMapping,
    required String Function(int chapterIndex) getChapterPlainText,
  }) {
    final decorations = <ReaderDecoration>[];
    for (final note in notes) {
      final deco = noteToDecoration(
        note: note,
        hrefMapping: hrefMapping,
        getChapterPlainText: getChapterPlainText,
      );
      if (deco != null) {
        decorations.add(deco);
      }
    }
    return decorations;
  }

  /// Build a [Locator] from the note's position.
  Locator? _buildLocator({
    required int chapterIndex,
    required int charOffset,
    required String? selectedText,
    required Map<int, String> hrefMapping,
    required String Function(int chapterIndex) getChapterPlainText,
  }) {
    final position = ReadingPosition(
      chapterIndex: chapterIndex,
      charOffsetUtf16: charOffset,
    );
    return ReadiumPositionMapper.positionToLocator(
      position: position,
      hrefMapping: hrefMapping,
      getChapterPlainText: getChapterPlainText,
    );
  }

  /// Map a Rust highlight color (int) to a Dart [Color].
  ///
  /// Rust uses ARGB hex (e.g. 0xFFFF0000 for full-opacity red).
  /// Falls back to semi-transparent yellow when null.
  Color _mapColor(int? rustColor) {
    if (rustColor == null) {
      return const Color(0x33FFEB3B); // semi-transparent yellow
    }
    // Rust passes ARGB as a 64-bit signed int, but the color space
    // fits in 32 bits. Mask to 32-bit ARGB.
    return Color(rustColor & 0xFFFFFFFF);
  }
}
