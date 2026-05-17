# AGENTS.md — Zephyr Reader

## Project Context
Flutter 3.41.2 + Dart 3.11.0 e-reader app using flutter_rust_bridge, signals, injectable, freezed. Reading modes: scroll, pagination, bilingual.

## Architecture
- `lib/core/` — shared infrastructure (theme, routing, logging, storage services)
- `lib/features/{reader,bookshelf,home,statistics,profile,sync}/` — feature modules
- Each feature has `page/`, `application/`, `domain/`, `data/` layers (some incomplete)
- `lib/di/` — dependency injection via injectable/getIt
- State management: signals (injectable singletons) + StatefulWidget setState

## Build & Test
- `flutter build apk` / `flutter build ios`
- `flutter analyze`
- `flutter test` (existing tests in `test/features/reader/`, `test/features/sync/`)

## Session Summary (2026-05-17)

### Completed (this session + previous)

**P0 Reading Modes**
- Scroll/pagination/bilingual reading modes with virtualized ListView.builder + approximate pagination
- Pre-rendering buffer: 3 chapters ahead/behind after every loadChapter()
- Hybrid pagination: all chapters use character-estimation at paragraph boundaries
- Dead code removed: _sliceTextSpan, _spanTextLength, _paginateWithTextPainter

**P0 Font & Layout**
- Font stack fallback (Noto Sans SC → PingFang SC → Noto Sans CJK SC → SF Pro → sans-serif)
- CJK/Latin baseline alignment via StrutStyle(forceStrutHeight: true)

**P1 Highlights & Annotations**
- Highlight rendering with HighlightPainter + TapGestureRecognizer for edit/delete
- Selection toolbar: "高亮" / "笔记" / "查词" / "生词本" / "标注两侧" buttons
- Annotation dialog + highlight edit/delete bottom sheet
- Highlights loaded on every loadChapter() via loadHighlights()
- P1 analyzer fixes (import paths, BigInt→int, SelectionChangedCallback 2-arg form on 7 lambdas)

**P2 Custom Fonts**
- Custom font registration: FontLoader → FontRepository → FontConfig
- FontConfig.readerStyle()/readerStrut() with fontFamily override

**P2 Backend & Infrastructure**
- Backup/restore: RustStorageService.exportDatabase/restoreDatabase + FilePicker
- Home page connected to real RustStorageService (recent books + global stats)
- Statistics pages (statistics_page.dart + reading_stats_page.dart) using ReadingStatsService real data
- All 15 analyzer warnings fixed (async gap context.mounted, curly braces, __ → _, RadioGroup)
- Bookmark delete fixed: hashCode → String id on 4 call sites
- Category color restored: hex string → Color extension

**Dictionary Feature**
- scripts/build_dictionary.py: downloads CC-CEDICT → parses → outputs assets/dictionary.db (124,920 entries, 25MB SQLite with FTS5 unicode61 index)
- pubspec.yaml: registered assets/dictionary.db
- rust/src/api/dictionary.rs: init_dictionary(), lookup_word(), fuzzy_search_dictionary(), search_dictionary_definitions(), segment_text() (jieba), get_dictionary_info()
- rust/src/api/vocabulary.rs: add_vocabulary_word(), get_vocabulary_words(), search_vocabulary(), update_vocabulary_status(), delete_vocabulary_word(), get_vocabulary_stats()
- Note model extended: paired_note_id: Option<String> + language: Option<String> (Rust struct, migration SQL, note_repo.rs, FRB-generated Dart)
- FRB codegen completed successfully; cargo check passes
- lib/features/reader/data/dictionary_service.dart: @injectable, auto-copies .db from assets, wraps all Rust API calls
- SelectionToolbar updated: optional onLookup / onAddToVocabulary callbacks with green/purple buttons
- Dictionary panel: _showDictionaryPanel() bottom sheet with word/pinyin/definitions/segments/「加入生词本」button
- Vocabulary empty handler: _addToVocabulary() placeholder with SnackBar
- DI registration: DictionaryService auto-registered by injectable_generator

