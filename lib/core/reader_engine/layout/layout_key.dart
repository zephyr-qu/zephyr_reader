import 'package:flutter/foundation.dart';
import 'layout_spec.dart';
/// [LayoutSpec] 的不可变标识，用于布局缓存比较和 staging promote 校验。
///
/// ADR-018：LayoutKey 不同的计划禁止复用或互相 promote。
@immutable
class LayoutKey {
  final BigInt _hash;

  const LayoutKey(this._hash);

  factory LayoutKey.fromSpec(LayoutSpec spec) {
    return LayoutKey(BigInt.from(Object.hash(
      spec.viewportWidth,
      spec.viewportHeight,
      spec.contentPadding,
      spec.fontFamily,
      spec.fontSize,
      spec.lineHeight,
      spec.letterSpacing,
      spec.paragraphSpacing,
      spec.textScaler,
      spec.baselineAlign,
      spec.forceStrutHeight,
      spec.textAlign,
      spec.textDirection,
      spec.textHeightBehavior,
      spec.firstLineIndent,
      spec.punctuationSqueeze,
      spec.language,
      spec.autoSpaceRatio,
    )));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LayoutKey && _hash == other._hash);

  @override
  int get hashCode => _hash.hashCode;

  @override
  String toString() => 'LayoutKey#$_hash';
}
