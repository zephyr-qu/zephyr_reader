// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingStats implements DiagnosticableTreeMixin {

/// 固定 ID = 1
 int get id;/// 总阅读时长（秒）
 int get totalReadingTimeSeconds;/// 总阅读字数
 int get totalCharactersRead;/// 阅读书籍数量
 int get booksReadCount;/// 完成阅读书籍数量
 int get booksCompletedCount;/// 最后阅读日期（YYYY-MM-DD 格式）
 String? get lastReadDate;/// 连续阅读天数
 int get consecutiveReadingDays;
/// Create a copy of ReadingStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingStatsCopyWith<ReadingStats> get copyWith => _$ReadingStatsCopyWithImpl<ReadingStats>(this as ReadingStats, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingStats'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('totalReadingTimeSeconds', totalReadingTimeSeconds))..add(DiagnosticsProperty('totalCharactersRead', totalCharactersRead))..add(DiagnosticsProperty('booksReadCount', booksReadCount))..add(DiagnosticsProperty('booksCompletedCount', booksCompletedCount))..add(DiagnosticsProperty('lastReadDate', lastReadDate))..add(DiagnosticsProperty('consecutiveReadingDays', consecutiveReadingDays));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingStats&&(identical(other.id, id) || other.id == id)&&(identical(other.totalReadingTimeSeconds, totalReadingTimeSeconds) || other.totalReadingTimeSeconds == totalReadingTimeSeconds)&&(identical(other.totalCharactersRead, totalCharactersRead) || other.totalCharactersRead == totalCharactersRead)&&(identical(other.booksReadCount, booksReadCount) || other.booksReadCount == booksReadCount)&&(identical(other.booksCompletedCount, booksCompletedCount) || other.booksCompletedCount == booksCompletedCount)&&(identical(other.lastReadDate, lastReadDate) || other.lastReadDate == lastReadDate)&&(identical(other.consecutiveReadingDays, consecutiveReadingDays) || other.consecutiveReadingDays == consecutiveReadingDays));
}


@override
int get hashCode => Object.hash(runtimeType,id,totalReadingTimeSeconds,totalCharactersRead,booksReadCount,booksCompletedCount,lastReadDate,consecutiveReadingDays);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingStats(id: $id, totalReadingTimeSeconds: $totalReadingTimeSeconds, totalCharactersRead: $totalCharactersRead, booksReadCount: $booksReadCount, booksCompletedCount: $booksCompletedCount, lastReadDate: $lastReadDate, consecutiveReadingDays: $consecutiveReadingDays)';
}


}