**Vocabulary Feature**
- lib/features/vocabulary/data/vocabulary_service.dart: @injectable, wraps Rust vocabulary API
- lib/features/vocabulary/application/vocabulary_view_model.dart: signals-based state management (words, stats, loading, filter, search)
- lib/features/vocabulary/page/vocabulary_page.dart: AppBar + stats row + filter chips + ListView with swipe-delete and status PopupMenuButton
- Route constants: RoutePaths.vocabulary = '/vocabulary', RouteNames.vocabulary = 'vocabulary'
- App router: GoRoute with const VocabularyPage() builder

**Bilingual Highlight Linking**
- rust/src/storage/repos/note_repo.rs: added get_note_by_paired_id(), find_partner_note(), get_paired_notes_in_chapter()
- rust/src/api/bilingual_highlight.rs: create_bilingual_highlight_pair(), get_bilingual_highlight_pairs(), delete_bilingual_highlight_pair()
- BilingualHighlightPair model: source_note + target_note linked via paired_note_id
- Wired into rust/src/api/mod.rs as bilingual_highlight module + re-exports
- FRB codegen + cargo check pass
- UI complete: SelectionToolbar "标注两侧" button (pink), reader_page.dart alignment-segment → target offset → createBilingualHighlightPair(), reader_content.dart bilingual mode cn/en highlight separation with offset clipping

**Sync Service Refactored**
- 5 service files merged into 1 (webdav_sync_service.dart, 2409 lines)
- 4 files deleted; code reduced 3557→2409 lines (~32%)
- 4 page imports updated

**In-Page Search (New)**
- ReaderSearchBar: overlay text field + prev/next + match count
- HighlightPainter extended: searchQuery + searchMatchHighlight params for paintPlain/paintRich
- ReaderPage converted from StatelessWidget → StatefulWidget for TextEditingController lifecycle
- All call sites (plain, rich, bilingual) updated to pass search params

**Note Export (Markdown) (New)**
- note_manage_page.dart: export button + _exportMarkdown() → formatted .md with headings, original text, annotations, timestamps
- Uses path_provider to write to app documents directory; SnackBar with file path

**EPUB Image Lazy Loading (New)**
- Rust: get_chapter_content_rich() now resolves image sources after HTML parsing — calls epub_file.read_resource_bytes(src) for each <img> placeholder, populates RichParagraph.image_data
- Dart: rust_reader_repository.dart caches raw List<RichParagraph> per chapter (new _richParagraphCache)
- reader_content.dart: _buildRichScrollWithImages() interleaves Image.memory() widgets between text paragraphs, preserving original order, with error fallback and rounded corners

**Note Sidebar in Reader (New)**
- reader_note_sidebar.dart: new Drawer widget showing all notes/highlights for current book
- reader_page.dart: Scaffold endDrawer + GlobalKey<ScaffoldState> to open/close
- ReaderToolbar: added onShowNotes callback and button (replaces note manage route)
- Note anchor jump: onNoteTap → vm.loadChapter(chapterIndex) for note→position navigation
- CFI anchor persistence: ReaderNoteSidebar.onNoteTap + vm.loadChapter for note-to-chapter jump (uses char_offset)

**Vertical Writing Mode (New)**
- WritingDirection enum (horizontal/vertical) + signal in ReaderViewModel
- Settings panel toggle: 横排/竖排 choice chips
- _buildVerticalScrollMode(): horizontal RTL ListView + 1-char width columns for vertical text flow

**Letter/Paragraph/Page Margin Settings (New)**
- reader_view_model.dart: letterSpacing / paragraphSpacing / pageMargin signals + setters
- reader_settings_panel.dart: 4 new sliders (字间距 0-8px, 段间距 4-32px, 页边距 8-40px, 书写方向 toggle)
- FontConfig.readerStyle(): new letterSpacing param applied to all text styles
- reader_content.dart: all hardcoded 12px/16px padding replaced with paragraphSpacing/pageMargin

