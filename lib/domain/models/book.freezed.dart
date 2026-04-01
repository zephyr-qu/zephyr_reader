// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Book implements DiagnosticableTreeMixin {

 int get id;/// 书籍标题
 String get title;/// 作者
 String get author;/// 封面图片路径
 String? get coverPath;/// 描述/简介
 String? get description;/// 本地文件路径
 String get filePath;/// 文件类型（txt, epub, pdf）
 String get fileType;/// 文件大小（字节）
 int get fileSize;/// 总章节数
 int get totalChapters;/// 总字符数
 int get totalCharacters;/// 当前阅读章节 ID
 int? get currentChapterId;/// 当前阅读页码
 int get currentPageIndex;/// 总页数
 int get totalPages;/// 阅读进度 (0.0 - 1.0)
 double get progress;/// 阅读状态：reading-阅读中，completed-已完结，dropped-已弃坑，planned-计划阅读
 String get status;/// 是否置顶
 bool get isPinned;/// 分类 ID 列表
 List<int> get categoryIds;/// 创建时间
 DateTime get createdAt;/// 更新时间
 DateTime get updatedAt;/// 最后阅读时间
 DateTime? get lastReadAt;
/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCopyWith<Book> get copyWith => _$BookCopyWithImpl<Book>(this as Book, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Book'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('title', title))..add(DiagnosticsProperty('author', author))..add(DiagnosticsProperty('coverPath', coverPath))..add(DiagnosticsProperty('description', description))..add(DiagnosticsProperty('filePath', filePath))..add(DiagnosticsProperty('fileType', fileType))..add(DiagnosticsProperty('fileSize', fileSize))..add(DiagnosticsProperty('totalChapters', totalChapters))..add(DiagnosticsProperty('totalCharacters', totalCharacters))..add(DiagnosticsProperty('currentChapterId', currentChapterId))..add(DiagnosticsProperty('currentPageIndex', currentPageIndex))..add(DiagnosticsProperty('totalPages', totalPages))..add(DiagnosticsProperty('progress', progress))..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('isPinned', isPinned))..add(DiagnosticsProperty('categoryIds', categoryIds))..add(DiagnosticsProperty('createdAt', createdAt))..add(DiagnosticsProperty('updatedAt', updatedAt))..add(DiagnosticsProperty('lastReadAt', lastReadAt));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Book&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.coverPath, coverPath) || other.coverPath == coverPath)&&(identical(other.description, description) || other.description == description)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileType, fileType) || other.fileType == fileType)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.totalChapters, totalChapters) || other.totalChapters == totalChapters)&&(identical(other.totalCharacters, totalCharacters) || other.totalCharacters == totalCharacters)&&(identical(other.currentChapterId, currentChapterId) || other.currentChapterId == currentChapterId)&&(identical(other.currentPageIndex, currentPageIndex) || other.currentPageIndex == currentPageIndex)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.status, status) || other.status == status)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&const DeepCollectionEquality().equals(other.categoryIds, categoryIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,title,author,coverPath,description,filePath,fileType,fileSize,totalChapters,totalCharacters,currentChapterId,currentPageIndex,totalPages,progress,status,isPinned,const DeepCollectionEquality().hash(categoryIds),createdAt,updatedAt,lastReadAt]);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Book(id: $id, title: $title, author: $author, coverPath: $coverPath, description: $description, filePath: $filePath, fileType: $fileType, fileSize: $fileSize, totalChapters: $totalChapters, totalCharacters: $totalCharacters, currentChapterId: $currentChapterId, currentPageIndex: $currentPageIndex, totalPages: $totalPages, progress: $progress, status: $status, isPinned: $isPinned, categoryIds: $categoryIds, createdAt: $createdAt, updatedAt: $updatedAt, lastReadAt: $lastReadAt)';
}


}