/// @nodoc
abstract mixin class $ReadingStatsCopyWith<$Res>  {
  factory $ReadingStatsCopyWith(ReadingStats value, $Res Function(ReadingStats) _then) = _$ReadingStatsCopyWithImpl;
@useResult
$Res call({
 int id, int totalReadingTimeSeconds, int totalCharactersRead, int booksReadCount, int booksCompletedCount, String? lastReadDate, int consecutiveReadingDays
});




}
/// @nodoc
class _$ReadingStatsCopyWithImpl<$Res>
    implements $ReadingStatsCopyWith<$Res> {
  _$ReadingStatsCopyWithImpl(this._self, this._then);

  final ReadingStats _self;
  final $Res Function(ReadingStats) _then;

/// Create a copy of ReadingStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? totalReadingTimeSeconds = null,Object? totalCharactersRead = null,Object? booksReadCount = null,Object? booksCompletedCount = null,Object? lastReadDate = freezed,Object? consecutiveReadingDays = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,totalReadingTimeSeconds: null == totalReadingTimeSeconds ? _self.totalReadingTimeSeconds : totalReadingTimeSeconds // ignore: cast_nullable_to_non_nullable
as int,totalCharactersRead: null == totalCharactersRead ? _self.totalCharactersRead : totalCharactersRead // ignore: cast_nullable_to_non_nullable
as int,booksReadCount: null == booksReadCount ? _self.booksReadCount : booksReadCount // ignore: cast_nullable_to_non_nullable
as int,booksCompletedCount: null == booksCompletedCount ? _self.booksCompletedCount : booksCompletedCount // ignore: cast_nullable_to_non_nullable
as int,lastReadDate: freezed == lastReadDate ? _self.lastReadDate : lastReadDate // ignore: cast_nullable_to_non_nullable
as String?,consecutiveReadingDays: null == consecutiveReadingDays ? _self.consecutiveReadingDays : consecutiveReadingDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingStats].
extension ReadingStatsPatterns on ReadingStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingStats value)  $default,){
final _that = this;
switch (_that) {
case _ReadingStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingStats value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int totalReadingTimeSeconds,  int totalCharactersRead,  int booksReadCount,  int booksCompletedCount,  String? lastReadDate,  int consecutiveReadingDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingStats() when $default != null:
return $default(_that.id,_that.totalReadingTimeSeconds,_that.totalCharactersRead,_that.booksReadCount,_that.booksCompletedCount,_that.lastReadDate,_that.consecutiveReadingDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int totalReadingTimeSeconds,  int totalCharactersRead,  int booksReadCount,  int booksCompletedCount,  String? lastReadDate,  int consecutiveReadingDays)  $default,) {final _that = this;
switch (_that) {
case _ReadingStats():
return $default(_that.id,_that.totalReadingTimeSeconds,_that.totalCharactersRead,_that.booksReadCount,_that.booksCompletedCount,_that.lastReadDate,_that.consecutiveReadingDays);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int totalReadingTimeSeconds,  int totalCharactersRead,  int booksReadCount,  int booksCompletedCount,  String? lastReadDate,  int consecutiveReadingDays)?  $default,) {final _that = this;
switch (_that) {
case _ReadingStats() when $default != null:
return $default(_that.id,_that.totalReadingTimeSeconds,_that.totalCharactersRead,_that.booksReadCount,_that.booksCompletedCount,_that.lastReadDate,_that.consecutiveReadingDays);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingStats with DiagnosticableTreeMixin implements ReadingStats {
  const _ReadingStats({this.id = 1, this.totalReadingTimeSeconds = 0, this.totalCharactersRead = 0, this.booksReadCount = 0, this.booksCompletedCount = 0, this.lastReadDate, this.consecutiveReadingDays = 0});
  

/// 固定 ID = 1
@override@JsonKey() final  int id;
/// 总阅读时长（秒）
@override@JsonKey() final  int totalReadingTimeSeconds;
/// 总阅读字数
@override@JsonKey() final  int totalCharactersRead;
/// 阅读书籍数量
@override@JsonKey() final  int booksReadCount;
/// 完成阅读书籍数量
@override@JsonKey() final  int booksCompletedCount;
/// 最后阅读日期（YYYY-MM-DD 格式）
@override final  String? lastReadDate;
/// 连续阅读天数
@override@JsonKey() final  int consecutiveReadingDays;

/// Create a copy of ReadingStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingStatsCopyWith<_ReadingStats> get copyWith => __$ReadingStatsCopyWithImpl<_ReadingStats>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingStats'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('totalReadingTimeSeconds', totalReadingTimeSeconds))..add(DiagnosticsProperty('totalCharactersRead', totalCharactersRead))..add(DiagnosticsProperty('booksReadCount', booksReadCount))..add(DiagnosticsProperty('booksCompletedCount', booksCompletedCount))..add(DiagnosticsProperty('lastReadDate', lastReadDate))..add(DiagnosticsProperty('consecutiveReadingDays', consecutiveReadingDays));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingStats&&(identical(other.id, id) || other.id == id)&&(identical(other.totalReadingTimeSeconds, totalReadingTimeSeconds) || other.totalReadingTimeSeconds == totalReadingTimeSeconds)&&(identical(other.totalCharactersRead, totalCharactersRead) || other.totalCharactersRead == totalCharactersRead)&&(identical(other.booksReadCount, booksReadCount) || other.booksReadCount == booksReadCount)&&(identical(other.booksCompletedCount, booksCompletedCount) || other.booksCompletedCount == booksCompletedCount)&&(identical(other.lastReadDate, lastReadDate) || other.lastReadDate == lastReadDate)&&(identical(other.consecutiveReadingDays, consecutiveReadingDays) || other.consecutiveReadingDays == consecutiveReadingDays));
}


@override
int get hashCode => Object.hash(runtimeType,id,totalReadingTimeSeconds,totalCharactersRead,booksReadCount,booksCompletedCount,lastReadDate,consecutiveReadingDays);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingStats(id: $id, totalReadingTimeSeconds: $totalReadingTimeSeconds, totalCharactersRead: $totalCharactersRead, booksReadCount: $booksReadCount, booksCompletedCount: $booksCompletedCount, lastReadDate: $lastReadDate, consecutiveReadingDays: $consecutiveReadingDays)';
}


}

/// @nodoc
abstract mixin class _$ReadingStatsCopyWith<$Res> implements $ReadingStatsCopyWith<$Res> {
  factory _$ReadingStatsCopyWith(_ReadingStats value, $Res Function(_ReadingStats) _then) = __$ReadingStatsCopyWithImpl;
@override @useResult
$Res call({
 int id, int totalReadingTimeSeconds, int totalCharactersRead, int booksReadCount, int booksCompletedCount, String? lastReadDate, int consecutiveReadingDays
});




}
/// @nodoc
class __$ReadingStatsCopyWithImpl<$Res>
    implements _$ReadingStatsCopyWith<$Res> {
  __$ReadingStatsCopyWithImpl(this._self, this._then);

  final _ReadingStats _self;
  final $Res Function(_ReadingStats) _then;

/// Create a copy of ReadingStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? totalReadingTimeSeconds = null,Object? totalCharactersRead = null,Object? booksReadCount = null,Object? booksCompletedCount = null,Object? lastReadDate = freezed,Object? consecutiveReadingDays = null,}) {
  return _then(_ReadingStats(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,totalReadingTimeSeconds: null == totalReadingTimeSeconds ? _self.totalReadingTimeSeconds : totalReadingTimeSeconds // ignore: cast_nullable_to_non_nullable
as int,totalCharactersRead: null == totalCharactersRead ? _self.totalCharactersRead : totalCharactersRead // ignore: cast_nullable_to_non_nullable
as int,booksReadCount: null == booksReadCount ? _self.booksReadCount : booksReadCount // ignore: cast_nullable_to_non_nullable
as int,booksCompletedCount: null == booksCompletedCount ? _self.booksCompletedCount : booksCompletedCount // ignore: cast_nullable_to_non_nullable
as int,lastReadDate: freezed == lastReadDate ? _self.lastReadDate : lastReadDate // ignore: cast_nullable_to_non_nullable
as String?,consecutiveReadingDays: null == consecutiveReadingDays ? _self.consecutiveReadingDays : consecutiveReadingDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
