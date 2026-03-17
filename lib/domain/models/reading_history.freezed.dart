// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_history.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingHistory implements DiagnosticableTreeMixin {

/// 自增主键
 int get id;/// 书籍 ID
 int get bookId;/// 章节 ID
 int get chapterId;/// 阅读位置（字符偏移量）
 int get position;/// 阅读时间
 DateTime get readTime;/// 阅读时长（秒）
 int get duration;
/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingHistoryCopyWith<ReadingHistory> get copyWith => _$ReadingHistoryCopyWithImpl<ReadingHistory>(this as ReadingHistory, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingHistory'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('position', position))..add(DiagnosticsProperty('readTime', readTime))..add(DiagnosticsProperty('duration', duration));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingHistory&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.position, position) || other.position == position)&&(identical(other.readTime, readTime) || other.readTime == readTime)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,position,readTime,duration);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingHistory(id: $id, bookId: $bookId, chapterId: $chapterId, position: $position, readTime: $readTime, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $ReadingHistoryCopyWith<$Res>  {
  factory $ReadingHistoryCopyWith(ReadingHistory value, $Res Function(ReadingHistory) _then) = _$ReadingHistoryCopyWithImpl;
@useResult
$Res call({
 int id, int bookId, int chapterId, int position, DateTime readTime, int duration
});




}
/// @nodoc
class _$ReadingHistoryCopyWithImpl<$Res>
    implements $ReadingHistoryCopyWith<$Res> {
  _$ReadingHistoryCopyWithImpl(this._self, this._then);

  final ReadingHistory _self;
  final $Res Function(ReadingHistory) _then;

/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? position = null,Object? readTime = null,Object? duration = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,readTime: null == readTime ? _self.readTime : readTime // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingHistory].
extension ReadingHistoryPatterns on ReadingHistory {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingHistory value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingHistory value)  $default,){
final _that = this;
switch (_that) {
case _ReadingHistory():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingHistory value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int bookId,  int chapterId,  int position,  DateTime readTime,  int duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.position,_that.readTime,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int bookId,  int chapterId,  int position,  DateTime readTime,  int duration)  $default,) {final _that = this;
switch (_that) {
case _ReadingHistory():
return $default(_that.id,_that.bookId,_that.chapterId,_that.position,_that.readTime,_that.duration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int bookId,  int chapterId,  int position,  DateTime readTime,  int duration)?  $default,) {final _that = this;
switch (_that) {
case _ReadingHistory() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.position,_that.readTime,_that.duration);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingHistory with DiagnosticableTreeMixin implements ReadingHistory {
  const _ReadingHistory({required this.id, required this.bookId, required this.chapterId, required this.position, required this.readTime, this.duration = 0});
  

/// 自增主键
@override final  int id;
/// 书籍 ID
@override final  int bookId;
/// 章节 ID
@override final  int chapterId;
/// 阅读位置（字符偏移量）
@override final  int position;
/// 阅读时间
@override final  DateTime readTime;
/// 阅读时长（秒）
@override@JsonKey() final  int duration;

/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingHistoryCopyWith<_ReadingHistory> get copyWith => __$ReadingHistoryCopyWithImpl<_ReadingHistory>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingHistory'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('position', position))..add(DiagnosticsProperty('readTime', readTime))..add(DiagnosticsProperty('duration', duration));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingHistory&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.position, position) || other.position == position)&&(identical(other.readTime, readTime) || other.readTime == readTime)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,position,readTime,duration);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingHistory(id: $id, bookId: $bookId, chapterId: $chapterId, position: $position, readTime: $readTime, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$ReadingHistoryCopyWith<$Res> implements $ReadingHistoryCopyWith<$Res> {
  factory _$ReadingHistoryCopyWith(_ReadingHistory value, $Res Function(_ReadingHistory) _then) = __$ReadingHistoryCopyWithImpl;
@override @useResult
$Res call({
 int id, int bookId, int chapterId, int position, DateTime readTime, int duration
});




}
/// @nodoc
class __$ReadingHistoryCopyWithImpl<$Res>
    implements _$ReadingHistoryCopyWith<$Res> {
  __$ReadingHistoryCopyWithImpl(this._self, this._then);

  final _ReadingHistory _self;
  final $Res Function(_ReadingHistory) _then;

/// Create a copy of ReadingHistory
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? position = null,Object? readTime = null,Object? duration = null,}) {
  return _then(_ReadingHistory(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,readTime: null == readTime ? _self.readTime : readTime // ignore: cast_nullable_to_non_nullable
as DateTime,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
