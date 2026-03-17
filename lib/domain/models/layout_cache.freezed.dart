// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'layout_cache.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LayoutCache implements DiagnosticableTreeMixin {

/// 自增主键
 int get id;/// 书籍 ID
 int get bookId;/// 章节 ID
 int get chapterId;/// 排版配置哈希
 String get configHash;/// 页面偏移量列表（JSON 格式）
 String get pageOffsets;/// 总页数
 int get totalPages;/// 创建时间戳（Unix 时间戳，秒）
 int get createdAt;
/// Create a copy of LayoutCache
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LayoutCacheCopyWith<LayoutCache> get copyWith => _$LayoutCacheCopyWithImpl<LayoutCache>(this as LayoutCache, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'LayoutCache'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('configHash', configHash))..add(DiagnosticsProperty('pageOffsets', pageOffsets))..add(DiagnosticsProperty('totalPages', totalPages))..add(DiagnosticsProperty('createdAt', createdAt));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LayoutCache&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.configHash, configHash) || other.configHash == configHash)&&(identical(other.pageOffsets, pageOffsets) || other.pageOffsets == pageOffsets)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,configHash,pageOffsets,totalPages,createdAt);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'LayoutCache(id: $id, bookId: $bookId, chapterId: $chapterId, configHash: $configHash, pageOffsets: $pageOffsets, totalPages: $totalPages, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LayoutCacheCopyWith<$Res>  {
  factory $LayoutCacheCopyWith(LayoutCache value, $Res Function(LayoutCache) _then) = _$LayoutCacheCopyWithImpl;
@useResult
$Res call({
 int id, int bookId, int chapterId, String configHash, String pageOffsets, int totalPages, int createdAt
});




}
/// @nodoc
class _$LayoutCacheCopyWithImpl<$Res>
    implements $LayoutCacheCopyWith<$Res> {
  _$LayoutCacheCopyWithImpl(this._self, this._then);

  final LayoutCache _self;
  final $Res Function(LayoutCache) _then;

/// Create a copy of LayoutCache
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? configHash = null,Object? pageOffsets = null,Object? totalPages = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,configHash: null == configHash ? _self.configHash : configHash // ignore: cast_nullable_to_non_nullable
as String,pageOffsets: null == pageOffsets ? _self.pageOffsets : pageOffsets // ignore: cast_nullable_to_non_nullable
as String,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [LayoutCache].
extension LayoutCachePatterns on LayoutCache {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LayoutCache value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LayoutCache() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LayoutCache value)  $default,){
final _that = this;
switch (_that) {
case _LayoutCache():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LayoutCache value)?  $default,){
final _that = this;
switch (_that) {
case _LayoutCache() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int bookId,  int chapterId,  String configHash,  String pageOffsets,  int totalPages,  int createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LayoutCache() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.configHash,_that.pageOffsets,_that.totalPages,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int bookId,  int chapterId,  String configHash,  String pageOffsets,  int totalPages,  int createdAt)  $default,) {final _that = this;
switch (_that) {
case _LayoutCache():
return $default(_that.id,_that.bookId,_that.chapterId,_that.configHash,_that.pageOffsets,_that.totalPages,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int bookId,  int chapterId,  String configHash,  String pageOffsets,  int totalPages,  int createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LayoutCache() when $default != null:
return $default(_that.id,_that.bookId,_that.chapterId,_that.configHash,_that.pageOffsets,_that.totalPages,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc


class _LayoutCache with DiagnosticableTreeMixin implements LayoutCache {
  const _LayoutCache({required this.id, required this.bookId, required this.chapterId, required this.configHash, required this.pageOffsets, required this.totalPages, required this.createdAt});
  

/// 自增主键
@override final  int id;
/// 书籍 ID
@override final  int bookId;
/// 章节 ID
@override final  int chapterId;
/// 排版配置哈希
@override final  String configHash;
/// 页面偏移量列表（JSON 格式）
@override final  String pageOffsets;
/// 总页数
@override final  int totalPages;
/// 创建时间戳（Unix 时间戳，秒）
@override final  int createdAt;

/// Create a copy of LayoutCache
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LayoutCacheCopyWith<_LayoutCache> get copyWith => __$LayoutCacheCopyWithImpl<_LayoutCache>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'LayoutCache'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('bookId', bookId))..add(DiagnosticsProperty('chapterId', chapterId))..add(DiagnosticsProperty('configHash', configHash))..add(DiagnosticsProperty('pageOffsets', pageOffsets))..add(DiagnosticsProperty('totalPages', totalPages))..add(DiagnosticsProperty('createdAt', createdAt));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LayoutCache&&(identical(other.id, id) || other.id == id)&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.chapterId, chapterId) || other.chapterId == chapterId)&&(identical(other.configHash, configHash) || other.configHash == configHash)&&(identical(other.pageOffsets, pageOffsets) || other.pageOffsets == pageOffsets)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}


@override
int get hashCode => Object.hash(runtimeType,id,bookId,chapterId,configHash,pageOffsets,totalPages,createdAt);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'LayoutCache(id: $id, bookId: $bookId, chapterId: $chapterId, configHash: $configHash, pageOffsets: $pageOffsets, totalPages: $totalPages, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LayoutCacheCopyWith<$Res> implements $LayoutCacheCopyWith<$Res> {
  factory _$LayoutCacheCopyWith(_LayoutCache value, $Res Function(_LayoutCache) _then) = __$LayoutCacheCopyWithImpl;
@override @useResult
$Res call({
 int id, int bookId, int chapterId, String configHash, String pageOffsets, int totalPages, int createdAt
});




}
/// @nodoc
class __$LayoutCacheCopyWithImpl<$Res>
    implements _$LayoutCacheCopyWith<$Res> {
  __$LayoutCacheCopyWithImpl(this._self, this._then);

  final _LayoutCache _self;
  final $Res Function(_LayoutCache) _then;

/// Create a copy of LayoutCache
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? bookId = null,Object? chapterId = null,Object? configHash = null,Object? pageOffsets = null,Object? totalPages = null,Object? createdAt = null,}) {
  return _then(_LayoutCache(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,chapterId: null == chapterId ? _self.chapterId : chapterId // ignore: cast_nullable_to_non_nullable
as int,configHash: null == configHash ? _self.configHash : configHash // ignore: cast_nullable_to_non_nullable
as String,pageOffsets: null == pageOffsets ? _self.pageOffsets : pageOffsets // ignore: cast_nullable_to_non_nullable
as String,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