**Reading Background Color & Brightness (New)**
- 5 background color presets (default/sepia/cream/green/gray) via ReaderBgColors
- Brightness overlay: semi-transparent black Container in reader Stack
- Controls added to ReaderSettingsPanel (color chips + brightness slider)
- ViewModel signals: readerBgColorIndex, brightnessOverlay

**Stale Test Stubs Removed**
- test/features/bookshelf_test.dart (fully commented out, old drift architecture)
- test/features/reader/bookmark_manage_page_test.dart (fully commented out)
- test/features/reader/reader_content_test.dart (fully commented out)
- .gitkeep added to: lib/features/bookshelf/domain/models/, lib/features/bookshelf/page/widgets/, test/core/database/, test/features/bookshelf/

### Known Issues
- 2 test failures in webdav_sync_service_test due to MissingPluginException (flutter_secure_storage) — expected in non-native test env
- Missing feature layers: home/statistics lack application/data/domain directories
- No Rust tests in rust/tests/

### Key Libraries
- fl_chart — bar charts in statistics
- file_picker — backup/restore file selection
- package_info_plus — app version display
- flutter_rust_bridge — Rust ↔ Dart FFI
- signals + signals_flutter — reactive state management
- injectable + getIt — DI
- freezed — immutable data classes
- go_router — declarative navigation
- jieba-rs — Chinese word segmentation (reused in dictionary API)

### Critical Context
- PlatformInt64 from flutter_rust_bridge is int on 64-bit, not BigInt
- SelectionChangedCallback in Flutter 3.41: void Function(TextSelection, SelectionChangedCause?) — all 7 lambdas updated
- FontLoader must be imported from package:flutter/services.dart (not re-exported by material.dart)
- CC-CEDICT format: Traditional Simplified [pinyin] /def1/def2/ — 124,920 entries processed
- Dictionary DB schema: dictionary_entries (simplified, traditional, pinyin, definitions) + dictionary_fts (FTS5 with unicode61 tokenizer)
- FRB codegen input: rust_input: crate::api in flutter_rust_bridge.yaml; output: lib/src/rust/
- After adding new Rust API functions, always run flutter_rust_bridge_codegen generate then cargo check
- sqlx::migrate!("./migrations") runs in StorageManager::new() — all tables in single init migration file
- vocabulary_words table added to existing migration SQL file (incremental migration not needed for dev)
- Dictionary stored as separate read-only SQLite DB file (not merged into reader.db)
- Vocabulary as fully separated feature module with its own page/route

### Relevant Files

**Dictionary**
- scripts/build_dictionary.py
- rust/src/api/dictionary.rs
- rust/src/api/vocabulary.rs
- lib/features/reader/data/dictionary_service.dart
- lib/features/reader/page/reader_page.dart (_showDictionaryPanel, _addToVocabulary)
- lib/features/reader/page/widgets/selection_toolbar.dart (onLookup, onAddToVocabulary)
- assets/dictionary.db

**Vocabulary**
- lib/features/vocabulary/data/vocabulary_service.dart
- lib/features/vocabulary/application/vocabulary_view_model.dart
- lib/features/vocabulary/page/vocabulary_page.dart
- lib/core/routing/route_constants.dart (vocabulary route)
- lib/core/routing/app_router.dart (vocabulary GoRoute)

**Bilingual Highlight**
- rust/src/api/bilingual_highlight.rs
- rust/src/storage/repos/note_repo.rs (get_note_by_paired_id, find_partner_note, get_paired_notes_in_chapter)
- rust/src/api/mod.rs (bilingual_highlight module + re-exports)

**Core Model Changes**
- rust/src/storage/models.rs (Note: paired_note_id, language)
- rust/migrations/20240506000000_init.sql (paired_note_id, language columns + vocabulary_words table)

**Auto-generated**
- lib/src/rust/api/dictionary.dart
- lib/src/rust/api/vocabulary.dart
- lib/src/rust/api/storage.dart (Note with pairedNoteId/language)
- lib/src/rust/frb_generated.dart
- lib/src/rust/frb_generated.io.dart
- lib/src/rust/frb_generated.web.dart