/// @nodoc
abstract mixin class $BookCopyWith<$Res>  {
  factory $BookCopyWith(Book value, $Res Function(Book) _then) = _$BookCopyWithImpl;
@useResult
$Res call({
 int id, String title, String author, String? coverPath, String? description, String filePath, String fileType, int fileSize, int totalChapters, int totalCharacters, int? currentChapterId, int currentPageIndex, int totalPages, double progress, String status, bool isPinned, List<int> categoryIds, DateTime createdAt, DateTime updatedAt, DateTime? lastReadAt
});




}
/// @nodoc
class _$BookCopyWithImpl<$Res>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._self, this._then);

  final Book _self;
  final $Res Function(Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? author = null,Object? coverPath = freezed,Object? description = freezed,Object? filePath = null,Object? fileType = null,Object? fileSize = null,Object? totalChapters = null,Object? totalCharacters = null,Object? currentChapterId = freezed,Object? currentPageIndex = null,Object? totalPages = null,Object? progress = null,Object? status = null,Object? isPinned = null,Object? categoryIds = null,Object? createdAt = null,Object? updatedAt = null,Object? lastReadAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,coverPath: freezed == coverPath ? _self.coverPath : coverPath // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,fileType: null == fileType ? _self.fileType : fileType // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,totalChapters: null == totalChapters ? _self.totalChapters : totalChapters // ignore: cast_nullable_to_non_nullable
as int,totalCharacters: null == totalCharacters ? _self.totalCharacters : totalCharacters // ignore: cast_nullable_to_non_nullable
as int,currentChapterId: freezed == currentChapterId ? _self.currentChapterId : currentChapterId // ignore: cast_nullable_to_non_nullable
as int?,currentPageIndex: null == currentPageIndex ? _self.currentPageIndex : currentPageIndex // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,categoryIds: null == categoryIds ? _self.categoryIds : categoryIds // ignore: cast_nullable_to_non_nullable
as List<int>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastReadAt: freezed == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Book].
extension BookPatterns on Book {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Book value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Book value)  $default,){
final _that = this;
switch (_that) {
case _Book():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Book value)?  $default,){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String author,  String? coverPath,  String? description,  String filePath,  String fileType,  int fileSize,  int totalChapters,  int totalCharacters,  int? currentChapterId,  int currentPageIndex,  int totalPages,  double progress,  String status,  bool isPinned,  List<int> categoryIds,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastReadAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.coverPath,_that.description,_that.filePath,_that.fileType,_that.fileSize,_that.totalChapters,_that.totalCharacters,_that.currentChapterId,_that.currentPageIndex,_that.totalPages,_that.progress,_that.status,_that.isPinned,_that.categoryIds,_that.createdAt,_that.updatedAt,_that.lastReadAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String author,  String? coverPath,  String? description,  String filePath,  String fileType,  int fileSize,  int totalChapters,  int totalCharacters,  int? currentChapterId,  int currentPageIndex,  int totalPages,  double progress,  String status,  bool isPinned,  List<int> categoryIds,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastReadAt)  $default,) {final _that = this;
switch (_that) {
case _Book():
return $default(_that.id,_that.title,_that.author,_that.coverPath,_that.description,_that.filePath,_that.fileType,_that.fileSize,_that.totalChapters,_that.totalCharacters,_that.currentChapterId,_that.currentPageIndex,_that.totalPages,_that.progress,_that.status,_that.isPinned,_that.categoryIds,_that.createdAt,_that.updatedAt,_that.lastReadAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String author,  String? coverPath,  String? description,  String filePath,  String fileType,  int fileSize,  int totalChapters,  int totalCharacters,  int? currentChapterId,  int currentPageIndex,  int totalPages,  double progress,  String status,  bool isPinned,  List<int> categoryIds,  DateTime createdAt,  DateTime updatedAt,  DateTime? lastReadAt)?  $default,) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.coverPath,_that.description,_that.filePath,_that.fileType,_that.fileSize,_that.totalChapters,_that.totalCharacters,_that.currentChapterId,_that.currentPageIndex,_that.totalPages,_that.progress,_that.status,_that.isPinned,_that.categoryIds,_that.createdAt,_that.updatedAt,_that.lastReadAt);case _:
  return null;

}
}

}

