/// Flutter 分页（方案三 · 条件接受）：Rust 只出 IR，本包负责装箱 + 会话。
///
/// [kFlutterPaginationSpike] 为 `true` 时走本包；
/// 禁止 Rust pagination session / calibration / store_line_breaks。
library;

export 'flutter_block_paginator.dart';
export 'flutter_pagination_session.dart';
export 'flutter_pagination_spike_flag.dart';
export 'flutter_staging_preloader.dart';
export 'slice_height.dart';
export 'slice_rich_spans.dart';
export 'spike_active_chapter_ir.dart';
export 'spike_page.dart';
export 'spike_pagination_session.dart';
export 'spike_progress.dart';
export 'spike_staging_store.dart';
export 'spike_viewport_metrics.dart';
