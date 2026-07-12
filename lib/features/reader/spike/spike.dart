/// Flutter 分页实验（方案三）：Rust 只出 IR，本包负责装箱 + 会话旁路。
///
/// **默认关闭**。[kFlutterPaginationSpike] 为 `true` 时走本包，
/// 禁止 Rust pagination session / calibration / store_line_breaks。
library;

export 'flutter_block_paginator.dart';
export 'flutter_pagination_session.dart';
export 'flutter_pagination_spike_flag.dart';
export 'flutter_staging_preloader.dart';
export 'spike_page.dart';
export 'spike_pagination_session.dart';
export 'spike_progress.dart';
export 'spike_staging_store.dart';
