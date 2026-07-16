/// 纯 Dart 侧 IR 类型（替代 FRB `pipeline/types.dart`）。
///
/// 这些类型在 Rust→Dart 边界处由 [`ChapterContentRepository`] 从 FRB 类型转换而来，
/// 下游代码不再依赖 FRB 序列化。
library;

export 'package:zephyr_reader/src/rust/pipeline/types.dart'
    show
        ReaderChapterIr,
        ReaderInlineRun,
        ReaderInlineStyle,
        ReaderIrBlock,
        ReaderIrBlockKind;
