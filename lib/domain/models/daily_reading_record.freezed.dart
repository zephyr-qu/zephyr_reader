// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_reading_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DailyReadingRecord implements DiagnosticableTreeMixin {

/// 日期（YYYY-MM-DD 格式）
 String get date;/// 阅读时长（秒）
 int get readingTimeSeconds;/// 阅读字数
 int get charactersRead;/// 阅读章节数
 int get chaptersRead;/// 阅读页数
 int get pagesRead;
/// Create a copy of DailyReadingRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyReadingRecordCopyWith<DailyReadingRecord> get copyWith => _$DailyReadingRecordCopyWithImpl<DailyReadingRecord>(this as DailyReadingRecord, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'DailyReadingRecord'))
    ..add(DiagnosticsProperty('date', date))..add(DiagnosticsProperty('readingTimeSeconds', readingTimeSeconds))..add(DiagnosticsProperty('charactersRead', charactersRead))..add(DiagnosticsProperty('chaptersRead', chaptersRead))..add(DiagnosticsProperty('pagesRead', pagesRead));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyReadingRecord&&(identical(other.date, date) || other.date == date)&&(identical(other.readingTimeSeconds, readingTimeSeconds) || other.readingTimeSeconds == readingTimeSeconds)&&(identical(other.charactersRead, charactersRead) || other.charactersRead == charactersRead)&&(identical(other.chaptersRead, chaptersRead) || other.chaptersRead == chaptersRead)&&(identical(other.pagesRead, pagesRead) || other.pagesRead == pagesRead));
}


@override
int get hashCode => Object.hash(runtimeType,date,readingTimeSeconds,charactersRead,chaptersRead,pagesRead);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'DailyReadingRecord(date: $date, readingTimeSeconds: $readingTimeSeconds, charactersRead: $charactersRead, chaptersRead: $chaptersRead, pagesRead: $pagesRead)';
}


}

/// @nodoc
abstract mixin class $DailyReadingRecordCopyWith<$Res>  {
  factory $DailyReadingRecordCopyWith(DailyReadingRecord value, $Res Function(DailyReadingRecord) _then) = _$DailyReadingRecordCopyWithImpl;
@useResult
$Res call({
 String date, int readingTimeSeconds, int charactersRead, int chaptersRead, int pagesRead
});




}
/// @nodoc
class _$DailyReadingRecordCopyWithImpl<$Res>
    implements $DailyReadingRecordCopyWith<$Res> {
  _$DailyReadingRecordCopyWithImpl(this._self, this._then);

  final DailyReadingRecord _self;
  final $Res Function(DailyReadingRecord) _then;

/// Create a copy of DailyReadingRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? readingTimeSeconds = null,Object? charactersRead = null,Object? chaptersRead = null,Object? pagesRead = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,readingTimeSeconds: null == readingTimeSeconds ? _self.readingTimeSeconds : readingTimeSeconds // ignore: cast_nullable_to_non_nullable
as int,charactersRead: null == charactersRead ? _self.charactersRead : charactersRead // ignore: cast_nullable_to_non_nullable
as int,chaptersRead: null == chaptersRead ? _self.chaptersRead : chaptersRead // ignore: cast_nullable_to_non_nullable
as int,pagesRead: null == pagesRead ? _self.pagesRead : pagesRead // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyReadingRecord].
extension DailyReadingRecordPatterns on DailyReadingRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyReadingRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyReadingRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyReadingRecord value)  $default,){
final _that = this;
switch (_that) {
case _DailyReadingRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyReadingRecord value)?  $default,){
final _that = this;
switch (_that) {
case _DailyReadingRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  int readingTimeSeconds,  int charactersRead,  int chaptersRead,  int pagesRead)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyReadingRecord() when $default != null:
return $default(_that.date,_that.readingTimeSeconds,_that.charactersRead,_that.chaptersRead,_that.pagesRead);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  int readingTimeSeconds,  int charactersRead,  int chaptersRead,  int pagesRead)  $default,) {final _that = this;
switch (_that) {
case _DailyReadingRecord():
return $default(_that.date,_that.readingTimeSeconds,_that.charactersRead,_that.chaptersRead,_that.pagesRead);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  int readingTimeSeconds,  int charactersRead,  int chaptersRead,  int pagesRead)?  $default,) {final _that = this;
switch (_that) {
case _DailyReadingRecord() when $default != null:
return $default(_that.date,_that.readingTimeSeconds,_that.charactersRead,_that.chaptersRead,_that.pagesRead);case _:
  return null;

}
}

}

