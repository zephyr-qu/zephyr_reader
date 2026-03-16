// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookmark.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookmarkItem implements DiagnosticableTreeMixin {

/// 书签唯一标识（UUID）
 String get id;/// 关联的书籍 ID
 String get bookId;/// 关联的章节 ID
 int get chapterId;/// 书签位置（字符偏移量或页码）
 int get position;/// 书签备注
 String? get note;/// 创建时间
 DateTime get createdAt;
/// Create a copy of BookmarkItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookmarkItemCopyWith<BookmarkItem> get copyWith => _$BookmarkItemCopyWithImpl<BookmarkItem>(this as BookmarkItem, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'BookmarkItem'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('position', position))..add(DiagnosticsProperty('note', note))..add(DiagnosticsProperty('createdAt', createdAt));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookmarkItem&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.position, position) || other.position == position)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,position,note,createdAt);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'BookmarkItem(id: $id, bookId: $bookId, chapterId: $chapterId, position: $position, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $BookmarkItemCopyWith<$Res>  {
  factory $BookmarkItemCopyWith(BookmarkItem value, $Res Function(BookmarkItem) _then) = _$BookmarkItemCopyWithImpl;
@useResult
$Res call({
 String id, String bookId, int chapterId, int position, String? note, DateTime createdAt
});




}
/// @nodoc
class _$BookmarkItemCopyWithImpl<$Res>
    implements $BookmarkItemCopyWith<$Res> {
  _$BookmarkItemCopyWithImpl(this._self, this._then);

  final BookmarkItem _self;
  final $Res Function(BookmarkItem) _then;

/// Create a copy of BookmarkItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? position = null,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [BookmarkItem].
extension BookmarkItemPatterns on BookmarkItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookmarkItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookmarkItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookmarkItem value)  $default,){
final _that = this;
switch (_that) {
case _BookmarkItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookmarkItem value)?  $default,){
final _that = this;
switch (_that) {
case _BookmarkItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String bookId,  int chapterId,  int position,  String? note,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookmarkItem() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.position,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String bookId,  int chapterId,  int position,  String? note,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _BookmarkItem():
return $default(_that.id,_that.bookId,_that.chapterId,_that.position,_that.note,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String bookId,  int chapterId,  int position,  String? note,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _BookmarkItem() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.position,_that.note,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _BookmarkItem with DiagnosticableTreeMixin implements BookmarkItem {
  const _BookmarkItem({required this.id, required this.bookId, required this.chapterId, required this.position, this.note, required this.createdAt});
  

/// 书签唯一标识（UUID）
@override final  String id;
/// 关联的书籍 ID
@override final  String bookId;
/// 关联的章节 ID
@override final  int chapterId;
/// 书签位置（字符偏移量或页码）
@override final  int position;
/// 书签备注
@override final  String? note;
/// 创建时间
@override final  DateTime createdAt;

/// Create a copy of BookmarkItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookmarkItemCopyWith<_BookmarkItem> get copyWith => __$BookmarkItemCopyWithImpl<_BookmarkItem>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'BookmarkItem'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('position', position))..add(DiagnosticsProperty('note', note))..add(DiagnosticsProperty('createdAt', createdAt));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookmarkItem&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.position, position) || other.position == position)&&(identical(other.note, note) || other.note == note)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,position,note,createdAt);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'BookmarkItem(id: $id, bookId: $bookId, chapterId: $chapterId, position: $position, note: $note, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$BookmarkItemCopyWith<$Res> implements $BookmarkItemCopyWith<$Res> {
  factory _$BookmarkItemCopyWith(_BookmarkItem value, $Res Function(_BookmarkItem) _then) = __$BookmarkItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String bookId, int chapterId, int position, String? note, DateTime createdAt
});




}
/// @nodoc
class __$BookmarkItemCopyWithImpl<$Res>
    implements _$BookmarkItemCopyWith<$Res> {
  __$BookmarkItemCopyWithImpl(this._self, this._then);

  final _BookmarkItem _self;
  final $Res Function(_BookmarkItem) _then;

/// Create a copy of BookmarkItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? position = null,Object? note = freezed,Object? createdAt = null,}) {
  return _then(_BookmarkItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as String,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,position: null == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
