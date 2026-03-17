// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReadingSession implements DiagnosticableTreeMixin {

/// 会话 ID（UUID）
 int get id;/// 书籍 ID
 int get bookId;/// 章节 ID
 int get chapterId;/// 开始时间戳（Unix 时间戳，秒）
 int get startTimestamp;/// 结束时间戳（Unix 时间戳，秒）
 int get endTimestamp;/// 阅读时长（秒）
 int get durationSeconds;/// 阅读字数
 int get charactersRead;
/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingSessionCopyWith<ReadingSession> get copyWith => _$ReadingSessionCopyWithImpl<ReadingSession>(this as ReadingSession, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingSession'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('startTimestamp', startTimestamp))..add(DiagnosticsProperty('endTimestamp', endTimestamp))..add(DiagnosticsProperty('durationSeconds', durationSeconds))..add(DiagnosticsProperty('charactersRead', charactersRead));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingSession&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.startTimestamp, startTimestamp) || other.startTimestamp == startTimestamp)&&(identical(other.endTimestamp, endTimestamp) || other.endTimestamp == endTimestamp)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.charactersRead, charactersRead) || other.charactersRead == charactersRead));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,startTimestamp,endTimestamp,durationSeconds,charactersRead);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingSession(id: $id, bookId: $bookId, chapterId: $chapterId, startTimestamp: $startTimestamp, endTimestamp: $endTimestamp, durationSeconds: $durationSeconds, charactersRead: $charactersRead)';
}


}

/// @nodoc
abstract mixin class $ReadingSessionCopyWith<$Res>  {
  factory $ReadingSessionCopyWith(ReadingSession value, $Res Function(ReadingSession) _then) = _$ReadingSessionCopyWithImpl;
@useResult
$Res call({
 int id, int bookId, int chapterId, int startTimestamp, int endTimestamp, int durationSeconds, int charactersRead
});




}
/// @nodoc
class _$ReadingSessionCopyWithImpl<$Res>
    implements $ReadingSessionCopyWith<$Res> {
  _$ReadingSessionCopyWithImpl(this._self, this._then);

  final ReadingSession _self;
  final $Res Function(ReadingSession) _then;

/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? startTimestamp = null,Object? endTimestamp = null,Object? durationSeconds = null,Object? charactersRead = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,startTimestamp: null == startTimestamp ? _self.startTimestamp : startTimestamp // ignore: cast_nullable_to_non_nullable
as int,endTimestamp: null == endTimestamp ? _self.endTimestamp : endTimestamp // ignore: cast_nullable_to_non_nullable
as int,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,charactersRead: null == charactersRead ? _self.charactersRead : charactersRead // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingSession].
extension ReadingSessionPatterns on ReadingSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingSession value)  $default,){
final _that = this;
switch (_that) {
case _ReadingSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingSession value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int bookId,  int chapterId,  int startTimestamp,  int endTimestamp,  int durationSeconds,  int charactersRead)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.startTimestamp,_that.endTimestamp,_that.durationSeconds,_that.charactersRead);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int bookId,  int chapterId,  int startTimestamp,  int endTimestamp,  int durationSeconds,  int charactersRead)  $default,) {final _that = this;
switch (_that) {
case _ReadingSession():
return $default(_that.id,_that.bookId,_that.chapterId,_that.startTimestamp,_that.endTimestamp,_that.durationSeconds,_that.charactersRead);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int bookId,  int chapterId,  int startTimestamp,  int endTimestamp,  int durationSeconds,  int charactersRead)?  $default,) {final _that = this;
switch (_that) {
case _ReadingSession() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.startTimestamp,_that.endTimestamp,_that.durationSeconds,_that.charactersRead);case _:
  return null;

}
}

}

/// @nodoc


class _ReadingSession with DiagnosticableTreeMixin implements ReadingSession {
  const _ReadingSession({required this.id, required this.bookId, required this.chapterId, required this.startTimestamp, required this.endTimestamp, required this.durationSeconds, this.charactersRead = 0});
  

/// 会话 ID（UUID）
@override final  int id;
/// 书籍 ID
@override final  int bookId;
/// 章节 ID
@override final  int chapterId;
/// 开始时间戳（Unix 时间戳，秒）
@override final  int startTimestamp;
/// 结束时间戳（Unix 时间戳，秒）
@override final  int endTimestamp;
/// 阅读时长（秒）
@override final  int durationSeconds;
/// 阅读字数
@override@JsonKey() final  int charactersRead;

/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingSessionCopyWith<_ReadingSession> get copyWith => __$ReadingSessionCopyWithImpl<_ReadingSession>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'ReadingSession'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('startTimestamp', startTimestamp))..add(DiagnosticsProperty('endTimestamp', endTimestamp))..add(DiagnosticsProperty('durationSeconds', durationSeconds))..add(DiagnosticsProperty('charactersRead', charactersRead));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingSession&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.startTimestamp, startTimestamp) || other.startTimestamp == startTimestamp)&&(identical(other.endTimestamp, endTimestamp) || other.endTimestamp == endTimestamp)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds)&&(identical(other.charactersRead, charactersRead) || other.charactersRead == charactersRead));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,startTimestamp,endTimestamp,durationSeconds,charactersRead);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'ReadingSession(id: $id, bookId: $bookId, chapterId: $chapterId, startTimestamp: $startTimestamp, endTimestamp: $endTimestamp, durationSeconds: $durationSeconds, charactersRead: $charactersRead)';
}


}

/// @nodoc
abstract mixin class _$ReadingSessionCopyWith<$Res> implements $ReadingSessionCopyWith<$Res> {
  factory _$ReadingSessionCopyWith(_ReadingSession value, $Res Function(_ReadingSession) _then) = __$ReadingSessionCopyWithImpl;
@override @useResult
$Res call({
 int id, int bookId, int chapterId, int startTimestamp, int endTimestamp, int durationSeconds, int charactersRead
});




}
/// @nodoc
class __$ReadingSessionCopyWithImpl<$Res>
    implements _$ReadingSessionCopyWith<$Res> {
  __$ReadingSessionCopyWithImpl(this._self, this._then);

  final _ReadingSession _self;
  final $Res Function(_ReadingSession) _then;

/// Create a copy of ReadingSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? startTimestamp = null,Object? endTimestamp = null,Object? durationSeconds = null,Object? charactersRead = null,}) {
  return _then(_ReadingSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,startTimestamp: null == startTimestamp ? _self.startTimestamp : startTimestamp // ignore: cast_nullable_to_non_nullable
as int,endTimestamp: null == endTimestamp ? _self.endTimestamp : endTimestamp // ignore: cast_nullable_to_non_nullable
as int,durationSeconds: null == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int,charactersRead: null == charactersRead ? _self.charactersRead : charactersRead // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
