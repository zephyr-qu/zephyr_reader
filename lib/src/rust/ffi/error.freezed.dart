// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ParserError {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ParserError()';
}


}

/// @nodoc
class $ParserErrorCopyWith<$Res>  {
$ParserErrorCopyWith(ParserError _, $Res Function(ParserError) __);
}


/// Adds pattern-matching-related methods to [ParserError].
extension ParserErrorPatterns on ParserError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ParserError_FileNotFound value)?  fileNotFound,TResult Function( ParserError_FileReadError value)?  fileReadError,TResult Function( ParserError_EncodingError value)?  encodingError,TResult Function( ParserError_EpubParseError value)?  epubParseError,TResult Function( ParserError_PdfParseError value)?  pdfParseError,TResult Function( ParserError_TxtParseError value)?  txtParseError,TResult Function( ParserError_ChapterExtractError value)?  chapterExtractError,TResult Function( ParserError_Typeset value)?  typeset,TResult Function( ParserError_StreamError value)?  streamError,TResult Function( ParserError_UnsupportedFormat value)?  unsupportedFormat,TResult Function( ParserError_FileWriteError value)?  fileWriteError,TResult Function( ParserError_InternalError value)?  internalError,TResult Function( ParserError_ConfigError value)?  configError,TResult Function( ParserError_PageExtractError value)?  pageExtractError,TResult Function( ParserError_TextExtractError value)?  textExtractError,TResult Function( ParserError_Other value)?  other,TResult Function( ParserError_SecurityError value)?  securityError,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ParserError_FileNotFound() when fileNotFound != null:
return fileNotFound(_that);case ParserError_FileReadError() when fileReadError != null:
return fileReadError(_that);case ParserError_EncodingError() when encodingError != null:
return encodingError(_that);case ParserError_EpubParseError() when epubParseError != null:
return epubParseError(_that);case ParserError_PdfParseError() when pdfParseError != null:
return pdfParseError(_that);case ParserError_TxtParseError() when txtParseError != null:
return txtParseError(_that);case ParserError_ChapterExtractError() when chapterExtractError != null:
return chapterExtractError(_that);case ParserError_Typeset() when typeset != null:
return typeset(_that);case ParserError_StreamError() when streamError != null:
return streamError(_that);case ParserError_UnsupportedFormat() when unsupportedFormat != null:
return unsupportedFormat(_that);case ParserError_FileWriteError() when fileWriteError != null:
return fileWriteError(_that);case ParserError_InternalError() when internalError != null:
return internalError(_that);case ParserError_ConfigError() when configError != null:
return configError(_that);case ParserError_PageExtractError() when pageExtractError != null:
return pageExtractError(_that);case ParserError_TextExtractError() when textExtractError != null:
return textExtractError(_that);case ParserError_Other() when other != null:
return other(_that);case ParserError_SecurityError() when securityError != null:
return securityError(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ParserError_FileNotFound value)  fileNotFound,required TResult Function( ParserError_FileReadError value)  fileReadError,required TResult Function( ParserError_EncodingError value)  encodingError,required TResult Function( ParserError_EpubParseError value)  epubParseError,required TResult Function( ParserError_PdfParseError value)  pdfParseError,required TResult Function( ParserError_TxtParseError value)  txtParseError,required TResult Function( ParserError_ChapterExtractError value)  chapterExtractError,required TResult Function( ParserError_Typeset value)  typeset,required TResult Function( ParserError_StreamError value)  streamError,required TResult Function( ParserError_UnsupportedFormat value)  unsupportedFormat,required TResult Function( ParserError_FileWriteError value)  fileWriteError,required TResult Function( ParserError_InternalError value)  internalError,required TResult Function( ParserError_ConfigError value)  configError,required TResult Function( ParserError_PageExtractError value)  pageExtractError,required TResult Function( ParserError_TextExtractError value)  textExtractError,required TResult Function( ParserError_Other value)  other,required TResult Function( ParserError_SecurityError value)  securityError,}){
final _that = this;
switch (_that) {
case ParserError_FileNotFound():
return fileNotFound(_that);case ParserError_FileReadError():
return fileReadError(_that);case ParserError_EncodingError():
return encodingError(_that);case ParserError_EpubParseError():
return epubParseError(_that);case ParserError_PdfParseError():
return pdfParseError(_that);case ParserError_TxtParseError():
return txtParseError(_that);case ParserError_ChapterExtractError():
return chapterExtractError(_that);case ParserError_Typeset():
return typeset(_that);case ParserError_StreamError():
return streamError(_that);case ParserError_UnsupportedFormat():
return unsupportedFormat(_that);case ParserError_FileWriteError():
return fileWriteError(_that);case ParserError_InternalError():
return internalError(_that);case ParserError_ConfigError():
return configError(_that);case ParserError_PageExtractError():
return pageExtractError(_that);case ParserError_TextExtractError():
return textExtractError(_that);case ParserError_Other():
return other(_that);case ParserError_SecurityError():
return securityError(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ParserError_FileNotFound value)?  fileNotFound,TResult? Function( ParserError_FileReadError value)?  fileReadError,TResult? Function( ParserError_EncodingError value)?  encodingError,TResult? Function( ParserError_EpubParseError value)?  epubParseError,TResult? Function( ParserError_PdfParseError value)?  pdfParseError,TResult? Function( ParserError_TxtParseError value)?  txtParseError,TResult? Function( ParserError_ChapterExtractError value)?  chapterExtractError,TResult? Function( ParserError_Typeset value)?  typeset,TResult? Function( ParserError_StreamError value)?  streamError,TResult? Function( ParserError_UnsupportedFormat value)?  unsupportedFormat,TResult? Function( ParserError_FileWriteError value)?  fileWriteError,TResult? Function( ParserError_InternalError value)?  internalError,TResult? Function( ParserError_ConfigError value)?  configError,TResult? Function( ParserError_PageExtractError value)?  pageExtractError,TResult? Function( ParserError_TextExtractError value)?  textExtractError,TResult? Function( ParserError_Other value)?  other,TResult? Function( ParserError_SecurityError value)?  securityError,}){
final _that = this;
switch (_that) {
case ParserError_FileNotFound() when fileNotFound != null:
return fileNotFound(_that);case ParserError_FileReadError() when fileReadError != null:
return fileReadError(_that);case ParserError_EncodingError() when encodingError != null:
return encodingError(_that);case ParserError_EpubParseError() when epubParseError != null:
return epubParseError(_that);case ParserError_PdfParseError() when pdfParseError != null:
return pdfParseError(_that);case ParserError_TxtParseError() when txtParseError != null:
return txtParseError(_that);case ParserError_ChapterExtractError() when chapterExtractError != null:
return chapterExtractError(_that);case ParserError_Typeset() when typeset != null:
return typeset(_that);case ParserError_StreamError() when streamError != null:
return streamError(_that);case ParserError_UnsupportedFormat() when unsupportedFormat != null:
return unsupportedFormat(_that);case ParserError_FileWriteError() when fileWriteError != null:
return fileWriteError(_that);case ParserError_InternalError() when internalError != null:
return internalError(_that);case ParserError_ConfigError() when configError != null:
return configError(_that);case ParserError_PageExtractError() when pageExtractError != null:
return pageExtractError(_that);case ParserError_TextExtractError() when textExtractError != null:
return textExtractError(_that);case ParserError_Other() when other != null:
return other(_that);case ParserError_SecurityError() when securityError != null:
return securityError(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String path,  String reason)?  fileNotFound,TResult Function( String path,  String message)?  fileReadError,TResult Function( String field0)?  encodingError,TResult Function( String field0)?  epubParseError,TResult Function( String field0)?  pdfParseError,TResult Function( String field0)?  txtParseError,TResult Function( String field0)?  chapterExtractError,TResult Function( String field0)?  typeset,TResult Function( String field0)?  streamError,TResult Function( String field0)?  unsupportedFormat,TResult Function( String field0)?  fileWriteError,TResult Function( String field0)?  internalError,TResult Function( String field0)?  configError,TResult Function( String field0)?  pageExtractError,TResult Function( String field0)?  textExtractError,TResult Function( String field0)?  other,TResult Function( String field0)?  securityError,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ParserError_FileNotFound() when fileNotFound != null:
return fileNotFound(_that.path,_that.reason);case ParserError_FileReadError() when fileReadError != null:
return fileReadError(_that.path,_that.message);case ParserError_EncodingError() when encodingError != null:
return encodingError(_that.field0);case ParserError_EpubParseError() when epubParseError != null:
return epubParseError(_that.field0);case ParserError_PdfParseError() when pdfParseError != null:
return pdfParseError(_that.field0);case ParserError_TxtParseError() when txtParseError != null:
return txtParseError(_that.field0);case ParserError_ChapterExtractError() when chapterExtractError != null:
return chapterExtractError(_that.field0);case ParserError_Typeset() when typeset != null:
return typeset(_that.field0);case ParserError_StreamError() when streamError != null:
return streamError(_that.field0);case ParserError_UnsupportedFormat() when unsupportedFormat != null:
return unsupportedFormat(_that.field0);case ParserError_FileWriteError() when fileWriteError != null:
return fileWriteError(_that.field0);case ParserError_InternalError() when internalError != null:
return internalError(_that.field0);case ParserError_ConfigError() when configError != null:
return configError(_that.field0);case ParserError_PageExtractError() when pageExtractError != null:
return pageExtractError(_that.field0);case ParserError_TextExtractError() when textExtractError != null:
return textExtractError(_that.field0);case ParserError_Other() when other != null:
return other(_that.field0);case ParserError_SecurityError() when securityError != null:
return securityError(_that.field0);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String path,  String reason)  fileNotFound,required TResult Function( String path,  String message)  fileReadError,required TResult Function( String field0)  encodingError,required TResult Function( String field0)  epubParseError,required TResult Function( String field0)  pdfParseError,required TResult Function( String field0)  txtParseError,required TResult Function( String field0)  chapterExtractError,required TResult Function( String field0)  typeset,required TResult Function( String field0)  streamError,required TResult Function( String field0)  unsupportedFormat,required TResult Function( String field0)  fileWriteError,required TResult Function( String field0)  internalError,required TResult Function( String field0)  configError,required TResult Function( String field0)  pageExtractError,required TResult Function( String field0)  textExtractError,required TResult Function( String field0)  other,required TResult Function( String field0)  securityError,}) {final _that = this;
switch (_that) {
case ParserError_FileNotFound():
return fileNotFound(_that.path,_that.reason);case ParserError_FileReadError():
return fileReadError(_that.path,_that.message);case ParserError_EncodingError():
return encodingError(_that.field0);case ParserError_EpubParseError():
return epubParseError(_that.field0);case ParserError_PdfParseError():
return pdfParseError(_that.field0);case ParserError_TxtParseError():
return txtParseError(_that.field0);case ParserError_ChapterExtractError():
return chapterExtractError(_that.field0);case ParserError_Typeset():
return typeset(_that.field0);case ParserError_StreamError():
return streamError(_that.field0);case ParserError_UnsupportedFormat():
return unsupportedFormat(_that.field0);case ParserError_FileWriteError():
return fileWriteError(_that.field0);case ParserError_InternalError():
return internalError(_that.field0);case ParserError_ConfigError():
return configError(_that.field0);case ParserError_PageExtractError():
return pageExtractError(_that.field0);case ParserError_TextExtractError():
return textExtractError(_that.field0);case ParserError_Other():
return other(_that.field0);case ParserError_SecurityError():
return securityError(_that.field0);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String path,  String reason)?  fileNotFound,TResult? Function( String path,  String message)?  fileReadError,TResult? Function( String field0)?  encodingError,TResult? Function( String field0)?  epubParseError,TResult? Function( String field0)?  pdfParseError,TResult? Function( String field0)?  txtParseError,TResult? Function( String field0)?  chapterExtractError,TResult? Function( String field0)?  typeset,TResult? Function( String field0)?  streamError,TResult? Function( String field0)?  unsupportedFormat,TResult? Function( String field0)?  fileWriteError,TResult? Function( String field0)?  internalError,TResult? Function( String field0)?  configError,TResult? Function( String field0)?  pageExtractError,TResult? Function( String field0)?  textExtractError,TResult? Function( String field0)?  other,TResult? Function( String field0)?  securityError,}) {final _that = this;
switch (_that) {
case ParserError_FileNotFound() when fileNotFound != null:
return fileNotFound(_that.path,_that.reason);case ParserError_FileReadError() when fileReadError != null:
return fileReadError(_that.path,_that.message);case ParserError_EncodingError() when encodingError != null:
return encodingError(_that.field0);case ParserError_EpubParseError() when epubParseError != null:
return epubParseError(_that.field0);case ParserError_PdfParseError() when pdfParseError != null:
return pdfParseError(_that.field0);case ParserError_TxtParseError() when txtParseError != null:
return txtParseError(_that.field0);case ParserError_ChapterExtractError() when chapterExtractError != null:
return chapterExtractError(_that.field0);case ParserError_Typeset() when typeset != null:
return typeset(_that.field0);case ParserError_StreamError() when streamError != null:
return streamError(_that.field0);case ParserError_UnsupportedFormat() when unsupportedFormat != null:
return unsupportedFormat(_that.field0);case ParserError_FileWriteError() when fileWriteError != null:
return fileWriteError(_that.field0);case ParserError_InternalError() when internalError != null:
return internalError(_that.field0);case ParserError_ConfigError() when configError != null:
return configError(_that.field0);case ParserError_PageExtractError() when pageExtractError != null:
return pageExtractError(_that.field0);case ParserError_TextExtractError() when textExtractError != null:
return textExtractError(_that.field0);case ParserError_Other() when other != null:
return other(_that.field0);case ParserError_SecurityError() when securityError != null:
return securityError(_that.field0);case _:
  return null;

}
}

}

