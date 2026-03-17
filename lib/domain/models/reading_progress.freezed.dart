// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingProgress implements DiagnosticableTreeMixin {

/// 书籍 ID
 int get bookId;/// 当前章节 ID
 int get chapterId;/// 当前页码
 int get pageIndex;/// 总页数
 int get totalPages;/// 进度百分比（0.0 - 1.0）
 double get progress;/// 已阅读时间（秒）
 int get readingTimeSeconds;/// 最后阅读时间戳（Unix 时间戳，秒）
 int get lastReadTimestamp;
/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingProgressCopyWith<ReadingProgress> get copyWith => _$ReadingProgressCopyWithImpl<ReadingProgress>(this as ReadingProgress, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingProgress'))
    ..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('pageIndex', pageIndex))..add(DiagnosticsProperty('totalPages', totalPages))..add(DiagnosticsProperty('progress', progress))..add(DiagnosticsProperty('readingTimeSeconds', readingTimeSeconds))..add(DiagnosticsProperty('lastReadTimestamp', lastReadTimestamp));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingProgress&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.readingTimeSeconds, readingTimeSeconds) || other.readingTimeSeconds == readingTimeSeconds)&&(identical(other.lastReadTimestamp, lastReadTimestamp) || other.lastReadTimestamp == lastReadTimestamp));
}


@override
int get hashCode => Object.hash(runtimeType,bookId,chapterId,pageIndex,totalPages,progress,readingTimeSeconds,lastReadTimestamp);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingProgress(bookId: $bookId, chapterId: $chapterId, pageIndex: $pageIndex, totalPages: $totalPages, progress: $progress, readingTimeSeconds: $readingTimeSeconds, lastReadTimestamp: $lastReadTimestamp)';
}


}

/// @nodoc
abstract mixin class $ReadingProgressCopyWith<$Res>  {
  factory $ReadingProgressCopyWith(ReadingProgress value, $Res Function(ReadingProgress) _then) = _$ReadingProgressCopyWithImpl;
@useResult
$Res call({
 int bookId, int chapterId, int pageIndex, int totalPages, double progress, int readingTimeSeconds, int lastReadTimestamp
});




}
/// @nodoc
class _$ReadingProgressCopyWithImpl<$Res>
    implements $ReadingProgressCopyWith<$Res> {
  _$ReadingProgressCopyWithImpl(this._self, this._then);

  final ReadingProgress _self;
  final $Res Function(ReadingProgress) _then;

/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookId = null,Object? chapterId = null,Object? pageIndex = null,Object? totalPages = null,Object? progress = null,Object? readingTimeSeconds = null,Object? lastReadTimestamp = null,}) {
  return _then(_self.copyWith(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,pageIndex: null == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,readingTimeSeconds: null == readingTimeSeconds ? _self.readingTimeSeconds : readingTimeSeconds // ignore: cast_nullable_to_non_nullable
as int,lastReadTimestamp: null == lastReadTimestamp ? _self.lastReadTimestamp : lastReadTimestamp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingProgress].
extension ReadingProgressPatterns on ReadingProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingProgress value)  $default,){
final _that = this;
switch (_that) {
case _ReadingProgress():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingProgress value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int bookId,  int chapterId,  int pageIndex,  int totalPages,  double progress,  int readingTimeSeconds,  int lastReadTimestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
return $default(_that.bookId,_that.chapterId,_that.pageIndex,_that.totalPages,_that.progress,_that.readingTimeSeconds,_that.lastReadTimestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int bookId,  int chapterId,  int pageIndex,  int totalPages,  double progress,  int readingTimeSeconds,  int lastReadTimestamp)  $default,) {final _that = this;
switch (_that) {
case _ReadingProgress():
return $default(_that.bookId,_that.chapterId,_that.pageIndex,_that.totalPages,_that.progress,_that.readingTimeSeconds,_that.lastReadTimestamp);case _:
  throw StateError('Unexpected subclass');

}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int bookId,  int chapterId,  int pageIndex,  int totalPages,  double progress,  int readingTimeSeconds,  int lastReadTimestamp)?  $default,) {final _that = this;
switch (_that) {
case _ReadingProgress() when $default != null:
return $default(_that.bookId,_that.chapterId,_that.pageIndex,_that.totalPages,_that.progress,_that.readingTimeSeconds,_that.lastReadTimestamp);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingProgress with DiagnosticableTreeMixin implements ReadingProgress {
  const _ReadingProgress({required this.bookId, required this.chapterId, required this.pageIndex, required this.totalPages, this.progress = 0.0, this.readingTimeSeconds = 0, required this.lastReadTimestamp});
  

/// 书籍 ID
@override final  int bookId;
/// 当前章节 ID
@override final  int chapterId;
/// 当前页码
@override final  int pageIndex;
/// 总页数
@override final  int totalPages;
/// 进度百分比（0.0 - 1.0）
@override@JsonKey() final  double progress;
/// 已阅读时间（秒）
@override@JsonKey() final  int readingTimeSeconds;
/// 最后阅读时间戳（Unix 时间戳，秒）
@override final  int lastReadTimestamp;

/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingProgressCopyWith<_ReadingProgress> get copyWith => __$ReadingProgressCopyWithImpl<_ReadingProgress>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingProgress'))
    ..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('pageIndex', pageIndex))..add(DiagnosticsProperty('totalPages', totalPages))..add(DiagnosticsProperty('progress', progress))..add(DiagnosticsProperty('readingTimeSeconds', readingTimeSeconds))..add(DiagnosticsProperty('lastReadTimestamp', lastReadTimestamp));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingProgress&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.readingTimeSeconds, readingTimeSeconds) || other.readingTimeSeconds == readingTimeSeconds)&&(identical(other.lastReadTimestamp, lastReadTimestamp) || other.lastReadTimestamp == lastReadTimestamp));
}


@override
int get hashCode => Object.hash(runtimeType,bookId,chapterId,pageIndex,totalPages,progress,readingTimeSeconds,lastReadTimestamp);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingProgress(bookId: $bookId, chapterId: $chapterId, pageIndex: $pageIndex, totalPages: $totalPages, progress: $progress, readingTimeSeconds: $readingTimeSeconds, lastReadTimestamp: $lastReadTimestamp)';
}


}

/// @nodoc
abstract mixin class _$ReadingProgressCopyWith<$Res> implements $ReadingProgressCopyWith<$Res> {
  factory _$ReadingProgressCopyWith(_ReadingProgress value, $Res Function(_ReadingProgress) _then) = __$ReadingProgressCopyWithImpl;
@override @useResult
$Res call({
 int bookId, int chapterId, int pageIndex, int totalPages, double progress, int readingTimeSeconds, int lastReadTimestamp
});




}
/// @nodoc
class __$ReadingProgressCopyWithImpl<$Res>
    implements _$ReadingProgressCopyWith<$Res> {
  __$ReadingProgressCopyWithImpl(this._self, this._then);

  final _ReadingProgress _self;
  final $Res Function(_ReadingProgress) _then;

/// Create a copy of ReadingProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookId = null,Object? chapterId = null,Object? pageIndex = null,Object? totalPages = null,Object? progress = null,Object? readingTimeSeconds = null,Object? lastReadTimestamp = null,}) {
  return _then(_ReadingProgress(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,pageIndex: null == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,readingTimeSeconds: null == readingTimeSeconds ? _self.readingTimeSeconds : readingTimeSeconds // ignore: cast_nullable_to_non_nullable
as int,lastReadTimestamp: null == lastReadTimestamp ? _self.lastReadTimestamp : lastReadTimestamp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
