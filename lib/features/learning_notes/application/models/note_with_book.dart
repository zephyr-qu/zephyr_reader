import 'package:zephyr_reader/src/rust/storage/models.dart';

class NoteWithBook {
  final Note note;
  final String bookTitle;
  const NoteWithBook({required this.note, required this.bookTitle});
}