/// @nodoc


class ParserError_FileNotFound extends ParserError {
  const ParserError_FileNotFound({required this.path, required this.reason}): super._();
  

 final  String path;
 final  String reason;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_FileNotFoundCopyWith<ParserError_FileNotFound> get copyWith => _$ParserError_FileNotFoundCopyWithImpl<ParserError_FileNotFound>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_FileNotFound&&(identical(other.path, path) || other.path == path)&&(identical(other.reason, reason) || other.reason == reason));
}


@override
int get hashCode => Object.hash(runtimeType,path,reason);

@override
String toString() {
  return 'ParserError.fileNotFound(path: $path, reason: $reason)';
}


}

/// @nodoc
abstract mixin class $ParserError_FileNotFoundCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_FileNotFoundCopyWith(ParserError_FileNotFound value, $Res Function(ParserError_FileNotFound) _then) = _$ParserError_FileNotFoundCopyWithImpl;
@useResult
$Res call({
 String path, String reason
});




}
/// @nodoc
class _$ParserError_FileNotFoundCopyWithImpl<$Res>
    implements $ParserError_FileNotFoundCopyWith<$Res> {
  _$ParserError_FileNotFoundCopyWithImpl(this._self, this._then);

  final ParserError_FileNotFound _self;
  final $Res Function(ParserError_FileNotFound) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? reason = null,}) {
  return _then(ParserError_FileNotFound(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,reason: null == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_FileReadError extends ParserError {
  const ParserError_FileReadError({required this.path, required this.message}): super._();
  

 final  String path;
 final  String message;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_FileReadErrorCopyWith<ParserError_FileReadError> get copyWith => _$ParserError_FileReadErrorCopyWithImpl<ParserError_FileReadError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_FileReadError&&(identical(other.path, path) || other.path == path)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,path,message);

@override
String toString() {
  return 'ParserError.fileReadError(path: $path, message: $message)';
}


}

/// @nodoc
abstract mixin class $ParserError_FileReadErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_FileReadErrorCopyWith(ParserError_FileReadError value, $Res Function(ParserError_FileReadError) _then) = _$ParserError_FileReadErrorCopyWithImpl;
@useResult
$Res call({
 String path, String message
});




}
/// @nodoc
class _$ParserError_FileReadErrorCopyWithImpl<$Res>
    implements $ParserError_FileReadErrorCopyWith<$Res> {
  _$ParserError_FileReadErrorCopyWithImpl(this._self, this._then);

  final ParserError_FileReadError _self;
  final $Res Function(ParserError_FileReadError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? path = null,Object? message = null,}) {
  return _then(ParserError_FileReadError(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_EncodingError extends ParserError {
  const ParserError_EncodingError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_EncodingErrorCopyWith<ParserError_EncodingError> get copyWith => _$ParserError_EncodingErrorCopyWithImpl<ParserError_EncodingError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_EncodingError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.encodingError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_EncodingErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_EncodingErrorCopyWith(ParserError_EncodingError value, $Res Function(ParserError_EncodingError) _then) = _$ParserError_EncodingErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_EncodingErrorCopyWithImpl<$Res>
    implements $ParserError_EncodingErrorCopyWith<$Res> {
  _$ParserError_EncodingErrorCopyWithImpl(this._self, this._then);

  final ParserError_EncodingError _self;
  final $Res Function(ParserError_EncodingError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_EncodingError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_EpubParseError extends ParserError {
  const ParserError_EpubParseError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_EpubParseErrorCopyWith<ParserError_EpubParseError> get copyWith => _$ParserError_EpubParseErrorCopyWithImpl<ParserError_EpubParseError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_EpubParseError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.epubParseError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_EpubParseErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_EpubParseErrorCopyWith(ParserError_EpubParseError value, $Res Function(ParserError_EpubParseError) _then) = _$ParserError_EpubParseErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_EpubParseErrorCopyWithImpl<$Res>
    implements $ParserError_EpubParseErrorCopyWith<$Res> {
  _$ParserError_EpubParseErrorCopyWithImpl(this._self, this._then);

  final ParserError_EpubParseError _self;
  final $Res Function(ParserError_EpubParseError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_EpubParseError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_PdfParseError extends ParserError {
  const ParserError_PdfParseError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_PdfParseErrorCopyWith<ParserError_PdfParseError> get copyWith => _$ParserError_PdfParseErrorCopyWithImpl<ParserError_PdfParseError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_PdfParseError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.pdfParseError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_PdfParseErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_PdfParseErrorCopyWith(ParserError_PdfParseError value, $Res Function(ParserError_PdfParseError) _then) = _$ParserError_PdfParseErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_PdfParseErrorCopyWithImpl<$Res>
    implements $ParserError_PdfParseErrorCopyWith<$Res> {
  _$ParserError_PdfParseErrorCopyWithImpl(this._self, this._then);

  final ParserError_PdfParseError _self;
  final $Res Function(ParserError_PdfParseError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_PdfParseError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_TxtParseError extends ParserError {
  const ParserError_TxtParseError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_TxtParseErrorCopyWith<ParserError_TxtParseError> get copyWith => _$ParserError_TxtParseErrorCopyWithImpl<ParserError_TxtParseError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_TxtParseError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.txtParseError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_TxtParseErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_TxtParseErrorCopyWith(ParserError_TxtParseError value, $Res Function(ParserError_TxtParseError) _then) = _$ParserError_TxtParseErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_TxtParseErrorCopyWithImpl<$Res>
    implements $ParserError_TxtParseErrorCopyWith<$Res> {
  _$ParserError_TxtParseErrorCopyWithImpl(this._self, this._then);

  final ParserError_TxtParseError _self;
  final $Res Function(ParserError_TxtParseError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_TxtParseError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_ChapterExtractError extends ParserError {
  const ParserError_ChapterExtractError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_ChapterExtractErrorCopyWith<ParserError_ChapterExtractError> get copyWith => _$ParserError_ChapterExtractErrorCopyWithImpl<ParserError_ChapterExtractError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_ChapterExtractError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.chapterExtractError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_ChapterExtractErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_ChapterExtractErrorCopyWith(ParserError_ChapterExtractError value, $Res Function(ParserError_ChapterExtractError) _then) = _$ParserError_ChapterExtractErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_ChapterExtractErrorCopyWithImpl<$Res>
    implements $ParserError_ChapterExtractErrorCopyWith<$Res> {
  _$ParserError_ChapterExtractErrorCopyWithImpl(this._self, this._then);

  final ParserError_ChapterExtractError _self;
  final $Res Function(ParserError_ChapterExtractError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_ChapterExtractError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_Typeset extends ParserError {
  const ParserError_Typeset(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_TypesetCopyWith<ParserError_Typeset> get copyWith => _$ParserError_TypesetCopyWithImpl<ParserError_Typeset>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_Typeset&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.typeset(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_TypesetCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_TypesetCopyWith(ParserError_Typeset value, $Res Function(ParserError_Typeset) _then) = _$ParserError_TypesetCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_TypesetCopyWithImpl<$Res>
    implements $ParserError_TypesetCopyWith<$Res> {
  _$ParserError_TypesetCopyWithImpl(this._self, this._then);

  final ParserError_Typeset _self;
  final $Res Function(ParserError_Typeset) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_Typeset(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_StreamError extends ParserError {
  const ParserError_StreamError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_StreamErrorCopyWith<ParserError_StreamError> get copyWith => _$ParserError_StreamErrorCopyWithImpl<ParserError_StreamError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_StreamError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.streamError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_StreamErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_StreamErrorCopyWith(ParserError_StreamError value, $Res Function(ParserError_StreamError) _then) = _$ParserError_StreamErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_StreamErrorCopyWithImpl<$Res>
    implements $ParserError_StreamErrorCopyWith<$Res> {
  _$ParserError_StreamErrorCopyWithImpl(this._self, this._then);

  final ParserError_StreamError _self;
  final $Res Function(ParserError_StreamError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_StreamError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_UnsupportedFormat extends ParserError {
  const ParserError_UnsupportedFormat(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_UnsupportedFormatCopyWith<ParserError_UnsupportedFormat> get copyWith => _$ParserError_UnsupportedFormatCopyWithImpl<ParserError_UnsupportedFormat>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_UnsupportedFormat&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.unsupportedFormat(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_UnsupportedFormatCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_UnsupportedFormatCopyWith(ParserError_UnsupportedFormat value, $Res Function(ParserError_UnsupportedFormat) _then) = _$ParserError_UnsupportedFormatCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_UnsupportedFormatCopyWithImpl<$Res>
    implements $ParserError_UnsupportedFormatCopyWith<$Res> {
  _$ParserError_UnsupportedFormatCopyWithImpl(this._self, this._then);

  final ParserError_UnsupportedFormat _self;
  final $Res Function(ParserError_UnsupportedFormat) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_UnsupportedFormat(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_FileWriteError extends ParserError {
  const ParserError_FileWriteError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_FileWriteErrorCopyWith<ParserError_FileWriteError> get copyWith => _$ParserError_FileWriteErrorCopyWithImpl<ParserError_FileWriteError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_FileWriteError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.fileWriteError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_FileWriteErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_FileWriteErrorCopyWith(ParserError_FileWriteError value, $Res Function(ParserError_FileWriteError) _then) = _$ParserError_FileWriteErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_FileWriteErrorCopyWithImpl<$Res>
    implements $ParserError_FileWriteErrorCopyWith<$Res> {
  _$ParserError_FileWriteErrorCopyWithImpl(this._self, this._then);

  final ParserError_FileWriteError _self;
  final $Res Function(ParserError_FileWriteError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_FileWriteError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_InternalError extends ParserError {
  const ParserError_InternalError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_InternalErrorCopyWith<ParserError_InternalError> get copyWith => _$ParserError_InternalErrorCopyWithImpl<ParserError_InternalError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_InternalError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.internalError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_InternalErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_InternalErrorCopyWith(ParserError_InternalError value, $Res Function(ParserError_InternalError) _then) = _$ParserError_InternalErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_InternalErrorCopyWithImpl<$Res>
    implements $ParserError_InternalErrorCopyWith<$Res> {
  _$ParserError_InternalErrorCopyWithImpl(this._self, this._then);

  final ParserError_InternalError _self;
  final $Res Function(ParserError_InternalError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_InternalError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_ConfigError extends ParserError {
  const ParserError_ConfigError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_ConfigErrorCopyWith<ParserError_ConfigError> get copyWith => _$ParserError_ConfigErrorCopyWithImpl<ParserError_ConfigError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_ConfigError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.configError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_ConfigErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_ConfigErrorCopyWith(ParserError_ConfigError value, $Res Function(ParserError_ConfigError) _then) = _$ParserError_ConfigErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_ConfigErrorCopyWithImpl<$Res>
    implements $ParserError_ConfigErrorCopyWith<$Res> {
  _$ParserError_ConfigErrorCopyWithImpl(this._self, this._then);

  final ParserError_ConfigError _self;
  final $Res Function(ParserError_ConfigError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_ConfigError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_PageExtractError extends ParserError {
  const ParserError_PageExtractError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_PageExtractErrorCopyWith<ParserError_PageExtractError> get copyWith => _$ParserError_PageExtractErrorCopyWithImpl<ParserError_PageExtractError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_PageExtractError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.pageExtractError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_PageExtractErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_PageExtractErrorCopyWith(ParserError_PageExtractError value, $Res Function(ParserError_PageExtractError) _then) = _$ParserError_PageExtractErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_PageExtractErrorCopyWithImpl<$Res>
    implements $ParserError_PageExtractErrorCopyWith<$Res> {
  _$ParserError_PageExtractErrorCopyWithImpl(this._self, this._then);

  final ParserError_PageExtractError _self;
  final $Res Function(ParserError_PageExtractError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_PageExtractError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_TextExtractError extends ParserError {
  const ParserError_TextExtractError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_TextExtractErrorCopyWith<ParserError_TextExtractError> get copyWith => _$ParserError_TextExtractErrorCopyWithImpl<ParserError_TextExtractError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_TextExtractError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.textExtractError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_TextExtractErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_TextExtractErrorCopyWith(ParserError_TextExtractError value, $Res Function(ParserError_TextExtractError) _then) = _$ParserError_TextExtractErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_TextExtractErrorCopyWithImpl<$Res>
    implements $ParserError_TextExtractErrorCopyWith<$Res> {
  _$ParserError_TextExtractErrorCopyWithImpl(this._self, this._then);

  final ParserError_TextExtractError _self;
  final $Res Function(ParserError_TextExtractError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_TextExtractError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_Other extends ParserError {
  const ParserError_Other(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_OtherCopyWith<ParserError_Other> get copyWith => _$ParserError_OtherCopyWithImpl<ParserError_Other>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_Other&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.other(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_OtherCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_OtherCopyWith(ParserError_Other value, $Res Function(ParserError_Other) _then) = _$ParserError_OtherCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_OtherCopyWithImpl<$Res>
    implements $ParserError_OtherCopyWith<$Res> {
  _$ParserError_OtherCopyWithImpl(this._self, this._then);

  final ParserError_Other _self;
  final $Res Function(ParserError_Other) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_Other(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ParserError_SecurityError extends ParserError {
  const ParserError_SecurityError(this.field0): super._();
  

 final  String field0;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParserError_SecurityErrorCopyWith<ParserError_SecurityError> get copyWith => _$ParserError_SecurityErrorCopyWithImpl<ParserError_SecurityError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParserError_SecurityError&&(identical(other.field0, field0) || other.field0 == field0));
}


@override
int get hashCode => Object.hash(runtimeType,field0);

@override
String toString() {
  return 'ParserError.securityError(field0: $field0)';
}


}

/// @nodoc
abstract mixin class $ParserError_SecurityErrorCopyWith<$Res> implements $ParserErrorCopyWith<$Res> {
  factory $ParserError_SecurityErrorCopyWith(ParserError_SecurityError value, $Res Function(ParserError_SecurityError) _then) = _$ParserError_SecurityErrorCopyWithImpl;
@useResult
$Res call({
 String field0
});




}
/// @nodoc
class _$ParserError_SecurityErrorCopyWithImpl<$Res>
    implements $ParserError_SecurityErrorCopyWith<$Res> {
  _$ParserError_SecurityErrorCopyWithImpl(this._self, this._then);

  final ParserError_SecurityError _self;
  final $Res Function(ParserError_SecurityError) _then;

/// Create a copy of ParserError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? field0 = null,}) {
  return _then(ParserError_SecurityError(
null == field0 ? _self.field0 : field0 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
