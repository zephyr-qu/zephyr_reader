// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RichTextSpan {

 String get text;
/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpanCopyWith<RichTextSpan> get copyWith => _$RichTextSpanCopyWithImpl<RichTextSpan>(this as RichTextSpan, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpanCopyWith<$Res>  {
  factory $RichTextSpanCopyWith(RichTextSpan value, $Res Function(RichTextSpan) _then) = _$RichTextSpanCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpanCopyWithImpl<$Res>
    implements $RichTextSpanCopyWith<$Res> {
  _$RichTextSpanCopyWithImpl(this._self, this._then);

  final RichTextSpan _self;
  final $Res Function(RichTextSpan) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RichTextSpan].
extension RichTextSpanPatterns on RichTextSpan {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( RichTextSpan_Plain value)?  plain,TResult Function( RichTextSpan_Bold value)?  bold,TResult Function( RichTextSpan_Italic value)?  italic,TResult Function( RichTextSpan_BoldItalic value)?  boldItalic,TResult Function( RichTextSpan_Underline value)?  underline,TResult Function( RichTextSpan_Strikethrough value)?  strikethrough,TResult Function( RichTextSpan_Code value)?  code,TResult Function( RichTextSpan_Link value)?  link,required TResult orElse(),}){
final _that = this;
switch (_that) {
case RichTextSpan_Plain() when plain != null:
return plain(_that);case RichTextSpan_Bold() when bold != null:
return bold(_that);case RichTextSpan_Italic() when italic != null:
return italic(_that);case RichTextSpan_BoldItalic() when boldItalic != null:
return boldItalic(_that);case RichTextSpan_Underline() when underline != null:
return underline(_that);case RichTextSpan_Strikethrough() when strikethrough != null:
return strikethrough(_that);case RichTextSpan_Code() when code != null:
return code(_that);case RichTextSpan_Link() when link != null:
return link(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( RichTextSpan_Plain value)  plain,required TResult Function( RichTextSpan_Bold value)  bold,required TResult Function( RichTextSpan_Italic value)  italic,required TResult Function( RichTextSpan_BoldItalic value)  boldItalic,required TResult Function( RichTextSpan_Underline value)  underline,required TResult Function( RichTextSpan_Strikethrough value)  strikethrough,required TResult Function( RichTextSpan_Code value)  code,required TResult Function( RichTextSpan_Link value)  link,}){
final _that = this;
switch (_that) {
case RichTextSpan_Plain():
return plain(_that);case RichTextSpan_Bold():
return bold(_that);case RichTextSpan_Italic():
return italic(_that);case RichTextSpan_BoldItalic():
return boldItalic(_that);case RichTextSpan_Underline():
return underline(_that);case RichTextSpan_Strikethrough():
return strikethrough(_that);case RichTextSpan_Code():
return code(_that);case RichTextSpan_Link():
return link(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( RichTextSpan_Plain value)?  plain,TResult? Function( RichTextSpan_Bold value)?  bold,TResult? Function( RichTextSpan_Italic value)?  italic,TResult? Function( RichTextSpan_BoldItalic value)?  boldItalic,TResult? Function( RichTextSpan_Underline value)?  underline,TResult? Function( RichTextSpan_Strikethrough value)?  strikethrough,TResult? Function( RichTextSpan_Code value)?  code,TResult? Function( RichTextSpan_Link value)?  link,}){
final _that = this;
switch (_that) {
case RichTextSpan_Plain() when plain != null:
return plain(_that);case RichTextSpan_Bold() when bold != null:
return bold(_that);case RichTextSpan_Italic() when italic != null:
return italic(_that);case RichTextSpan_BoldItalic() when boldItalic != null:
return boldItalic(_that);case RichTextSpan_Underline() when underline != null:
return underline(_that);case RichTextSpan_Strikethrough() when strikethrough != null:
return strikethrough(_that);case RichTextSpan_Code() when code != null:
return code(_that);case RichTextSpan_Link() when link != null:
return link(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  plain,TResult Function( String text)?  bold,TResult Function( String text)?  italic,TResult Function( String text)?  boldItalic,TResult Function( String text)?  underline,TResult Function( String text)?  strikethrough,TResult Function( String text)?  code,TResult Function( String text,  String url)?  link,required TResult orElse(),}) {final _that = this;
switch (_that) {
case RichTextSpan_Plain() when plain != null:
return plain(_that.text);case RichTextSpan_Bold() when bold != null:
return bold(_that.text);case RichTextSpan_Italic() when italic != null:
return italic(_that.text);case RichTextSpan_BoldItalic() when boldItalic != null:
return boldItalic(_that.text);case RichTextSpan_Underline() when underline != null:
return underline(_that.text);case RichTextSpan_Strikethrough() when strikethrough != null:
return strikethrough(_that.text);case RichTextSpan_Code() when code != null:
return code(_that.text);case RichTextSpan_Link() when link != null:
return link(_that.text,_that.url);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  plain,required TResult Function( String text)  bold,required TResult Function( String text)  italic,required TResult Function( String text)  boldItalic,required TResult Function( String text)  underline,required TResult Function( String text)  strikethrough,required TResult Function( String text)  code,required TResult Function( String text,  String url)  link,}) {final _that = this;
switch (_that) {
case RichTextSpan_Plain():
return plain(_that.text);case RichTextSpan_Bold():
return bold(_that.text);case RichTextSpan_Italic():
return italic(_that.text);case RichTextSpan_BoldItalic():
return boldItalic(_that.text);case RichTextSpan_Underline():
return underline(_that.text);case RichTextSpan_Strikethrough():
return strikethrough(_that.text);case RichTextSpan_Code():
return code(_that.text);case RichTextSpan_Link():
return link(_that.text,_that.url);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  plain,TResult? Function( String text)?  bold,TResult? Function( String text)?  italic,TResult? Function( String text)?  boldItalic,TResult? Function( String text)?  underline,TResult? Function( String text)?  strikethrough,TResult? Function( String text)?  code,TResult? Function( String text,  String url)?  link,}) {final _that = this;
switch (_that) {
case RichTextSpan_Plain() when plain != null:
return plain(_that.text);case RichTextSpan_Bold() when bold != null:
return bold(_that.text);case RichTextSpan_Italic() when italic != null:
return italic(_that.text);case RichTextSpan_BoldItalic() when boldItalic != null:
return boldItalic(_that.text);case RichTextSpan_Underline() when underline != null:
return underline(_that.text);case RichTextSpan_Strikethrough() when strikethrough != null:
return strikethrough(_that.text);case RichTextSpan_Code() when code != null:
return code(_that.text);case RichTextSpan_Link() when link != null:
return link(_that.text,_that.url);case _:
  return null;

}
}

}

/// @nodoc


class RichTextSpan_Plain extends RichTextSpan {
  const RichTextSpan_Plain({required this.text}): super._();
  

@override final  String text;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_PlainCopyWith<RichTextSpan_Plain> get copyWith => _$RichTextSpan_PlainCopyWithImpl<RichTextSpan_Plain>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_Plain&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan.plain(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_PlainCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_PlainCopyWith(RichTextSpan_Plain value, $Res Function(RichTextSpan_Plain) _then) = _$RichTextSpan_PlainCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpan_PlainCopyWithImpl<$Res>
    implements $RichTextSpan_PlainCopyWith<$Res> {
  _$RichTextSpan_PlainCopyWithImpl(this._self, this._then);

  final RichTextSpan_Plain _self;
  final $Res Function(RichTextSpan_Plain) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RichTextSpan_Plain(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RichTextSpan_Bold extends RichTextSpan {
  const RichTextSpan_Bold({required this.text}): super._();
  

@override final  String text;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_BoldCopyWith<RichTextSpan_Bold> get copyWith => _$RichTextSpan_BoldCopyWithImpl<RichTextSpan_Bold>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_Bold&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan.bold(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_BoldCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_BoldCopyWith(RichTextSpan_Bold value, $Res Function(RichTextSpan_Bold) _then) = _$RichTextSpan_BoldCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpan_BoldCopyWithImpl<$Res>
    implements $RichTextSpan_BoldCopyWith<$Res> {
  _$RichTextSpan_BoldCopyWithImpl(this._self, this._then);

  final RichTextSpan_Bold _self;
  final $Res Function(RichTextSpan_Bold) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RichTextSpan_Bold(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RichTextSpan_Italic extends RichTextSpan {
  const RichTextSpan_Italic({required this.text}): super._();
  

@override final  String text;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_ItalicCopyWith<RichTextSpan_Italic> get copyWith => _$RichTextSpan_ItalicCopyWithImpl<RichTextSpan_Italic>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_Italic&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan.italic(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_ItalicCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_ItalicCopyWith(RichTextSpan_Italic value, $Res Function(RichTextSpan_Italic) _then) = _$RichTextSpan_ItalicCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpan_ItalicCopyWithImpl<$Res>
    implements $RichTextSpan_ItalicCopyWith<$Res> {
  _$RichTextSpan_ItalicCopyWithImpl(this._self, this._then);

  final RichTextSpan_Italic _self;
  final $Res Function(RichTextSpan_Italic) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RichTextSpan_Italic(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RichTextSpan_BoldItalic extends RichTextSpan {
  const RichTextSpan_BoldItalic({required this.text}): super._();
  

@override final  String text;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_BoldItalicCopyWith<RichTextSpan_BoldItalic> get copyWith => _$RichTextSpan_BoldItalicCopyWithImpl<RichTextSpan_BoldItalic>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_BoldItalic&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan.boldItalic(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_BoldItalicCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_BoldItalicCopyWith(RichTextSpan_BoldItalic value, $Res Function(RichTextSpan_BoldItalic) _then) = _$RichTextSpan_BoldItalicCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpan_BoldItalicCopyWithImpl<$Res>
    implements $RichTextSpan_BoldItalicCopyWith<$Res> {
  _$RichTextSpan_BoldItalicCopyWithImpl(this._self, this._then);

  final RichTextSpan_BoldItalic _self;
  final $Res Function(RichTextSpan_BoldItalic) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RichTextSpan_BoldItalic(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RichTextSpan_Underline extends RichTextSpan {
  const RichTextSpan_Underline({required this.text}): super._();
  

@override final  String text;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_UnderlineCopyWith<RichTextSpan_Underline> get copyWith => _$RichTextSpan_UnderlineCopyWithImpl<RichTextSpan_Underline>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_Underline&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan.underline(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_UnderlineCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_UnderlineCopyWith(RichTextSpan_Underline value, $Res Function(RichTextSpan_Underline) _then) = _$RichTextSpan_UnderlineCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpan_UnderlineCopyWithImpl<$Res>
    implements $RichTextSpan_UnderlineCopyWith<$Res> {
  _$RichTextSpan_UnderlineCopyWithImpl(this._self, this._then);

  final RichTextSpan_Underline _self;
  final $Res Function(RichTextSpan_Underline) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RichTextSpan_Underline(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RichTextSpan_Strikethrough extends RichTextSpan {
  const RichTextSpan_Strikethrough({required this.text}): super._();
  

@override final  String text;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_StrikethroughCopyWith<RichTextSpan_Strikethrough> get copyWith => _$RichTextSpan_StrikethroughCopyWithImpl<RichTextSpan_Strikethrough>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_Strikethrough&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan.strikethrough(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_StrikethroughCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_StrikethroughCopyWith(RichTextSpan_Strikethrough value, $Res Function(RichTextSpan_Strikethrough) _then) = _$RichTextSpan_StrikethroughCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpan_StrikethroughCopyWithImpl<$Res>
    implements $RichTextSpan_StrikethroughCopyWith<$Res> {
  _$RichTextSpan_StrikethroughCopyWithImpl(this._self, this._then);

  final RichTextSpan_Strikethrough _self;
  final $Res Function(RichTextSpan_Strikethrough) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RichTextSpan_Strikethrough(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RichTextSpan_Code extends RichTextSpan {
  const RichTextSpan_Code({required this.text}): super._();
  

@override final  String text;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_CodeCopyWith<RichTextSpan_Code> get copyWith => _$RichTextSpan_CodeCopyWithImpl<RichTextSpan_Code>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_Code&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'RichTextSpan.code(text: $text)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_CodeCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_CodeCopyWith(RichTextSpan_Code value, $Res Function(RichTextSpan_Code) _then) = _$RichTextSpan_CodeCopyWithImpl;
@override @useResult
$Res call({
 String text
});




}
/// @nodoc
class _$RichTextSpan_CodeCopyWithImpl<$Res>
    implements $RichTextSpan_CodeCopyWith<$Res> {
  _$RichTextSpan_CodeCopyWithImpl(this._self, this._then);

  final RichTextSpan_Code _self;
  final $Res Function(RichTextSpan_Code) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(RichTextSpan_Code(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class RichTextSpan_Link extends RichTextSpan {
  const RichTextSpan_Link({required this.text, required this.url}): super._();
  

@override final  String text;
 final  String url;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RichTextSpan_LinkCopyWith<RichTextSpan_Link> get copyWith => _$RichTextSpan_LinkCopyWithImpl<RichTextSpan_Link>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RichTextSpan_Link&&(identical(other.text, text) || other.text == text)&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode => Object.hash(runtimeType,text,url);

@override
String toString() {
  return 'RichTextSpan.link(text: $text, url: $url)';
}


}

/// @nodoc
abstract mixin class $RichTextSpan_LinkCopyWith<$Res> implements $RichTextSpanCopyWith<$Res> {
  factory $RichTextSpan_LinkCopyWith(RichTextSpan_Link value, $Res Function(RichTextSpan_Link) _then) = _$RichTextSpan_LinkCopyWithImpl;
@override @useResult
$Res call({
 String text, String url
});




}
/// @nodoc
class _$RichTextSpan_LinkCopyWithImpl<$Res>
    implements $RichTextSpan_LinkCopyWith<$Res> {
  _$RichTextSpan_LinkCopyWithImpl(this._self, this._then);

  final RichTextSpan_Link _self;
  final $Res Function(RichTextSpan_Link) _then;

/// Create a copy of RichTextSpan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? url = null,}) {
  return _then(RichTextSpan_Link(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