/// @nodoc


class _Book with DiagnosticableTreeMixin implements Book {
  const _Book({required this.id, required this.title, required this.author, this.coverPath, this.description, required this.filePath, required this.fileType, required this.fileSize, required this.totalChapters, required this.totalCharacters, this.currentChapterId, this.currentPageIndex = 0, this.totalPages = 0, this.progress = 0.0, this.status = 'reading', this.isPinned = false, final  List<int> categoryIds = const <int>[], required this.createdAt, required this.updatedAt, this.lastReadAt}): _categoryIds = categoryIds;
  

@override final  int id;
/// 书籍标题
@override final  String title;
/// 作者
@override final  String author;
/// 封面图片路径
@override final  String? coverPath;
/// 描述/简介
@override final  String? description;
/// 本地文件路径
@override final  String filePath;
/// 文件类型（txt, epub, pdf）
@override final  String fileType;
/// 文件大小（字节）
@override final  int fileSize;
/// 总章节数
@override final  int totalChapters;
/// 总字符数
@override final  int totalCharacters;
/// 当前阅读章节 ID
@override final  int? currentChapterId;
/// 当前阅读页码
@override@JsonKey() final  int currentPageIndex;
/// 总页数
@override@JsonKey() final  int totalPages;
/// 阅读进度 (0.0 - 1.0)
@override@JsonKey() final  double progress;
/// 阅读状态：reading-阅读中，completed-已完结，dropped-已弃坑，planned-计划阅读
@override@JsonKey() final  String status;
/// 是否置顶
@override@JsonKey() final  bool isPinned;
/// 分类 ID 列表
 final  List<int> _categoryIds;
/// 分类 ID 列表
@override@JsonKey() List<int> get categoryIds {
  if (_categoryIds is EqualUnmodifiableListView) return _categoryIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categoryIds);
}

/// 创建时间
@override final  DateTime createdAt;
/// 更新时间
@override final  DateTime updatedAt;
/// 最后阅读时间
@override final  DateTime? lastReadAt;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookCopyWith<_Book> get copyWith => __$BookCopyWithImpl<_Book>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'Book'))
    ..add(DiagnosticsProperty('id', id))..add(DiagnosticsProperty('title', title))..add(DiagnosticsProperty('author', author))..add(DiagnosticsProperty('coverPath', coverPath))..add(DiagnosticsProperty('description', description))..add(DiagnosticsProperty('filePath', filePath))..add(DiagnosticsProperty('fileType', fileType))..add(DiagnosticsProperty('fileSize', fileSize))..add(DiagnosticsProperty('totalChapters', totalChapters))..add(DiagnosticsProperty('totalCharacters', totalCharacters))..add(DiagnosticsProperty('currentChapterId', currentChapterId))..add(DiagnosticsProperty('currentPageIndex', currentPageIndex))..add(DiagnosticsProperty('totalPages', totalPages))..add(DiagnosticsProperty('progress', progress))..add(DiagnosticsProperty('status', status))..add(DiagnosticsProperty('isPinned', isPinned))..add(DiagnosticsProperty('categoryIds', categoryIds))..add(DiagnosticsProperty('createdAt', createdAt))..add(DiagnosticsProperty('updatedAt', updatedAt))..add(DiagnosticsProperty('lastReadAt', lastReadAt));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Book&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.coverPath, coverPath) || other.coverPath == coverPath)&&(identical(other.description, description) || other.description == description)&&(identical(other.filePath, filePath) || other.filePath == filePath)&&(identical(other.fileType, fileType) || other.fileType == fileType)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.totalChapters, totalChapters) || other.totalChapters == totalChapters)&&(identical(other.totalCharacters, totalCharacters) || other.totalCharacters == totalCharacters)&&(identical(other.currentChapterId, currentChapterId) || other.currentChapterId == currentChapterId)&&(identical(other.currentPageIndex, currentPageIndex) || other.currentPageIndex == currentPageIndex)&&(identical(other.totalPages, totalPages) || other.totalPages == totalPages)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.status, status) || other.status == status)&&(identical(other.isPinned, isPinned) || other.isPinned == isPinned)&&const DeepCollectionEquality().equals(other._categoryIds, _categoryIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.lastReadAt, lastReadAt) || other.lastReadAt == lastReadAt));
}


