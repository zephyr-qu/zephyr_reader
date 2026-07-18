/// Flutter 阅读引擎使用的 IR 公共入口。
///
/// 类型由 flutter_rust_bridge 根据 Rust IR 契约生成；引擎内部统一从此处导入。
library;

export 'package:zephyr_reader/src/rust/pipeline/types.dart'
    show
        BlockStyle,
        ReaderChapterIr,
        ReaderInlineRun,
        ReaderInlineStyle,
        ReaderIrBlock,
        ReaderIrBlockKind;
