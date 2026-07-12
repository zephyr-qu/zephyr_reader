/// Flutter 精确分页（ADR-016）：Rust 只出 IR，本包负责装箱 + 会话 + staging。
///
/// 禁止走 Rust pagination session / 校准写回 / store_line_breaks。
library;

export 'active_chapter_ir.dart';
export 'flutter_block_paginator.dart';
export 'flutter_pagination_session.dart';
export 'flutter_staging_preloader.dart';
export 'packed_page.dart';
export 'pagination_progress.dart';
export 'pagination_progress_hook.dart';
export 'pagination_staging_store.dart';
export 'pagination_viewport_metrics.dart';
export 'slice_height.dart';
export 'slice_rich_spans.dart';