@override
int get hashCode => Object.hashAll([runtimeType,id,title,author,coverPath,description,filePath,fileType,fileSize,totalChapters,totalCharacters,currentChapterId,currentPageIndex,totalPages,progress,status,isPinned,const DeepCollectionEquality().hash(_categoryIds),createdAt,updatedAt,lastReadAt]);

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'Book(id: $id, title: $title, author: $author, coverPath: $coverPath, description: $description, filePath: $filePath, fileType: $fileType, fileSize: $fileSize, totalChapters: $totalChapters, totalCharacters: $totalCharacters, currentChapterId: $currentChapterId, currentPageIndex: $currentPageIndex, totalPages: $totalPages, progress: $progress, status: $status, isPinned: $isPinned, categoryIds: $categoryIds, createdAt: $createdAt, updatedAt: $updatedAt, lastReadAt: $lastReadAt)';
}


}

/// @nodoc
abstract mixin class _$BookCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$BookCopyWith(_Book value, $Res Function(_Book) _then) = __$BookCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String author, String? coverPath, String? description, String filePath, String fileType, int fileSize, int totalChapters, int totalCharacters, int? currentChapterId, int currentPageIndex, int totalPages, double progress, String status, bool isPinned, List<int> categoryIds, DateTime createdAt, DateTime updatedAt, DateTime? lastReadAt
});




}
/// @nodoc
class __$BookCopyWithImpl<$Res>
    implements _$BookCopyWith<$Res> {
  __$BookCopyWithImpl(this._self, this._then);

  final _Book _self;
  final $Res Function(_Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? author = null,Object? coverPath = freezed,Object? description = freezed,Object? filePath = null,Object? fileType = null,Object? fileSize = null,Object? totalChapters = null,Object? totalCharacters = null,Object? currentChapterId = freezed,Object? currentPageIndex = null,Object? totalPages = null,Object? progress = null,Object? status = null,Object? isPinned = null,Object? categoryIds = null,Object? createdAt = null,Object? updatedAt = null,Object? lastReadAt = freezed,}) {
  return _then(_Book(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,coverPath: freezed == coverPath ? _self.coverPath : coverPath // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,filePath: null == filePath ? _self.filePath : filePath // ignore: cast_nullable_to_non_nullable
as String,fileType: null == fileType ? _self.fileType : fileType // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,totalChapters: null == totalChapters ? _self.totalChapters : totalChapters // ignore: cast_nullable_to_non_nullable
as int,totalCharacters: null == totalCharacters ? _self.totalCharacters : totalCharacters // ignore: cast_nullable_to_non_nullable
as int,currentChapterId: freezed == currentChapterId ? _self.currentChapterId : currentChapterId // ignore: cast_nullable_to_non_nullable
as int?,currentPageIndex: null == currentPageIndex ? _self.currentPageIndex : currentPageIndex // ignore: cast_nullable_to_non_nullable
as int,totalPages: null == totalPages ? _self.totalPages : totalPages // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,isPinned: null == isPinned ? _self.isPinned : isPinned // ignore: cast_nullable_to_non_nullable
as bool,categoryIds: null == categoryIds ? _self._categoryIds : categoryIds // ignore: cast_nullable_to_non_nullable
as List<int>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,lastReadAt: freezed == lastReadAt ? _self.lastReadAt : lastReadAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