/// @nodoc


class _DailyReadingRecord with DiagnosticableTreeMixin implements DailyReadingRecord {
  const _DailyReadingRecord({required this.date, this.readingTimeSeconds = 0, this.charactersRead = 0, this.chaptersRead = 0, this.pagesRead = 0});
  

/// 日期（YYYY-MM-DD 格式）
@override final  String date;
/// 阅读时长（秒）
@override@JsonKey() final  int readingTimeSeconds;
/// 阅读字数
@override@JsonKey() final  int charactersRead;
/// 阅读章节数
@override@JsonKey() final  int chaptersRead;
/// 阅读页数
@override@JsonKey() final  int pagesRead;

/// Create a copy of DailyReadingRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyReadingRecordCopyWith<_DailyReadingRecord> get copyWith => __$DailyReadingRecordCopyWithImpl<_DailyReadingRecord>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'DailyReadingRecord'))
    ..add(DiagnosticsProperty('date', date))..add(DiagnosticsProperty('readingTimeSeconds', readingTimeSeconds))..add(DiagnosticsProperty('charactersRead', charactersRead))..add(DiagnosticsProperty('chaptersRead', chaptersRead))..add(DiagnosticsProperty('pagesRead', pagesRead));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyReadingRecord&&(identical(other.date, date) || other.date == date)&&(identical(other.readingTimeSeconds, readingTimeSeconds) || other.readingTimeSeconds == readingTimeSeconds)&&(identical(other.charactersRead, charactersRead) || other.charactersRead == charactersRead)&&(identical(other.chaptersRead, chaptersRead) || other.chaptersRead == chaptersRead)&&(identical(other.pagesRead, pagesRead) || other.pagesRead == pagesRead));
}


@override
int get hashCode => Object.hash(runtimeType,date,readingTimeSeconds,charactersRead,chaptersRead,pagesRead);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'DailyReadingRecord(date: $date, readingTimeSeconds: $readingTimeSeconds, charactersRead: $charactersRead, chaptersRead: $chaptersRead, pagesRead: $pagesRead)';
}


}

/// @nodoc
abstract mixin class _$DailyReadingRecordCopyWith<$Res> implements $DailyReadingRecordCopyWith<$Res> {
  factory _$DailyReadingRecordCopyWith(_DailyReadingRecord value, $Res Function(_DailyReadingRecord) _then) = __$DailyReadingRecordCopyWithImpl;
@override @useResult
$Res call({
 String date, int readingTimeSeconds, int charactersRead, int chaptersRead, int pagesRead
});




}
/// @nodoc
class __$DailyReadingRecordCopyWithImpl<$Res>
    implements _$DailyReadingRecordCopyWith<$Res> {
  __$DailyReadingRecordCopyWithImpl(this._self, this._then);

  final _DailyReadingRecord _self;
  final $Res Function(_DailyReadingRecord) _then;

/// Create a copy of DailyReadingRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? readingTimeSeconds = null,Object? charactersRead = null,Object? chaptersRead = null,Object? pagesRead = null,}) {
  return _then(_DailyReadingRecord(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,readingTimeSeconds: null == readingTimeSeconds ? _self.readingTimeSeconds : readingTimeSeconds // ignore: cast_nullable_to_non_nullable
as int,charactersRead: null == charactersRead ? _self.charactersRead : charactersRead // ignore: cast_nullable_to_non_nullable
as int,chaptersRead: null == chaptersRead ? _self.chaptersRead : chaptersRead // ignore: cast_nullable_to_non_nullable
as int,pagesRead: null == pagesRead ? _self.pagesRead : pagesRead // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
