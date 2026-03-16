import 'package:flutter/material.dart';

/// 章节内容组件
class ChapterContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final TextAlign? textAlign;
  final double? lineHeight;
  final EdgeInsets? padding;

  const ChapterContent({
    super.key,
    required this.content,
    this.textStyle,
    this.textAlign,
    this.lineHeight,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle =
        textStyle ?? Theme.of(context).textTheme.bodyLarge;
    final effectivePadding = padding ?? const EdgeInsets.all(16);

    return Container(
      padding: effectivePadding,
      child: Text(
        content,
        style: effectiveTextStyle?.copyWith(height: lineHeight ?? 1.6),
        textAlign: textAlign ?? TextAlign.start,
      ),
    );
  }
}
