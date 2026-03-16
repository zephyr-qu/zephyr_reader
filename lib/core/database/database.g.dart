// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileFormatMeta = const VerificationMeta(
    'fileFormat',
  );
  @override
  late final GeneratedColumn<String> fileFormat = GeneratedColumn<String>(
    'file_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalCharactersMeta = const VerificationMeta(
    'totalCharacters',
  );
  @override
  late final GeneratedColumn<int> totalCharacters = GeneratedColumn<int>(
    'total_characters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentChapterIdMeta = const VerificationMeta(
    'currentChapterId',
  );
  @override
  late final GeneratedColumn<int> currentChapterId = GeneratedColumn<int>(
    'current_chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentPageIndexMeta = const VerificationMeta(
    'currentPageIndex',
  );
  @override
  late final GeneratedColumn<int> currentPageIndex = GeneratedColumn<int>(
    'current_page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalPagesMeta = const VerificationMeta(
    'totalPages',
  );
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
    'total_pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('reading'),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    author,
    coverPath,
    description,
    filePath,
    fileFormat,
    fileSize,
    totalChapters,
    totalCharacters,
    currentChapterId,
    currentPageIndex,
    totalPages,
    progress,
    status,
    isPinned,
    createdAt,
    updatedAt,
    lastReadAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_format')) {
      context.handle(
        _fileFormatMeta,
        fileFormat.isAcceptableOrUnknown(data['file_format']!, _fileFormatMeta),
      );
    } else if (isInserting) {
      context.missing(_fileFormatMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
        _totalChaptersMeta,
        totalChapters.isAcceptableOrUnknown(
          data['total_chapters']!,
          _totalChaptersMeta,
        ),
      );
    }
    if (data.containsKey('total_characters')) {
      context.handle(
        _totalCharactersMeta,
        totalCharacters.isAcceptableOrUnknown(
          data['total_characters']!,
          _totalCharactersMeta,
        ),
      );
    }
    if (data.containsKey('current_chapter_id')) {
      context.handle(
        _currentChapterIdMeta,
        currentChapterId.isAcceptableOrUnknown(
          data['current_chapter_id']!,
          _currentChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('current_page_index')) {
      context.handle(
        _currentPageIndexMeta,
        currentPageIndex.isAcceptableOrUnknown(
          data['current_page_index']!,
          _currentPageIndexMeta,
        ),
      );
    }
    if (data.containsKey('total_pages')) {
      context.handle(
        _totalPagesMeta,
        totalPages.isAcceptableOrUnknown(data['total_pages']!, _totalPagesMeta),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_format'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      )!,
      totalCharacters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_characters'],
      )!,
      currentChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_chapter_id'],
      ),
      currentPageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_page_index'],
      )!,
      totalPages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_pages'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastReadAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_read_at'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String title;
  final String author;
  final String? coverPath;
  final String? description;
  final String filePath;
  final String fileFormat;
  final int fileSize;
  final int totalChapters;
  final int totalCharacters;
  final int? currentChapterId;
  final int currentPageIndex;
  final int totalPages;
  final double progress;
  final String status;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastReadAt;
  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverPath,
    this.description,
    required this.filePath,
    required this.fileFormat,
    required this.fileSize,
    required this.totalChapters,
    required this.totalCharacters,
    this.currentChapterId,
    required this.currentPageIndex,
    required this.totalPages,
    required this.progress,
    required this.status,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.lastReadAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['file_path'] = Variable<String>(filePath);
    map['file_format'] = Variable<String>(fileFormat);
    map['file_size'] = Variable<int>(fileSize);
    map['total_chapters'] = Variable<int>(totalChapters);
    map['total_characters'] = Variable<int>(totalCharacters);
    if (!nullToAbsent || currentChapterId != null) {
      map['current_chapter_id'] = Variable<int>(currentChapterId);
    }
    map['current_page_index'] = Variable<int>(currentPageIndex);
    map['total_pages'] = Variable<int>(totalPages);
    map['progress'] = Variable<double>(progress);
    map['status'] = Variable<String>(status);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastReadAt != null) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      author: Value(author),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      filePath: Value(filePath),
      fileFormat: Value(fileFormat),
      fileSize: Value(fileSize),
      totalChapters: Value(totalChapters),
      totalCharacters: Value(totalCharacters),
      currentChapterId: currentChapterId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentChapterId),
      currentPageIndex: Value(currentPageIndex),
      totalPages: Value(totalPages),
      progress: Value(progress),
      status: Value(status),
      isPinned: Value(isPinned),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastReadAt: lastReadAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadAt),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      description: serializer.fromJson<String?>(json['description']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileFormat: serializer.fromJson<String>(json['fileFormat']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
      totalCharacters: serializer.fromJson<int>(json['totalCharacters']),
      currentChapterId: serializer.fromJson<int?>(json['currentChapterId']),
      currentPageIndex: serializer.fromJson<int>(json['currentPageIndex']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      progress: serializer.fromJson<double>(json['progress']),
      status: serializer.fromJson<String>(json['status']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastReadAt: serializer.fromJson<DateTime?>(json['lastReadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'coverPath': serializer.toJson<String?>(coverPath),
      'description': serializer.toJson<String?>(description),
      'filePath': serializer.toJson<String>(filePath),
      'fileFormat': serializer.toJson<String>(fileFormat),
      'fileSize': serializer.toJson<int>(fileSize),
      'totalChapters': serializer.toJson<int>(totalChapters),
      'totalCharacters': serializer.toJson<int>(totalCharacters),
      'currentChapterId': serializer.toJson<int?>(currentChapterId),
      'currentPageIndex': serializer.toJson<int>(currentPageIndex),
      'totalPages': serializer.toJson<int>(totalPages),
      'progress': serializer.toJson<double>(progress),
      'status': serializer.toJson<String>(status),
      'isPinned': serializer.toJson<bool>(isPinned),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastReadAt': serializer.toJson<DateTime?>(lastReadAt),
    };
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    Value<String?> coverPath = const Value.absent(),
    Value<String?> description = const Value.absent(),
    String? filePath,
    String? fileFormat,
    int? fileSize,
    int? totalChapters,
    int? totalCharacters,
    Value<int?> currentChapterId = const Value.absent(),
    int? currentPageIndex,
    int? totalPages,
    double? progress,
    String? status,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastReadAt = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author ?? this.author,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    description: description.present ? description.value : this.description,
    filePath: filePath ?? this.filePath,
    fileFormat: fileFormat ?? this.fileFormat,
    fileSize: fileSize ?? this.fileSize,
    totalChapters: totalChapters ?? this.totalChapters,
    totalCharacters: totalCharacters ?? this.totalCharacters,
    currentChapterId: currentChapterId.present
        ? currentChapterId.value
        : this.currentChapterId,
    currentPageIndex: currentPageIndex ?? this.currentPageIndex,
    totalPages: totalPages ?? this.totalPages,
    progress: progress ?? this.progress,
    status: status ?? this.status,
    isPinned: isPinned ?? this.isPinned,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastReadAt: lastReadAt.present ? lastReadAt.value : this.lastReadAt,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      description: data.description.present
          ? data.description.value
          : this.description,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileFormat: data.fileFormat.present
          ? data.fileFormat.value
          : this.fileFormat,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      totalCharacters: data.totalCharacters.present
          ? data.totalCharacters.value
          : this.totalCharacters,
      currentChapterId: data.currentChapterId.present
          ? data.currentChapterId.value
          : this.currentChapterId,
      currentPageIndex: data.currentPageIndex.present
          ? data.currentPageIndex.value
          : this.currentPageIndex,
      totalPages: data.totalPages.present
          ? data.totalPages.value
          : this.totalPages,
      progress: data.progress.present ? data.progress.value : this.progress,
      status: data.status.present ? data.status.value : this.status,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastReadAt: data.lastReadAt.present
          ? data.lastReadAt.value
          : this.lastReadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('description: $description, ')
          ..write('filePath: $filePath, ')
          ..write('fileFormat: $fileFormat, ')
          ..write('fileSize: $fileSize, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('totalCharacters: $totalCharacters, ')
          ..write('currentChapterId: $currentChapterId, ')
          ..write('currentPageIndex: $currentPageIndex, ')
          ..write('totalPages: $totalPages, ')
          ..write('progress: $progress, ')
          ..write('status: $status, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    coverPath,
    description,
    filePath,
    fileFormat,
    fileSize,
    totalChapters,
    totalCharacters,
    currentChapterId,
    currentPageIndex,
    totalPages,
    progress,
    status,
    isPinned,
    createdAt,
    updatedAt,
    lastReadAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverPath == this.coverPath &&
          other.description == this.description &&
          other.filePath == this.filePath &&
          other.fileFormat == this.fileFormat &&
          other.fileSize == this.fileSize &&
          other.totalChapters == this.totalChapters &&
          other.totalCharacters == this.totalCharacters &&
          other.currentChapterId == this.currentChapterId &&
          other.currentPageIndex == this.currentPageIndex &&
          other.totalPages == this.totalPages &&
          other.progress == this.progress &&
          other.status == this.status &&
          other.isPinned == this.isPinned &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastReadAt == this.lastReadAt);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> author;
  final Value<String?> coverPath;
  final Value<String?> description;
  final Value<String> filePath;
  final Value<String> fileFormat;
  final Value<int> fileSize;
  final Value<int> totalChapters;
  final Value<int> totalCharacters;
  final Value<int?> currentChapterId;
  final Value<int> currentPageIndex;
  final Value<int> totalPages;
  final Value<double> progress;
  final Value<String> status;
  final Value<bool> isPinned;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastReadAt;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.description = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileFormat = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.totalCharacters = const Value.absent(),
    this.currentChapterId = const Value.absent(),
    this.currentPageIndex = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.progress = const Value.absent(),
    this.status = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String author,
    this.coverPath = const Value.absent(),
    this.description = const Value.absent(),
    required String filePath,
    required String fileFormat,
    this.fileSize = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.totalCharacters = const Value.absent(),
    this.currentChapterId = const Value.absent(),
    this.currentPageIndex = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.progress = const Value.absent(),
    this.status = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
  }) : title = Value(title),
       author = Value(author),
       filePath = Value(filePath),
       fileFormat = Value(fileFormat);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverPath,
    Expression<String>? description,
    Expression<String>? filePath,
    Expression<String>? fileFormat,
    Expression<int>? fileSize,
    Expression<int>? totalChapters,
    Expression<int>? totalCharacters,
    Expression<int>? currentChapterId,
    Expression<int>? currentPageIndex,
    Expression<int>? totalPages,
    Expression<double>? progress,
    Expression<String>? status,
    Expression<bool>? isPinned,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastReadAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverPath != null) 'cover_path': coverPath,
      if (description != null) 'description': description,
      if (filePath != null) 'file_path': filePath,
      if (fileFormat != null) 'file_format': fileFormat,
      if (fileSize != null) 'file_size': fileSize,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (totalCharacters != null) 'total_characters': totalCharacters,
      if (currentChapterId != null) 'current_chapter_id': currentChapterId,
      if (currentPageIndex != null) 'current_page_index': currentPageIndex,
      if (totalPages != null) 'total_pages': totalPages,
      if (progress != null) 'progress': progress,
      if (status != null) 'status': status,
      if (isPinned != null) 'is_pinned': isPinned,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? author,
    Value<String?>? coverPath,
    Value<String?>? description,
    Value<String>? filePath,
    Value<String>? fileFormat,
    Value<int>? fileSize,
    Value<int>? totalChapters,
    Value<int>? totalCharacters,
    Value<int?>? currentChapterId,
    Value<int>? currentPageIndex,
    Value<int>? totalPages,
    Value<double>? progress,
    Value<String>? status,
    Value<bool>? isPinned,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastReadAt,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      fileFormat: fileFormat ?? this.fileFormat,
      fileSize: fileSize ?? this.fileSize,
      totalChapters: totalChapters ?? this.totalChapters,
      totalCharacters: totalCharacters ?? this.totalCharacters,
      currentChapterId: currentChapterId ?? this.currentChapterId,
      currentPageIndex: currentPageIndex ?? this.currentPageIndex,
      totalPages: totalPages ?? this.totalPages,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileFormat.present) {
      map['file_format'] = Variable<String>(fileFormat.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (totalCharacters.present) {
      map['total_characters'] = Variable<int>(totalCharacters.value);
    }
    if (currentChapterId.present) {
      map['current_chapter_id'] = Variable<int>(currentChapterId.value);
    }
    if (currentPageIndex.present) {
      map['current_page_index'] = Variable<int>(currentPageIndex.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('description: $description, ')
          ..write('filePath: $filePath, ')
          ..write('fileFormat: $fileFormat, ')
          ..write('fileSize: $fileSize, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('totalCharacters: $totalCharacters, ')
          ..write('currentChapterId: $currentChapterId, ')
          ..write('currentPageIndex: $currentPageIndex, ')
          ..write('totalPages: $totalPages, ')
          ..write('progress: $progress, ')
          ..write('status: $status, ')
          ..write('isPinned: $isPinned, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }
}

class $ChaptersTable extends Chapters with TableInfo<$ChaptersTable, Chapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentFileMeta = const VerificationMeta(
    'contentFile',
  );
  @override
  late final GeneratedColumn<String> contentFile = GeneratedColumn<String>(
    'content_file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wordCountMeta = const VerificationMeta(
    'wordCount',
  );
  @override
  late final GeneratedColumn<int> wordCount = GeneratedColumn<int>(
    'word_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    title,
    contentFile,
    chapterIndex,
    wordCount,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content_file')) {
      context.handle(
        _contentFileMeta,
        contentFile.isAcceptableOrUnknown(
          data['content_file']!,
          _contentFileMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentFileMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('word_count')) {
      context.handle(
        _wordCountMeta,
        wordCount.isAcceptableOrUnknown(data['word_count']!, _wordCountMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chapter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      contentFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_file'],
      )!,
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      wordCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}word_count'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $ChaptersTable createAlias(String alias) {
    return $ChaptersTable(attachedDatabase, alias);
  }
}

class Chapter extends DataClass implements Insertable<Chapter> {
  final int id;

  /// 关联的小说ID
  final int bookId;

  /// 章节标题
  final String title;

  /// 章节内容文件路径
  final String contentFile;

  /// 章节索引（从1开始）
  final int chapterIndex;

  /// 字数
  final int wordCount;

  /// 缓存时间
  final DateTime cachedAt;
  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.contentFile,
    required this.chapterIndex,
    required this.wordCount,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    map['title'] = Variable<String>(title);
    map['content_file'] = Variable<String>(contentFile);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['word_count'] = Variable<int>(wordCount);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  ChaptersCompanion toCompanion(bool nullToAbsent) {
    return ChaptersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      title: Value(title),
      contentFile: Value(contentFile),
      chapterIndex: Value(chapterIndex),
      wordCount: Value(wordCount),
      cachedAt: Value(cachedAt),
    );
  }

  factory Chapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chapter(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      contentFile: serializer.fromJson<String>(json['contentFile']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      wordCount: serializer.fromJson<int>(json['wordCount']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'title': serializer.toJson<String>(title),
      'contentFile': serializer.toJson<String>(contentFile),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'wordCount': serializer.toJson<int>(wordCount),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  Chapter copyWith({
    int? id,
    int? bookId,
    String? title,
    String? contentFile,
    int? chapterIndex,
    int? wordCount,
    DateTime? cachedAt,
  }) => Chapter(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    title: title ?? this.title,
    contentFile: contentFile ?? this.contentFile,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    wordCount: wordCount ?? this.wordCount,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  Chapter copyWithCompanion(ChaptersCompanion data) {
    return Chapter(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      contentFile: data.contentFile.present
          ? data.contentFile.value
          : this.contentFile,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      wordCount: data.wordCount.present ? data.wordCount.value : this.wordCount,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chapter(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('contentFile: $contentFile, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('wordCount: $wordCount, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    title,
    contentFile,
    chapterIndex,
    wordCount,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chapter &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.contentFile == this.contentFile &&
          other.chapterIndex == this.chapterIndex &&
          other.wordCount == this.wordCount &&
          other.cachedAt == this.cachedAt);
}

class ChaptersCompanion extends UpdateCompanion<Chapter> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<String> title;
  final Value<String> contentFile;
  final Value<int> chapterIndex;
  final Value<int> wordCount;
  final Value<DateTime> cachedAt;
  const ChaptersCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.contentFile = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.wordCount = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  ChaptersCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    required String title,
    required String contentFile,
    required int chapterIndex,
    this.wordCount = const Value.absent(),
    this.cachedAt = const Value.absent(),
  }) : bookId = Value(bookId),
       title = Value(title),
       contentFile = Value(contentFile),
       chapterIndex = Value(chapterIndex);
  static Insertable<Chapter> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<String>? title,
    Expression<String>? contentFile,
    Expression<int>? chapterIndex,
    Expression<int>? wordCount,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (contentFile != null) 'content_file': contentFile,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (wordCount != null) 'word_count': wordCount,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  ChaptersCompanion copyWith({
    Value<int>? id,
    Value<int>? bookId,
    Value<String>? title,
    Value<String>? contentFile,
    Value<int>? chapterIndex,
    Value<int>? wordCount,
    Value<DateTime>? cachedAt,
  }) {
    return ChaptersCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      contentFile: contentFile ?? this.contentFile,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      wordCount: wordCount ?? this.wordCount,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (contentFile.present) {
      map['content_file'] = Variable<String>(contentFile.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (wordCount.present) {
      map['word_count'] = Variable<int>(wordCount.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChaptersCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('contentFile: $contentFile, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('wordCount: $wordCount, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookmarkIdMeta = const VerificationMeta(
    'bookmarkId',
  );
  @override
  late final GeneratedColumn<String> bookmarkId = GeneratedColumn<String>(
    'bookmark_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdTimestampMeta = const VerificationMeta(
    'createdTimestamp',
  );
  @override
  late final GeneratedColumn<int> createdTimestamp = GeneratedColumn<int>(
    'created_timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookmarkId,
    bookId,
    chapterId,
    pageIndex,
    title,
    createdTimestamp,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('bookmark_id')) {
      context.handle(
        _bookmarkIdMeta,
        bookmarkId.isAcceptableOrUnknown(data['bookmark_id']!, _bookmarkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookmarkIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_timestamp')) {
      context.handle(
        _createdTimestampMeta,
        createdTimestamp.isAcceptableOrUnknown(
          data['created_timestamp']!,
          _createdTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdTimestampMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookmarkId};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      bookmarkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bookmark_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_timestamp'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  /// 书签 ID（UUID，主键）
  final String bookmarkId;

  /// 关联的小说 ID
  final int bookId;

  /// 关联的章节 ID
  final int chapterId;

  /// 书签位置（页码）
  final int pageIndex;

  /// 书签标题
  final String title;

  /// 创建时间戳（Unix 时间戳，秒）
  final int createdTimestamp;

  /// 书签备注
  final String? note;
  const Bookmark({
    required this.bookmarkId,
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.title,
    required this.createdTimestamp,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['bookmark_id'] = Variable<String>(bookmarkId);
    map['book_id'] = Variable<int>(bookId);
    map['chapter_id'] = Variable<int>(chapterId);
    map['page_index'] = Variable<int>(pageIndex);
    map['title'] = Variable<String>(title);
    map['created_timestamp'] = Variable<int>(createdTimestamp);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      bookmarkId: Value(bookmarkId),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      pageIndex: Value(pageIndex),
      title: Value(title),
      createdTimestamp: Value(createdTimestamp),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      bookmarkId: serializer.fromJson<String>(json['bookmarkId']),
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      title: serializer.fromJson<String>(json['title']),
      createdTimestamp: serializer.fromJson<int>(json['createdTimestamp']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookmarkId': serializer.toJson<String>(bookmarkId),
      'bookId': serializer.toJson<int>(bookId),
      'chapterId': serializer.toJson<int>(chapterId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'title': serializer.toJson<String>(title),
      'createdTimestamp': serializer.toJson<int>(createdTimestamp),
      'note': serializer.toJson<String?>(note),
    };
  }

  Bookmark copyWith({
    String? bookmarkId,
    int? bookId,
    int? chapterId,
    int? pageIndex,
    String? title,
    int? createdTimestamp,
    Value<String?> note = const Value.absent(),
  }) => Bookmark(
    bookmarkId: bookmarkId ?? this.bookmarkId,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    pageIndex: pageIndex ?? this.pageIndex,
    title: title ?? this.title,
    createdTimestamp: createdTimestamp ?? this.createdTimestamp,
    note: note.present ? note.value : this.note,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      bookmarkId: data.bookmarkId.present
          ? data.bookmarkId.value
          : this.bookmarkId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      title: data.title.present ? data.title.value : this.title,
      createdTimestamp: data.createdTimestamp.present
          ? data.createdTimestamp.value
          : this.createdTimestamp,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('bookmarkId: $bookmarkId, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('title: $title, ')
          ..write('createdTimestamp: $createdTimestamp, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookmarkId,
    bookId,
    chapterId,
    pageIndex,
    title,
    createdTimestamp,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.bookmarkId == this.bookmarkId &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.pageIndex == this.pageIndex &&
          other.title == this.title &&
          other.createdTimestamp == this.createdTimestamp &&
          other.note == this.note);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> bookmarkId;
  final Value<int> bookId;
  final Value<int> chapterId;
  final Value<int> pageIndex;
  final Value<String> title;
  final Value<int> createdTimestamp;
  final Value<String?> note;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.bookmarkId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.title = const Value.absent(),
    this.createdTimestamp = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String bookmarkId,
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    required int createdTimestamp,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
    required int position,
  }) : bookmarkId = Value(bookmarkId),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       pageIndex = Value(pageIndex),
       title = Value(title),
       createdTimestamp = Value(createdTimestamp);
  static Insertable<Bookmark> custom({
    Expression<String>? bookmarkId,
    Expression<int>? bookId,
    Expression<int>? chapterId,
    Expression<int>? pageIndex,
    Expression<String>? title,
    Expression<int>? createdTimestamp,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookmarkId != null) 'bookmark_id': bookmarkId,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (title != null) 'title': title,
      if (createdTimestamp != null) 'created_timestamp': createdTimestamp,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? bookmarkId,
    Value<int>? bookId,
    Value<int>? chapterId,
    Value<int>? pageIndex,
    Value<String>? title,
    Value<int>? createdTimestamp,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      bookmarkId: bookmarkId ?? this.bookmarkId,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      pageIndex: pageIndex ?? this.pageIndex,
      title: title ?? this.title,
      createdTimestamp: createdTimestamp ?? this.createdTimestamp,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookmarkId.present) {
      map['bookmark_id'] = Variable<String>(bookmarkId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdTimestamp.present) {
      map['created_timestamp'] = Variable<int>(createdTimestamp.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('bookmarkId: $bookmarkId, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('title: $title, ')
          ..write('createdTimestamp: $createdTimestamp, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingHistoriesTable extends ReadingHistories
    with TableInfo<$ReadingHistoriesTable, ReadingHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<int> bookId = GeneratedColumn<int>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chapters (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readTimeMeta = const VerificationMeta(
    'readTime',
  );
  @override
  late final GeneratedColumn<DateTime> readTime = GeneratedColumn<DateTime>(
    'read_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<int> duration = GeneratedColumn<int>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterId,
    position,
    readTime,
    duration,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('read_time')) {
      context.handle(
        _readTimeMeta,
        readTime.isAcceptableOrUnknown(data['read_time']!, _readTimeMeta),
      );
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      readTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_time'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration'],
      )!,
    );
  }

  @override
  $ReadingHistoriesTable createAlias(String alias) {
    return $ReadingHistoriesTable(attachedDatabase, alias);
  }
}

class ReadingHistory extends DataClass implements Insertable<ReadingHistory> {
  final int id;

  /// 关联的小说ID
  final int bookId;

  /// 关联的章节ID
  final int chapterId;

  /// 阅读位置（字符偏移量）
  final int position;

  /// 阅读时间
  final DateTime readTime;

  /// 阅读时长（秒）
  final int duration;
  const ReadingHistory({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.position,
    required this.readTime,
    required this.duration,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<int>(bookId);
    map['chapter_id'] = Variable<int>(chapterId);
    map['position'] = Variable<int>(position);
    map['read_time'] = Variable<DateTime>(readTime);
    map['duration'] = Variable<int>(duration);
    return map;
  }

  ReadingHistoriesCompanion toCompanion(bool nullToAbsent) {
    return ReadingHistoriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      position: Value(position),
      readTime: Value(readTime),
      duration: Value(duration),
    );
  }

  factory ReadingHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingHistory(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<int>(json['bookId']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      position: serializer.fromJson<int>(json['position']),
      readTime: serializer.fromJson<DateTime>(json['readTime']),
      duration: serializer.fromJson<int>(json['duration']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<int>(bookId),
      'chapterId': serializer.toJson<int>(chapterId),
      'position': serializer.toJson<int>(position),
      'readTime': serializer.toJson<DateTime>(readTime),
      'duration': serializer.toJson<int>(duration),
    };
  }

  ReadingHistory copyWith({
    int? id,
    int? bookId,
    int? chapterId,
    int? position,
    DateTime? readTime,
    int? duration,
  }) => ReadingHistory(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    position: position ?? this.position,
    readTime: readTime ?? this.readTime,
    duration: duration ?? this.duration,
  );
  ReadingHistory copyWithCompanion(ReadingHistoriesCompanion data) {
    return ReadingHistory(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      position: data.position.present ? data.position.value : this.position,
      readTime: data.readTime.present ? data.readTime.value : this.readTime,
      duration: data.duration.present ? data.duration.value : this.duration,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistory(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('position: $position, ')
          ..write('readTime: $readTime, ')
          ..write('duration: $duration')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, bookId, chapterId, position, readTime, duration);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingHistory &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.position == this.position &&
          other.readTime == this.readTime &&
          other.duration == this.duration);
}

class ReadingHistoriesCompanion extends UpdateCompanion<ReadingHistory> {
  final Value<int> id;
  final Value<int> bookId;
  final Value<int> chapterId;
  final Value<int> position;
  final Value<DateTime> readTime;
  final Value<int> duration;
  const ReadingHistoriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.position = const Value.absent(),
    this.readTime = const Value.absent(),
    this.duration = const Value.absent(),
  });
  ReadingHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required int bookId,
    required int chapterId,
    required int position,
    this.readTime = const Value.absent(),
    this.duration = const Value.absent(),
  }) : bookId = Value(bookId),
       chapterId = Value(chapterId),
       position = Value(position);
  static Insertable<ReadingHistory> custom({
    Expression<int>? id,
    Expression<int>? bookId,
    Expression<int>? chapterId,
    Expression<int>? position,
    Expression<DateTime>? readTime,
    Expression<int>? duration,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (position != null) 'position': position,
      if (readTime != null) 'read_time': readTime,
      if (duration != null) 'duration': duration,
    });
  }

  ReadingHistoriesCompanion copyWith({
    Value<int>? id,
    Value<int>? bookId,
    Value<int>? chapterId,
    Value<int>? position,
    Value<DateTime>? readTime,
    Value<int>? duration,
  }) {
    return ReadingHistoriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      position: position ?? this.position,
      readTime: readTime ?? this.readTime,
      duration: duration ?? this.duration,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<int>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (readTime.present) {
      map['read_time'] = Variable<DateTime>(readTime.value);
    }
    if (duration.present) {
      map['duration'] = Variable<int>(duration.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('position: $position, ')
          ..write('readTime: $readTime, ')
          ..write('duration: $duration')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressesTable extends ReadingProgresses
    with TableInfo<$ReadingProgressesTable, ReadingProgressItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageIndexMeta = const VerificationMeta(
    'pageIndex',
  );
  @override
  late final GeneratedColumn<int> pageIndex = GeneratedColumn<int>(
    'page_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPagesMeta = const VerificationMeta(
    'totalPages',
  );
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
    'total_pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingTimeSecondsMeta =
      const VerificationMeta('readingTimeSeconds');
  @override
  late final GeneratedColumn<int> readingTimeSeconds = GeneratedColumn<int>(
    'reading_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReadTimestampMeta = const VerificationMeta(
    'lastReadTimestamp',
  );
  @override
  late final GeneratedColumn<int> lastReadTimestamp = GeneratedColumn<int>(
    'last_read_timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    chapterId,
    pageIndex,
    totalPages,
    progress,
    readingTimeSeconds,
    lastReadTimestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('page_index')) {
      context.handle(
        _pageIndexMeta,
        pageIndex.isAcceptableOrUnknown(data['page_index']!, _pageIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_pageIndexMeta);
    }
    if (data.containsKey('total_pages')) {
      context.handle(
        _totalPagesMeta,
        totalPages.isAcceptableOrUnknown(data['total_pages']!, _totalPagesMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPagesMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    } else if (isInserting) {
      context.missing(_progressMeta);
    }
    if (data.containsKey('reading_time_seconds')) {
      context.handle(
        _readingTimeSecondsMeta,
        readingTimeSeconds.isAcceptableOrUnknown(
          data['reading_time_seconds']!,
          _readingTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('last_read_timestamp')) {
      context.handle(
        _lastReadTimestampMeta,
        lastReadTimestamp.isAcceptableOrUnknown(
          data['last_read_timestamp']!,
          _lastReadTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastReadTimestampMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  ReadingProgressItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressItem(
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      pageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_index'],
      )!,
      totalPages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_pages'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      readingTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reading_time_seconds'],
      )!,
      lastReadTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_read_timestamp'],
      )!,
    );
  }

  @override
  $ReadingProgressesTable createAlias(String alias) {
    return $ReadingProgressesTable(attachedDatabase, alias);
  }
}

class ReadingProgressItem extends DataClass
    implements Insertable<ReadingProgressItem> {
  /// 书籍 ID（主键）
  final String bookId;

  /// 当前章节 ID
  final int chapterId;

  /// 当前页码
  final int pageIndex;

  /// 总页数
  final int totalPages;

  /// 进度百分比（0.0 - 1.0）
  final double progress;

  /// 已阅读时间（秒）
  final int readingTimeSeconds;

  /// 最后阅读时间戳（Unix 时间戳，秒）
  final int lastReadTimestamp;
  const ReadingProgressItem({
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.totalPages,
    required this.progress,
    required this.readingTimeSeconds,
    required this.lastReadTimestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<int>(chapterId);
    map['page_index'] = Variable<int>(pageIndex);
    map['total_pages'] = Variable<int>(totalPages);
    map['progress'] = Variable<double>(progress);
    map['reading_time_seconds'] = Variable<int>(readingTimeSeconds);
    map['last_read_timestamp'] = Variable<int>(lastReadTimestamp);
    return map;
  }

  ReadingProgressesCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressesCompanion(
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      pageIndex: Value(pageIndex),
      totalPages: Value(totalPages),
      progress: Value(progress),
      readingTimeSeconds: Value(readingTimeSeconds),
      lastReadTimestamp: Value(lastReadTimestamp),
    );
  }

  factory ReadingProgressItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressItem(
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      pageIndex: serializer.fromJson<int>(json['pageIndex']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      progress: serializer.fromJson<double>(json['progress']),
      readingTimeSeconds: serializer.fromJson<int>(json['readingTimeSeconds']),
      lastReadTimestamp: serializer.fromJson<int>(json['lastReadTimestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'chapterId': serializer.toJson<int>(chapterId),
      'pageIndex': serializer.toJson<int>(pageIndex),
      'totalPages': serializer.toJson<int>(totalPages),
      'progress': serializer.toJson<double>(progress),
      'readingTimeSeconds': serializer.toJson<int>(readingTimeSeconds),
      'lastReadTimestamp': serializer.toJson<int>(lastReadTimestamp),
    };
  }

  ReadingProgressItem copyWith({
    String? bookId,
    int? chapterId,
    int? pageIndex,
    int? totalPages,
    double? progress,
    int? readingTimeSeconds,
    int? lastReadTimestamp,
  }) => ReadingProgressItem(
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    pageIndex: pageIndex ?? this.pageIndex,
    totalPages: totalPages ?? this.totalPages,
    progress: progress ?? this.progress,
    readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
    lastReadTimestamp: lastReadTimestamp ?? this.lastReadTimestamp,
  );
  ReadingProgressItem copyWithCompanion(ReadingProgressesCompanion data) {
    return ReadingProgressItem(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      pageIndex: data.pageIndex.present ? data.pageIndex.value : this.pageIndex,
      totalPages: data.totalPages.present
          ? data.totalPages.value
          : this.totalPages,
      progress: data.progress.present ? data.progress.value : this.progress,
      readingTimeSeconds: data.readingTimeSeconds.present
          ? data.readingTimeSeconds.value
          : this.readingTimeSeconds,
      lastReadTimestamp: data.lastReadTimestamp.present
          ? data.lastReadTimestamp.value
          : this.lastReadTimestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressItem(')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('totalPages: $totalPages, ')
          ..write('progress: $progress, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('lastReadTimestamp: $lastReadTimestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    chapterId,
    pageIndex,
    totalPages,
    progress,
    readingTimeSeconds,
    lastReadTimestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressItem &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.pageIndex == this.pageIndex &&
          other.totalPages == this.totalPages &&
          other.progress == this.progress &&
          other.readingTimeSeconds == this.readingTimeSeconds &&
          other.lastReadTimestamp == this.lastReadTimestamp);
}

class ReadingProgressesCompanion extends UpdateCompanion<ReadingProgressItem> {
  final Value<String> bookId;
  final Value<int> chapterId;
  final Value<int> pageIndex;
  final Value<int> totalPages;
  final Value<double> progress;
  final Value<int> readingTimeSeconds;
  final Value<int> lastReadTimestamp;
  final Value<int> rowid;
  const ReadingProgressesCompanion({
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.pageIndex = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.progress = const Value.absent(),
    this.readingTimeSeconds = const Value.absent(),
    this.lastReadTimestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressesCompanion.insert({
    required String bookId,
    required int chapterId,
    required int pageIndex,
    required int totalPages,
    required double progress,
    this.readingTimeSeconds = const Value.absent(),
    required int lastReadTimestamp,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       chapterId = Value(chapterId),
       pageIndex = Value(pageIndex),
       totalPages = Value(totalPages),
       progress = Value(progress),
       lastReadTimestamp = Value(lastReadTimestamp);
  static Insertable<ReadingProgressItem> custom({
    Expression<String>? bookId,
    Expression<int>? chapterId,
    Expression<int>? pageIndex,
    Expression<int>? totalPages,
    Expression<double>? progress,
    Expression<int>? readingTimeSeconds,
    Expression<int>? lastReadTimestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (pageIndex != null) 'page_index': pageIndex,
      if (totalPages != null) 'total_pages': totalPages,
      if (progress != null) 'progress': progress,
      if (readingTimeSeconds != null)
        'reading_time_seconds': readingTimeSeconds,
      if (lastReadTimestamp != null) 'last_read_timestamp': lastReadTimestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressesCompanion copyWith({
    Value<String>? bookId,
    Value<int>? chapterId,
    Value<int>? pageIndex,
    Value<int>? totalPages,
    Value<double>? progress,
    Value<int>? readingTimeSeconds,
    Value<int>? lastReadTimestamp,
    Value<int>? rowid,
  }) {
    return ReadingProgressesCompanion(
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      pageIndex: pageIndex ?? this.pageIndex,
      totalPages: totalPages ?? this.totalPages,
      progress: progress ?? this.progress,
      readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
      lastReadTimestamp: lastReadTimestamp ?? this.lastReadTimestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (pageIndex.present) {
      map['page_index'] = Variable<int>(pageIndex.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (readingTimeSeconds.present) {
      map['reading_time_seconds'] = Variable<int>(readingTimeSeconds.value);
    }
    if (lastReadTimestamp.present) {
      map['last_read_timestamp'] = Variable<int>(lastReadTimestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('pageIndex: $pageIndex, ')
          ..write('totalPages: $totalPages, ')
          ..write('progress: $progress, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('lastReadTimestamp: $lastReadTimestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LayoutCachesTable extends LayoutCaches
    with TableInfo<$LayoutCachesTable, LayoutCacheItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LayoutCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configHashMeta = const VerificationMeta(
    'configHash',
  );
  @override
  late final GeneratedColumn<String> configHash = GeneratedColumn<String>(
    'config_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageOffsetsMeta = const VerificationMeta(
    'pageOffsets',
  );
  @override
  late final GeneratedColumn<String> pageOffsets = GeneratedColumn<String>(
    'page_offsets',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPagesMeta = const VerificationMeta(
    'totalPages',
  );
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
    'total_pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterId,
    configHash,
    pageOffsets,
    totalPages,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'layout_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<LayoutCacheItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('config_hash')) {
      context.handle(
        _configHashMeta,
        configHash.isAcceptableOrUnknown(data['config_hash']!, _configHashMeta),
      );
    } else if (isInserting) {
      context.missing(_configHashMeta);
    }
    if (data.containsKey('page_offsets')) {
      context.handle(
        _pageOffsetsMeta,
        pageOffsets.isAcceptableOrUnknown(
          data['page_offsets']!,
          _pageOffsetsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pageOffsetsMeta);
    }
    if (data.containsKey('total_pages')) {
      context.handle(
        _totalPagesMeta,
        totalPages.isAcceptableOrUnknown(data['total_pages']!, _totalPagesMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPagesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, chapterId, configHash},
  ];
  @override
  LayoutCacheItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LayoutCacheItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      configHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_hash'],
      )!,
      pageOffsets: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_offsets'],
      )!,
      totalPages: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_pages'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LayoutCachesTable createAlias(String alias) {
    return $LayoutCachesTable(attachedDatabase, alias);
  }
}

class LayoutCacheItem extends DataClass implements Insertable<LayoutCacheItem> {
  /// 自增主键
  final int id;

  /// 书籍 ID
  final String bookId;

  /// 章节 ID
  final int chapterId;

  /// 排版配置哈希
  final String configHash;

  /// 页面偏移量列表（JSON 格式）
  final String pageOffsets;

  /// 总页数
  final int totalPages;

  /// 创建时间戳（Unix 时间戳，秒）
  final int createdAt;
  const LayoutCacheItem({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.configHash,
    required this.pageOffsets,
    required this.totalPages,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<int>(chapterId);
    map['config_hash'] = Variable<String>(configHash);
    map['page_offsets'] = Variable<String>(pageOffsets);
    map['total_pages'] = Variable<int>(totalPages);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  LayoutCachesCompanion toCompanion(bool nullToAbsent) {
    return LayoutCachesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      configHash: Value(configHash),
      pageOffsets: Value(pageOffsets),
      totalPages: Value(totalPages),
      createdAt: Value(createdAt),
    );
  }

  factory LayoutCacheItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LayoutCacheItem(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      configHash: serializer.fromJson<String>(json['configHash']),
      pageOffsets: serializer.fromJson<String>(json['pageOffsets']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterId': serializer.toJson<int>(chapterId),
      'configHash': serializer.toJson<String>(configHash),
      'pageOffsets': serializer.toJson<String>(pageOffsets),
      'totalPages': serializer.toJson<int>(totalPages),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  LayoutCacheItem copyWith({
    int? id,
    String? bookId,
    int? chapterId,
    String? configHash,
    String? pageOffsets,
    int? totalPages,
    int? createdAt,
  }) => LayoutCacheItem(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    configHash: configHash ?? this.configHash,
    pageOffsets: pageOffsets ?? this.pageOffsets,
    totalPages: totalPages ?? this.totalPages,
    createdAt: createdAt ?? this.createdAt,
  );
  LayoutCacheItem copyWithCompanion(LayoutCachesCompanion data) {
    return LayoutCacheItem(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      configHash: data.configHash.present
          ? data.configHash.value
          : this.configHash,
      pageOffsets: data.pageOffsets.present
          ? data.pageOffsets.value
          : this.pageOffsets,
      totalPages: data.totalPages.present
          ? data.totalPages.value
          : this.totalPages,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LayoutCacheItem(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('configHash: $configHash, ')
          ..write('pageOffsets: $pageOffsets, ')
          ..write('totalPages: $totalPages, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterId,
    configHash,
    pageOffsets,
    totalPages,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LayoutCacheItem &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.configHash == this.configHash &&
          other.pageOffsets == this.pageOffsets &&
          other.totalPages == this.totalPages &&
          other.createdAt == this.createdAt);
}

class LayoutCachesCompanion extends UpdateCompanion<LayoutCacheItem> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<int> chapterId;
  final Value<String> configHash;
  final Value<String> pageOffsets;
  final Value<int> totalPages;
  final Value<int> createdAt;
  const LayoutCachesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.configHash = const Value.absent(),
    this.pageOffsets = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LayoutCachesCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required int chapterId,
    required String configHash,
    required String pageOffsets,
    required int totalPages,
    required int createdAt,
  }) : bookId = Value(bookId),
       chapterId = Value(chapterId),
       configHash = Value(configHash),
       pageOffsets = Value(pageOffsets),
       totalPages = Value(totalPages),
       createdAt = Value(createdAt);
  static Insertable<LayoutCacheItem> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<int>? chapterId,
    Expression<String>? configHash,
    Expression<String>? pageOffsets,
    Expression<int>? totalPages,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (configHash != null) 'config_hash': configHash,
      if (pageOffsets != null) 'page_offsets': pageOffsets,
      if (totalPages != null) 'total_pages': totalPages,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LayoutCachesCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<int>? chapterId,
    Value<String>? configHash,
    Value<String>? pageOffsets,
    Value<int>? totalPages,
    Value<int>? createdAt,
  }) {
    return LayoutCachesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      configHash: configHash ?? this.configHash,
      pageOffsets: pageOffsets ?? this.pageOffsets,
      totalPages: totalPages ?? this.totalPages,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (configHash.present) {
      map['config_hash'] = Variable<String>(configHash.value);
    }
    if (pageOffsets.present) {
      map['page_offsets'] = Variable<String>(pageOffsets.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LayoutCachesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('configHash: $configHash, ')
          ..write('pageOffsets: $pageOffsets, ')
          ..write('totalPages: $totalPages, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingStatsesTable extends ReadingStatses
    with TableInfo<$ReadingStatsesTable, ReadingStatsItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingStatsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _totalReadingTimeSecondsMeta =
      const VerificationMeta('totalReadingTimeSeconds');
  @override
  late final GeneratedColumn<int> totalReadingTimeSeconds =
      GeneratedColumn<int>(
        'total_reading_time_seconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _totalCharactersReadMeta =
      const VerificationMeta('totalCharactersRead');
  @override
  late final GeneratedColumn<int> totalCharactersRead = GeneratedColumn<int>(
    'total_characters_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _booksReadCountMeta = const VerificationMeta(
    'booksReadCount',
  );
  @override
  late final GeneratedColumn<int> booksReadCount = GeneratedColumn<int>(
    'books_read_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _booksCompletedCountMeta =
      const VerificationMeta('booksCompletedCount');
  @override
  late final GeneratedColumn<int> booksCompletedCount = GeneratedColumn<int>(
    'books_completed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReadDateMeta = const VerificationMeta(
    'lastReadDate',
  );
  @override
  late final GeneratedColumn<String> lastReadDate = GeneratedColumn<String>(
    'last_read_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consecutiveReadingDaysMeta =
      const VerificationMeta('consecutiveReadingDays');
  @override
  late final GeneratedColumn<int> consecutiveReadingDays = GeneratedColumn<int>(
    'consecutive_reading_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    totalReadingTimeSeconds,
    totalCharactersRead,
    booksReadCount,
    booksCompletedCount,
    lastReadDate,
    consecutiveReadingDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_statses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingStatsItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('total_reading_time_seconds')) {
      context.handle(
        _totalReadingTimeSecondsMeta,
        totalReadingTimeSeconds.isAcceptableOrUnknown(
          data['total_reading_time_seconds']!,
          _totalReadingTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('total_characters_read')) {
      context.handle(
        _totalCharactersReadMeta,
        totalCharactersRead.isAcceptableOrUnknown(
          data['total_characters_read']!,
          _totalCharactersReadMeta,
        ),
      );
    }
    if (data.containsKey('books_read_count')) {
      context.handle(
        _booksReadCountMeta,
        booksReadCount.isAcceptableOrUnknown(
          data['books_read_count']!,
          _booksReadCountMeta,
        ),
      );
    }
    if (data.containsKey('books_completed_count')) {
      context.handle(
        _booksCompletedCountMeta,
        booksCompletedCount.isAcceptableOrUnknown(
          data['books_completed_count']!,
          _booksCompletedCountMeta,
        ),
      );
    }
    if (data.containsKey('last_read_date')) {
      context.handle(
        _lastReadDateMeta,
        lastReadDate.isAcceptableOrUnknown(
          data['last_read_date']!,
          _lastReadDateMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_reading_days')) {
      context.handle(
        _consecutiveReadingDaysMeta,
        consecutiveReadingDays.isAcceptableOrUnknown(
          data['consecutive_reading_days']!,
          _consecutiveReadingDaysMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ReadingStatsItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingStatsItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      totalReadingTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_reading_time_seconds'],
      )!,
      totalCharactersRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_characters_read'],
      )!,
      booksReadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}books_read_count'],
      )!,
      booksCompletedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}books_completed_count'],
      )!,
      lastReadDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_read_date'],
      ),
      consecutiveReadingDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_reading_days'],
      )!,
    );
  }

  @override
  $ReadingStatsesTable createAlias(String alias) {
    return $ReadingStatsesTable(attachedDatabase, alias);
  }
}

class ReadingStatsItem extends DataClass
    implements Insertable<ReadingStatsItem> {
  /// 固定 ID = 1
  final int id;

  /// 总阅读时长（秒）
  final int totalReadingTimeSeconds;

  /// 总阅读字数
  final int totalCharactersRead;

  /// 阅读书籍数量
  final int booksReadCount;

  /// 完成阅读书籍数量
  final int booksCompletedCount;

  /// 最后阅读日期（YYYY-MM-DD 格式）
  final String? lastReadDate;

  /// 连续阅读天数
  final int consecutiveReadingDays;
  const ReadingStatsItem({
    required this.id,
    required this.totalReadingTimeSeconds,
    required this.totalCharactersRead,
    required this.booksReadCount,
    required this.booksCompletedCount,
    this.lastReadDate,
    required this.consecutiveReadingDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['total_reading_time_seconds'] = Variable<int>(totalReadingTimeSeconds);
    map['total_characters_read'] = Variable<int>(totalCharactersRead);
    map['books_read_count'] = Variable<int>(booksReadCount);
    map['books_completed_count'] = Variable<int>(booksCompletedCount);
    if (!nullToAbsent || lastReadDate != null) {
      map['last_read_date'] = Variable<String>(lastReadDate);
    }
    map['consecutive_reading_days'] = Variable<int>(consecutiveReadingDays);
    return map;
  }

  ReadingStatsesCompanion toCompanion(bool nullToAbsent) {
    return ReadingStatsesCompanion(
      id: Value(id),
      totalReadingTimeSeconds: Value(totalReadingTimeSeconds),
      totalCharactersRead: Value(totalCharactersRead),
      booksReadCount: Value(booksReadCount),
      booksCompletedCount: Value(booksCompletedCount),
      lastReadDate: lastReadDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReadDate),
      consecutiveReadingDays: Value(consecutiveReadingDays),
    );
  }

  factory ReadingStatsItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingStatsItem(
      id: serializer.fromJson<int>(json['id']),
      totalReadingTimeSeconds: serializer.fromJson<int>(
        json['totalReadingTimeSeconds'],
      ),
      totalCharactersRead: serializer.fromJson<int>(
        json['totalCharactersRead'],
      ),
      booksReadCount: serializer.fromJson<int>(json['booksReadCount']),
      booksCompletedCount: serializer.fromJson<int>(
        json['booksCompletedCount'],
      ),
      lastReadDate: serializer.fromJson<String?>(json['lastReadDate']),
      consecutiveReadingDays: serializer.fromJson<int>(
        json['consecutiveReadingDays'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'totalReadingTimeSeconds': serializer.toJson<int>(
        totalReadingTimeSeconds,
      ),
      'totalCharactersRead': serializer.toJson<int>(totalCharactersRead),
      'booksReadCount': serializer.toJson<int>(booksReadCount),
      'booksCompletedCount': serializer.toJson<int>(booksCompletedCount),
      'lastReadDate': serializer.toJson<String?>(lastReadDate),
      'consecutiveReadingDays': serializer.toJson<int>(consecutiveReadingDays),
    };
  }

  ReadingStatsItem copyWith({
    int? id,
    int? totalReadingTimeSeconds,
    int? totalCharactersRead,
    int? booksReadCount,
    int? booksCompletedCount,
    Value<String?> lastReadDate = const Value.absent(),
    int? consecutiveReadingDays,
  }) => ReadingStatsItem(
    id: id ?? this.id,
    totalReadingTimeSeconds:
        totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
    totalCharactersRead: totalCharactersRead ?? this.totalCharactersRead,
    booksReadCount: booksReadCount ?? this.booksReadCount,
    booksCompletedCount: booksCompletedCount ?? this.booksCompletedCount,
    lastReadDate: lastReadDate.present ? lastReadDate.value : this.lastReadDate,
    consecutiveReadingDays:
        consecutiveReadingDays ?? this.consecutiveReadingDays,
  );
  ReadingStatsItem copyWithCompanion(ReadingStatsesCompanion data) {
    return ReadingStatsItem(
      id: data.id.present ? data.id.value : this.id,
      totalReadingTimeSeconds: data.totalReadingTimeSeconds.present
          ? data.totalReadingTimeSeconds.value
          : this.totalReadingTimeSeconds,
      totalCharactersRead: data.totalCharactersRead.present
          ? data.totalCharactersRead.value
          : this.totalCharactersRead,
      booksReadCount: data.booksReadCount.present
          ? data.booksReadCount.value
          : this.booksReadCount,
      booksCompletedCount: data.booksCompletedCount.present
          ? data.booksCompletedCount.value
          : this.booksCompletedCount,
      lastReadDate: data.lastReadDate.present
          ? data.lastReadDate.value
          : this.lastReadDate,
      consecutiveReadingDays: data.consecutiveReadingDays.present
          ? data.consecutiveReadingDays.value
          : this.consecutiveReadingDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingStatsItem(')
          ..write('id: $id, ')
          ..write('totalReadingTimeSeconds: $totalReadingTimeSeconds, ')
          ..write('totalCharactersRead: $totalCharactersRead, ')
          ..write('booksReadCount: $booksReadCount, ')
          ..write('booksCompletedCount: $booksCompletedCount, ')
          ..write('lastReadDate: $lastReadDate, ')
          ..write('consecutiveReadingDays: $consecutiveReadingDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    totalReadingTimeSeconds,
    totalCharactersRead,
    booksReadCount,
    booksCompletedCount,
    lastReadDate,
    consecutiveReadingDays,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingStatsItem &&
          other.id == this.id &&
          other.totalReadingTimeSeconds == this.totalReadingTimeSeconds &&
          other.totalCharactersRead == this.totalCharactersRead &&
          other.booksReadCount == this.booksReadCount &&
          other.booksCompletedCount == this.booksCompletedCount &&
          other.lastReadDate == this.lastReadDate &&
          other.consecutiveReadingDays == this.consecutiveReadingDays);
}

class ReadingStatsesCompanion extends UpdateCompanion<ReadingStatsItem> {
  final Value<int> id;
  final Value<int> totalReadingTimeSeconds;
  final Value<int> totalCharactersRead;
  final Value<int> booksReadCount;
  final Value<int> booksCompletedCount;
  final Value<String?> lastReadDate;
  final Value<int> consecutiveReadingDays;
  final Value<int> rowid;
  const ReadingStatsesCompanion({
    this.id = const Value.absent(),
    this.totalReadingTimeSeconds = const Value.absent(),
    this.totalCharactersRead = const Value.absent(),
    this.booksReadCount = const Value.absent(),
    this.booksCompletedCount = const Value.absent(),
    this.lastReadDate = const Value.absent(),
    this.consecutiveReadingDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingStatsesCompanion.insert({
    this.id = const Value.absent(),
    this.totalReadingTimeSeconds = const Value.absent(),
    this.totalCharactersRead = const Value.absent(),
    this.booksReadCount = const Value.absent(),
    this.booksCompletedCount = const Value.absent(),
    this.lastReadDate = const Value.absent(),
    this.consecutiveReadingDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<ReadingStatsItem> custom({
    Expression<int>? id,
    Expression<int>? totalReadingTimeSeconds,
    Expression<int>? totalCharactersRead,
    Expression<int>? booksReadCount,
    Expression<int>? booksCompletedCount,
    Expression<String>? lastReadDate,
    Expression<int>? consecutiveReadingDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (totalReadingTimeSeconds != null)
        'total_reading_time_seconds': totalReadingTimeSeconds,
      if (totalCharactersRead != null)
        'total_characters_read': totalCharactersRead,
      if (booksReadCount != null) 'books_read_count': booksReadCount,
      if (booksCompletedCount != null)
        'books_completed_count': booksCompletedCount,
      if (lastReadDate != null) 'last_read_date': lastReadDate,
      if (consecutiveReadingDays != null)
        'consecutive_reading_days': consecutiveReadingDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingStatsesCompanion copyWith({
    Value<int>? id,
    Value<int>? totalReadingTimeSeconds,
    Value<int>? totalCharactersRead,
    Value<int>? booksReadCount,
    Value<int>? booksCompletedCount,
    Value<String?>? lastReadDate,
    Value<int>? consecutiveReadingDays,
    Value<int>? rowid,
  }) {
    return ReadingStatsesCompanion(
      id: id ?? this.id,
      totalReadingTimeSeconds:
          totalReadingTimeSeconds ?? this.totalReadingTimeSeconds,
      totalCharactersRead: totalCharactersRead ?? this.totalCharactersRead,
      booksReadCount: booksReadCount ?? this.booksReadCount,
      booksCompletedCount: booksCompletedCount ?? this.booksCompletedCount,
      lastReadDate: lastReadDate ?? this.lastReadDate,
      consecutiveReadingDays:
          consecutiveReadingDays ?? this.consecutiveReadingDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (totalReadingTimeSeconds.present) {
      map['total_reading_time_seconds'] = Variable<int>(
        totalReadingTimeSeconds.value,
      );
    }
    if (totalCharactersRead.present) {
      map['total_characters_read'] = Variable<int>(totalCharactersRead.value);
    }
    if (booksReadCount.present) {
      map['books_read_count'] = Variable<int>(booksReadCount.value);
    }
    if (booksCompletedCount.present) {
      map['books_completed_count'] = Variable<int>(booksCompletedCount.value);
    }
    if (lastReadDate.present) {
      map['last_read_date'] = Variable<String>(lastReadDate.value);
    }
    if (consecutiveReadingDays.present) {
      map['consecutive_reading_days'] = Variable<int>(
        consecutiveReadingDays.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingStatsesCompanion(')
          ..write('id: $id, ')
          ..write('totalReadingTimeSeconds: $totalReadingTimeSeconds, ')
          ..write('totalCharactersRead: $totalCharactersRead, ')
          ..write('booksReadCount: $booksReadCount, ')
          ..write('booksCompletedCount: $booksCompletedCount, ')
          ..write('lastReadDate: $lastReadDate, ')
          ..write('consecutiveReadingDays: $consecutiveReadingDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyReadingRecordsTable extends DailyReadingRecords
    with TableInfo<$DailyReadingRecordsTable, DailyReadingRecordItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyReadingRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingTimeSecondsMeta =
      const VerificationMeta('readingTimeSeconds');
  @override
  late final GeneratedColumn<int> readingTimeSeconds = GeneratedColumn<int>(
    'reading_time_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _charactersReadMeta = const VerificationMeta(
    'charactersRead',
  );
  @override
  late final GeneratedColumn<int> charactersRead = GeneratedColumn<int>(
    'characters_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _chaptersReadMeta = const VerificationMeta(
    'chaptersRead',
  );
  @override
  late final GeneratedColumn<int> chaptersRead = GeneratedColumn<int>(
    'chapters_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagesReadMeta = const VerificationMeta(
    'pagesRead',
  );
  @override
  late final GeneratedColumn<int> pagesRead = GeneratedColumn<int>(
    'pages_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    date,
    readingTimeSeconds,
    charactersRead,
    chaptersRead,
    pagesRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_reading_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyReadingRecordItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('reading_time_seconds')) {
      context.handle(
        _readingTimeSecondsMeta,
        readingTimeSeconds.isAcceptableOrUnknown(
          data['reading_time_seconds']!,
          _readingTimeSecondsMeta,
        ),
      );
    }
    if (data.containsKey('characters_read')) {
      context.handle(
        _charactersReadMeta,
        charactersRead.isAcceptableOrUnknown(
          data['characters_read']!,
          _charactersReadMeta,
        ),
      );
    }
    if (data.containsKey('chapters_read')) {
      context.handle(
        _chaptersReadMeta,
        chaptersRead.isAcceptableOrUnknown(
          data['chapters_read']!,
          _chaptersReadMeta,
        ),
      );
    }
    if (data.containsKey('pages_read')) {
      context.handle(
        _pagesReadMeta,
        pagesRead.isAcceptableOrUnknown(data['pages_read']!, _pagesReadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {date};
  @override
  DailyReadingRecordItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyReadingRecordItem(
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      readingTimeSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reading_time_seconds'],
      )!,
      charactersRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}characters_read'],
      )!,
      chaptersRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapters_read'],
      )!,
      pagesRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pages_read'],
      )!,
    );
  }

  @override
  $DailyReadingRecordsTable createAlias(String alias) {
    return $DailyReadingRecordsTable(attachedDatabase, alias);
  }
}

class DailyReadingRecordItem extends DataClass
    implements Insertable<DailyReadingRecordItem> {
  /// 日期（YYYY-MM-DD 格式，主键）
  final String date;

  /// 阅读时长（秒）
  final int readingTimeSeconds;

  /// 阅读字数
  final int charactersRead;

  /// 阅读章节数
  final int chaptersRead;

  /// 阅读页数
  final int pagesRead;
  const DailyReadingRecordItem({
    required this.date,
    required this.readingTimeSeconds,
    required this.charactersRead,
    required this.chaptersRead,
    required this.pagesRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date'] = Variable<String>(date);
    map['reading_time_seconds'] = Variable<int>(readingTimeSeconds);
    map['characters_read'] = Variable<int>(charactersRead);
    map['chapters_read'] = Variable<int>(chaptersRead);
    map['pages_read'] = Variable<int>(pagesRead);
    return map;
  }

  DailyReadingRecordsCompanion toCompanion(bool nullToAbsent) {
    return DailyReadingRecordsCompanion(
      date: Value(date),
      readingTimeSeconds: Value(readingTimeSeconds),
      charactersRead: Value(charactersRead),
      chaptersRead: Value(chaptersRead),
      pagesRead: Value(pagesRead),
    );
  }

  factory DailyReadingRecordItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyReadingRecordItem(
      date: serializer.fromJson<String>(json['date']),
      readingTimeSeconds: serializer.fromJson<int>(json['readingTimeSeconds']),
      charactersRead: serializer.fromJson<int>(json['charactersRead']),
      chaptersRead: serializer.fromJson<int>(json['chaptersRead']),
      pagesRead: serializer.fromJson<int>(json['pagesRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'date': serializer.toJson<String>(date),
      'readingTimeSeconds': serializer.toJson<int>(readingTimeSeconds),
      'charactersRead': serializer.toJson<int>(charactersRead),
      'chaptersRead': serializer.toJson<int>(chaptersRead),
      'pagesRead': serializer.toJson<int>(pagesRead),
    };
  }

  DailyReadingRecordItem copyWith({
    String? date,
    int? readingTimeSeconds,
    int? charactersRead,
    int? chaptersRead,
    int? pagesRead,
  }) => DailyReadingRecordItem(
    date: date ?? this.date,
    readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
    charactersRead: charactersRead ?? this.charactersRead,
    chaptersRead: chaptersRead ?? this.chaptersRead,
    pagesRead: pagesRead ?? this.pagesRead,
  );
  DailyReadingRecordItem copyWithCompanion(DailyReadingRecordsCompanion data) {
    return DailyReadingRecordItem(
      date: data.date.present ? data.date.value : this.date,
      readingTimeSeconds: data.readingTimeSeconds.present
          ? data.readingTimeSeconds.value
          : this.readingTimeSeconds,
      charactersRead: data.charactersRead.present
          ? data.charactersRead.value
          : this.charactersRead,
      chaptersRead: data.chaptersRead.present
          ? data.chaptersRead.value
          : this.chaptersRead,
      pagesRead: data.pagesRead.present ? data.pagesRead.value : this.pagesRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyReadingRecordItem(')
          ..write('date: $date, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('charactersRead: $charactersRead, ')
          ..write('chaptersRead: $chaptersRead, ')
          ..write('pagesRead: $pagesRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    date,
    readingTimeSeconds,
    charactersRead,
    chaptersRead,
    pagesRead,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyReadingRecordItem &&
          other.date == this.date &&
          other.readingTimeSeconds == this.readingTimeSeconds &&
          other.charactersRead == this.charactersRead &&
          other.chaptersRead == this.chaptersRead &&
          other.pagesRead == this.pagesRead);
}

class DailyReadingRecordsCompanion
    extends UpdateCompanion<DailyReadingRecordItem> {
  final Value<String> date;
  final Value<int> readingTimeSeconds;
  final Value<int> charactersRead;
  final Value<int> chaptersRead;
  final Value<int> pagesRead;
  final Value<int> rowid;
  const DailyReadingRecordsCompanion({
    this.date = const Value.absent(),
    this.readingTimeSeconds = const Value.absent(),
    this.charactersRead = const Value.absent(),
    this.chaptersRead = const Value.absent(),
    this.pagesRead = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyReadingRecordsCompanion.insert({
    required String date,
    this.readingTimeSeconds = const Value.absent(),
    this.charactersRead = const Value.absent(),
    this.chaptersRead = const Value.absent(),
    this.pagesRead = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : date = Value(date);
  static Insertable<DailyReadingRecordItem> custom({
    Expression<String>? date,
    Expression<int>? readingTimeSeconds,
    Expression<int>? charactersRead,
    Expression<int>? chaptersRead,
    Expression<int>? pagesRead,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (date != null) 'date': date,
      if (readingTimeSeconds != null)
        'reading_time_seconds': readingTimeSeconds,
      if (charactersRead != null) 'characters_read': charactersRead,
      if (chaptersRead != null) 'chapters_read': chaptersRead,
      if (pagesRead != null) 'pages_read': pagesRead,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyReadingRecordsCompanion copyWith({
    Value<String>? date,
    Value<int>? readingTimeSeconds,
    Value<int>? charactersRead,
    Value<int>? chaptersRead,
    Value<int>? pagesRead,
    Value<int>? rowid,
  }) {
    return DailyReadingRecordsCompanion(
      date: date ?? this.date,
      readingTimeSeconds: readingTimeSeconds ?? this.readingTimeSeconds,
      charactersRead: charactersRead ?? this.charactersRead,
      chaptersRead: chaptersRead ?? this.chaptersRead,
      pagesRead: pagesRead ?? this.pagesRead,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (readingTimeSeconds.present) {
      map['reading_time_seconds'] = Variable<int>(readingTimeSeconds.value);
    }
    if (charactersRead.present) {
      map['characters_read'] = Variable<int>(charactersRead.value);
    }
    if (chaptersRead.present) {
      map['chapters_read'] = Variable<int>(chaptersRead.value);
    }
    if (pagesRead.present) {
      map['pages_read'] = Variable<int>(pagesRead.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyReadingRecordsCompanion(')
          ..write('date: $date, ')
          ..write('readingTimeSeconds: $readingTimeSeconds, ')
          ..write('charactersRead: $charactersRead, ')
          ..write('chaptersRead: $chaptersRead, ')
          ..write('pagesRead: $pagesRead, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingSessionsTable extends ReadingSessions
    with TableInfo<$ReadingSessionsTable, ReadingSessionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<int> chapterId = GeneratedColumn<int>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimestampMeta = const VerificationMeta(
    'startTimestamp',
  );
  @override
  late final GeneratedColumn<int> startTimestamp = GeneratedColumn<int>(
    'start_timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimestampMeta = const VerificationMeta(
    'endTimestamp',
  );
  @override
  late final GeneratedColumn<int> endTimestamp = GeneratedColumn<int>(
    'end_timestamp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _charactersReadMeta = const VerificationMeta(
    'charactersRead',
  );
  @override
  late final GeneratedColumn<int> charactersRead = GeneratedColumn<int>(
    'characters_read',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    bookId,
    chapterId,
    startTimestamp,
    endTimestamp,
    durationSeconds,
    charactersRead,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingSessionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('start_timestamp')) {
      context.handle(
        _startTimestampMeta,
        startTimestamp.isAcceptableOrUnknown(
          data['start_timestamp']!,
          _startTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startTimestampMeta);
    }
    if (data.containsKey('end_timestamp')) {
      context.handle(
        _endTimestampMeta,
        endTimestamp.isAcceptableOrUnknown(
          data['end_timestamp']!,
          _endTimestampMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endTimestampMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('characters_read')) {
      context.handle(
        _charactersReadMeta,
        charactersRead.isAcceptableOrUnknown(
          data['characters_read']!,
          _charactersReadMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  ReadingSessionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingSessionItem(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_id'],
      )!,
      startTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_timestamp'],
      )!,
      endTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_timestamp'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      charactersRead: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}characters_read'],
      )!,
    );
  }

  @override
  $ReadingSessionsTable createAlias(String alias) {
    return $ReadingSessionsTable(attachedDatabase, alias);
  }
}

class ReadingSessionItem extends DataClass
    implements Insertable<ReadingSessionItem> {
  /// 会话 ID（UUID）
  final String sessionId;

  /// 书籍 ID
  final String bookId;

  /// 章节 ID
  final int chapterId;

  /// 开始时间戳（Unix 时间戳，秒）
  final int startTimestamp;

  /// 结束时间戳（Unix 时间戳，秒）
  final int endTimestamp;

  /// 阅读时长（秒）
  final int durationSeconds;

  /// 阅读字数
  final int charactersRead;
  const ReadingSessionItem({
    required this.sessionId,
    required this.bookId,
    required this.chapterId,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.durationSeconds,
    required this.charactersRead,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<int>(chapterId);
    map['start_timestamp'] = Variable<int>(startTimestamp);
    map['end_timestamp'] = Variable<int>(endTimestamp);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['characters_read'] = Variable<int>(charactersRead);
    return map;
  }

  ReadingSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingSessionsCompanion(
      sessionId: Value(sessionId),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      startTimestamp: Value(startTimestamp),
      endTimestamp: Value(endTimestamp),
      durationSeconds: Value(durationSeconds),
      charactersRead: Value(charactersRead),
    );
  }

  factory ReadingSessionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingSessionItem(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<int>(json['chapterId']),
      startTimestamp: serializer.fromJson<int>(json['startTimestamp']),
      endTimestamp: serializer.fromJson<int>(json['endTimestamp']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      charactersRead: serializer.fromJson<int>(json['charactersRead']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'bookId': serializer.toJson<String>(bookId),
      'chapterId': serializer.toJson<int>(chapterId),
      'startTimestamp': serializer.toJson<int>(startTimestamp),
      'endTimestamp': serializer.toJson<int>(endTimestamp),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'charactersRead': serializer.toJson<int>(charactersRead),
    };
  }

  ReadingSessionItem copyWith({
    String? sessionId,
    String? bookId,
    int? chapterId,
    int? startTimestamp,
    int? endTimestamp,
    int? durationSeconds,
    int? charactersRead,
  }) => ReadingSessionItem(
    sessionId: sessionId ?? this.sessionId,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    startTimestamp: startTimestamp ?? this.startTimestamp,
    endTimestamp: endTimestamp ?? this.endTimestamp,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    charactersRead: charactersRead ?? this.charactersRead,
  );
  ReadingSessionItem copyWithCompanion(ReadingSessionsCompanion data) {
    return ReadingSessionItem(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      startTimestamp: data.startTimestamp.present
          ? data.startTimestamp.value
          : this.startTimestamp,
      endTimestamp: data.endTimestamp.present
          ? data.endTimestamp.value
          : this.endTimestamp,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      charactersRead: data.charactersRead.present
          ? data.charactersRead.value
          : this.charactersRead,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionItem(')
          ..write('sessionId: $sessionId, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('startTimestamp: $startTimestamp, ')
          ..write('endTimestamp: $endTimestamp, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('charactersRead: $charactersRead')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    bookId,
    chapterId,
    startTimestamp,
    endTimestamp,
    durationSeconds,
    charactersRead,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingSessionItem &&
          other.sessionId == this.sessionId &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.startTimestamp == this.startTimestamp &&
          other.endTimestamp == this.endTimestamp &&
          other.durationSeconds == this.durationSeconds &&
          other.charactersRead == this.charactersRead);
}

class ReadingSessionsCompanion extends UpdateCompanion<ReadingSessionItem> {
  final Value<String> sessionId;
  final Value<String> bookId;
  final Value<int> chapterId;
  final Value<int> startTimestamp;
  final Value<int> endTimestamp;
  final Value<int> durationSeconds;
  final Value<int> charactersRead;
  final Value<int> rowid;
  const ReadingSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.startTimestamp = const Value.absent(),
    this.endTimestamp = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.charactersRead = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingSessionsCompanion.insert({
    required String sessionId,
    required String bookId,
    required int chapterId,
    required int startTimestamp,
    required int endTimestamp,
    required int durationSeconds,
    this.charactersRead = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       startTimestamp = Value(startTimestamp),
       endTimestamp = Value(endTimestamp),
       durationSeconds = Value(durationSeconds);
  static Insertable<ReadingSessionItem> custom({
    Expression<String>? sessionId,
    Expression<String>? bookId,
    Expression<int>? chapterId,
    Expression<int>? startTimestamp,
    Expression<int>? endTimestamp,
    Expression<int>? durationSeconds,
    Expression<int>? charactersRead,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (startTimestamp != null) 'start_timestamp': startTimestamp,
      if (endTimestamp != null) 'end_timestamp': endTimestamp,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (charactersRead != null) 'characters_read': charactersRead,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingSessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? bookId,
    Value<int>? chapterId,
    Value<int>? startTimestamp,
    Value<int>? endTimestamp,
    Value<int>? durationSeconds,
    Value<int>? charactersRead,
    Value<int>? rowid,
  }) {
    return ReadingSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      charactersRead: charactersRead ?? this.charactersRead,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<int>(chapterId.value);
    }
    if (startTimestamp.present) {
      map['start_timestamp'] = Variable<int>(startTimestamp.value);
    }
    if (endTimestamp.present) {
      map['end_timestamp'] = Variable<int>(endTimestamp.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (charactersRead.present) {
      map['characters_read'] = Variable<int>(charactersRead.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('startTimestamp: $startTimestamp, ')
          ..write('endTimestamp: $endTimestamp, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('charactersRead: $charactersRead, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ChaptersTable chapters = $ChaptersTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ReadingHistoriesTable readingHistories = $ReadingHistoriesTable(
    this,
  );
  late final $ReadingProgressesTable readingProgresses =
      $ReadingProgressesTable(this);
  late final $LayoutCachesTable layoutCaches = $LayoutCachesTable(this);
  late final $ReadingStatsesTable readingStatses = $ReadingStatsesTable(this);
  late final $DailyReadingRecordsTable dailyReadingRecords =
      $DailyReadingRecordsTable(this);
  late final $ReadingSessionsTable readingSessions = $ReadingSessionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    books,
    chapters,
    bookmarks,
    readingHistories,
    readingProgresses,
    layoutCaches,
    readingStatses,
    dailyReadingRecords,
    readingSessions,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chapters', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('bookmarks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'books',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_histories', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chapters',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_histories', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$BooksTableCreateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      required String title,
      required String author,
      Value<String?> coverPath,
      Value<String?> description,
      required String filePath,
      required String fileFormat,
      Value<int> fileSize,
      Value<int> totalChapters,
      Value<int> totalCharacters,
      Value<int?> currentChapterId,
      Value<int> currentPageIndex,
      Value<int> totalPages,
      Value<double> progress,
      Value<String> status,
      Value<bool> isPinned,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastReadAt,
    });
typedef $$BooksTableUpdateCompanionBuilder =
    BooksCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> author,
      Value<String?> coverPath,
      Value<String?> description,
      Value<String> filePath,
      Value<String> fileFormat,
      Value<int> fileSize,
      Value<int> totalChapters,
      Value<int> totalCharacters,
      Value<int?> currentChapterId,
      Value<int> currentPageIndex,
      Value<int> totalPages,
      Value<double> progress,
      Value<String> status,
      Value<bool> isPinned,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastReadAt,
    });

final class $$BooksTableReferences
    extends BaseReferences<_$AppDatabase, $BooksTable, Book> {
  $$BooksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ChaptersTable, List<Chapter>> _chaptersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.chapters,
    aliasName: $_aliasNameGenerator(db.books.id, db.chapters.bookId),
  );

  $$ChaptersTableProcessedTableManager get chaptersRefs {
    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_chaptersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
  _bookmarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(db.books.id, db.bookmarks.bookId),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingHistoriesTable, List<ReadingHistory>>
  _readingHistoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readingHistories,
    aliasName: $_aliasNameGenerator(db.books.id, db.readingHistories.bookId),
  );

  $$ReadingHistoriesTableProcessedTableManager get readingHistoriesRefs {
    final manager = $$ReadingHistoriesTableTableManager(
      $_db,
      $_db.readingHistories,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingHistoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCharacters => $composableBuilder(
    column: $table.totalCharacters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPageIndex => $composableBuilder(
    column: $table.currentPageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> chaptersRefs(
    Expression<bool> Function($$ChaptersTableFilterComposer f) f,
  ) {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingHistoriesRefs(
    Expression<bool> Function($$ReadingHistoriesTableFilterComposer f) f,
  ) {
    final $$ReadingHistoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingHistories,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingHistoriesTableFilterComposer(
            $db: $db,
            $table: $db.readingHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCharacters => $composableBuilder(
    column: $table.totalCharacters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPageIndex => $composableBuilder(
    column: $table.currentPageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get fileFormat => $composableBuilder(
    column: $table.fileFormat,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCharacters => $composableBuilder(
    column: $table.totalCharacters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentChapterId => $composableBuilder(
    column: $table.currentChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentPageIndex => $composableBuilder(
    column: $table.currentPageIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );

  Expression<T> chaptersRefs<T extends Object>(
    Expression<T> Function($$ChaptersTableAnnotationComposer a) f,
  ) {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingHistoriesRefs<T extends Object>(
    Expression<T> Function($$ReadingHistoriesTableAnnotationComposer a) f,
  ) {
    final $$ReadingHistoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingHistories,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingHistoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.readingHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, $$BooksTableReferences),
          Book,
          PrefetchHooks Function({
            bool chaptersRefs,
            bool bookmarksRefs,
            bool readingHistoriesRefs,
          })
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> fileFormat = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<int> totalCharacters = const Value.absent(),
                Value<int?> currentChapterId = const Value.absent(),
                Value<int> currentPageIndex = const Value.absent(),
                Value<int> totalPages = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                author: author,
                coverPath: coverPath,
                description: description,
                filePath: filePath,
                fileFormat: fileFormat,
                fileSize: fileSize,
                totalChapters: totalChapters,
                totalCharacters: totalCharacters,
                currentChapterId: currentChapterId,
                currentPageIndex: currentPageIndex,
                totalPages: totalPages,
                progress: progress,
                status: status,
                isPinned: isPinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastReadAt: lastReadAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String author,
                Value<String?> coverPath = const Value.absent(),
                Value<String?> description = const Value.absent(),
                required String filePath,
                required String fileFormat,
                Value<int> fileSize = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<int> totalCharacters = const Value.absent(),
                Value<int?> currentChapterId = const Value.absent(),
                Value<int> currentPageIndex = const Value.absent(),
                Value<int> totalPages = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastReadAt = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                author: author,
                coverPath: coverPath,
                description: description,
                filePath: filePath,
                fileFormat: fileFormat,
                fileSize: fileSize,
                totalChapters: totalChapters,
                totalCharacters: totalCharacters,
                currentChapterId: currentChapterId,
                currentPageIndex: currentPageIndex,
                totalPages: totalPages,
                progress: progress,
                status: status,
                isPinned: isPinned,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastReadAt: lastReadAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$BooksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                chaptersRefs = false,
                bookmarksRefs = false,
                readingHistoriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (chaptersRefs) db.chapters,
                    if (bookmarksRefs) db.bookmarks,
                    if (readingHistoriesRefs) db.readingHistories,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (chaptersRefs)
                        await $_getPrefetchedData<Book, $BooksTable, Chapter>(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._chaptersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).chaptersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<Book, $BooksTable, Bookmark>(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingHistoriesRefs)
                        await $_getPrefetchedData<
                          Book,
                          $BooksTable,
                          ReadingHistory
                        >(
                          currentTable: table,
                          referencedTable: $$BooksTableReferences
                              ._readingHistoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BooksTableReferences(
                                db,
                                table,
                                p0,
                              ).readingHistoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, $$BooksTableReferences),
      Book,
      PrefetchHooks Function({
        bool chaptersRefs,
        bool bookmarksRefs,
        bool readingHistoriesRefs,
      })
    >;
typedef $$ChaptersTableCreateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      required int bookId,
      required String title,
      required String contentFile,
      required int chapterIndex,
      Value<int> wordCount,
      Value<DateTime> cachedAt,
    });
typedef $$ChaptersTableUpdateCompanionBuilder =
    ChaptersCompanion Function({
      Value<int> id,
      Value<int> bookId,
      Value<String> title,
      Value<String> contentFile,
      Value<int> chapterIndex,
      Value<int> wordCount,
      Value<DateTime> cachedAt,
    });

final class $$ChaptersTableReferences
    extends BaseReferences<_$AppDatabase, $ChaptersTable, Chapter> {
  $$ChaptersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.chapters.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReadingHistoriesTable, List<ReadingHistory>>
  _readingHistoriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readingHistories,
    aliasName: $_aliasNameGenerator(
      db.chapters.id,
      db.readingHistories.chapterId,
    ),
  );

  $$ReadingHistoriesTableProcessedTableManager get readingHistoriesRefs {
    final manager = $$ReadingHistoriesTableTableManager(
      $_db,
      $_db.readingHistories,
    ).filter((f) => f.chapterId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingHistoriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentFile => $composableBuilder(
    column: $table.contentFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> readingHistoriesRefs(
    Expression<bool> Function($$ReadingHistoriesTableFilterComposer f) f,
  ) {
    final $$ReadingHistoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingHistories,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingHistoriesTableFilterComposer(
            $db: $db,
            $table: $db.readingHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentFile => $composableBuilder(
    column: $table.contentFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wordCount => $composableBuilder(
    column: $table.wordCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChaptersTable> {
  $$ChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get contentFile => $composableBuilder(
    column: $table.contentFile,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wordCount =>
      $composableBuilder(column: $table.wordCount, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> readingHistoriesRefs<T extends Object>(
    Expression<T> Function($$ReadingHistoriesTableAnnotationComposer a) f,
  ) {
    final $$ReadingHistoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingHistories,
      getReferencedColumn: (t) => t.chapterId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingHistoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.readingHistories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChaptersTable,
          Chapter,
          $$ChaptersTableFilterComposer,
          $$ChaptersTableOrderingComposer,
          $$ChaptersTableAnnotationComposer,
          $$ChaptersTableCreateCompanionBuilder,
          $$ChaptersTableUpdateCompanionBuilder,
          (Chapter, $$ChaptersTableReferences),
          Chapter,
          PrefetchHooks Function({bool bookId, bool readingHistoriesRefs})
        > {
  $$ChaptersTableTableManager(_$AppDatabase db, $ChaptersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChaptersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChaptersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChaptersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> contentFile = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> wordCount = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => ChaptersCompanion(
                id: id,
                bookId: bookId,
                title: title,
                contentFile: contentFile,
                chapterIndex: chapterIndex,
                wordCount: wordCount,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bookId,
                required String title,
                required String contentFile,
                required int chapterIndex,
                Value<int> wordCount = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => ChaptersCompanion.insert(
                id: id,
                bookId: bookId,
                title: title,
                contentFile: contentFile,
                chapterIndex: chapterIndex,
                wordCount: wordCount,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ChaptersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({bookId = false, readingHistoriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (readingHistoriesRefs) db.readingHistories,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (bookId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.bookId,
                                    referencedTable: $$ChaptersTableReferences
                                        ._bookIdTable(db),
                                    referencedColumn: $$ChaptersTableReferences
                                        ._bookIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (readingHistoriesRefs)
                        await $_getPrefetchedData<
                          Chapter,
                          $ChaptersTable,
                          ReadingHistory
                        >(
                          currentTable: table,
                          referencedTable: $$ChaptersTableReferences
                              ._readingHistoriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ChaptersTableReferences(
                                db,
                                table,
                                p0,
                              ).readingHistoriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.chapterId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChaptersTable,
      Chapter,
      $$ChaptersTableFilterComposer,
      $$ChaptersTableOrderingComposer,
      $$ChaptersTableAnnotationComposer,
      $$ChaptersTableCreateCompanionBuilder,
      $$ChaptersTableUpdateCompanionBuilder,
      (Chapter, $$ChaptersTableReferences),
      Chapter,
      PrefetchHooks Function({bool bookId, bool readingHistoriesRefs})
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String bookmarkId,
      required int bookId,
      required int chapterId,
      required int pageIndex,
      required String title,
      required int createdTimestamp,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> bookmarkId,
      Value<int> bookId,
      Value<int> chapterId,
      Value<int> pageIndex,
      Value<String> title,
      Value<int> createdTimestamp,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$BookmarksTableReferences
    extends BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.bookmarks.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookmarkId => $composableBuilder(
    column: $table.bookmarkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdTimestamp => $composableBuilder(
    column: $table.createdTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookmarkId => $composableBuilder(
    column: $table.bookmarkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdTimestamp => $composableBuilder(
    column: $table.createdTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookmarkId => $composableBuilder(
    column: $table.bookmarkId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get createdTimestamp => $composableBuilder(
    column: $table.createdTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, $$BookmarksTableReferences),
          Bookmark,
          PrefetchHooks Function({bool bookId})
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> bookmarkId = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> createdTimestamp = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                bookmarkId: bookmarkId,
                bookId: bookId,
                chapterId: chapterId,
                pageIndex: pageIndex,
                title: title,
                createdTimestamp: createdTimestamp,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookmarkId,
                required int bookId,
                required int chapterId,
                required int pageIndex,
                required String title,
                int position,
                required int createdTimestamp,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                bookmarkId: bookmarkId,
                bookId: bookId,
                chapterId: chapterId,
                pageIndex: pageIndex,
                title: title,
                createdTimestamp: createdTimestamp,
                note: note,
                rowid: rowid,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookmarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable: $$BookmarksTableReferences
                                    ._bookIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._bookIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, $$BookmarksTableReferences),
      Bookmark,
      PrefetchHooks Function({bool bookId})
    >;
typedef $$ReadingHistoriesTableCreateCompanionBuilder =
    ReadingHistoriesCompanion Function({
      Value<int> id,
      required int bookId,
      required int chapterId,
      required int position,
      Value<DateTime> readTime,
      Value<int> duration,
    });
typedef $$ReadingHistoriesTableUpdateCompanionBuilder =
    ReadingHistoriesCompanion Function({
      Value<int> id,
      Value<int> bookId,
      Value<int> chapterId,
      Value<int> position,
      Value<DateTime> readTime,
      Value<int> duration,
    });

final class $$ReadingHistoriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $ReadingHistoriesTable, ReadingHistory> {
  $$ReadingHistoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BooksTable _bookIdTable(_$AppDatabase db) => db.books.createAlias(
    $_aliasNameGenerator(db.readingHistories.bookId, db.books.id),
  );

  $$BooksTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<int>('book_id')!;

    final manager = $$BooksTableTableManager(
      $_db,
      $_db.books,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ChaptersTable _chapterIdTable(_$AppDatabase db) =>
      db.chapters.createAlias(
        $_aliasNameGenerator(db.readingHistories.chapterId, db.chapters.id),
      );

  $$ChaptersTableProcessedTableManager get chapterId {
    final $_column = $_itemColumn<int>('chapter_id')!;

    final manager = $$ChaptersTableTableManager(
      $_db,
      $_db.chapters,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chapterIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingHistoriesTable> {
  $$ReadingHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readTime => $composableBuilder(
    column: $table.readTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  $$BooksTableFilterComposer get bookId {
    final $$BooksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableFilterComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableFilterComposer get chapterId {
    final $$ChaptersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableFilterComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingHistoriesTable> {
  $$ReadingHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readTime => $composableBuilder(
    column: $table.readTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  $$BooksTableOrderingComposer get bookId {
    final $$BooksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableOrderingComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableOrderingComposer get chapterId {
    final $$ChaptersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableOrderingComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingHistoriesTable> {
  $$ReadingHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get readTime =>
      $composableBuilder(column: $table.readTime, builder: (column) => column);

  GeneratedColumn<int> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  $$BooksTableAnnotationComposer get bookId {
    final $$BooksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.books,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BooksTableAnnotationComposer(
            $db: $db,
            $table: $db.books,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ChaptersTableAnnotationComposer get chapterId {
    final $$ChaptersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chapterId,
      referencedTable: $db.chapters,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChaptersTableAnnotationComposer(
            $db: $db,
            $table: $db.chapters,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingHistoriesTable,
          ReadingHistory,
          $$ReadingHistoriesTableFilterComposer,
          $$ReadingHistoriesTableOrderingComposer,
          $$ReadingHistoriesTableAnnotationComposer,
          $$ReadingHistoriesTableCreateCompanionBuilder,
          $$ReadingHistoriesTableUpdateCompanionBuilder,
          (ReadingHistory, $$ReadingHistoriesTableReferences),
          ReadingHistory,
          PrefetchHooks Function({bool bookId, bool chapterId})
        > {
  $$ReadingHistoriesTableTableManager(
    _$AppDatabase db,
    $ReadingHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> bookId = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> readTime = const Value.absent(),
                Value<int> duration = const Value.absent(),
              }) => ReadingHistoriesCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                readTime: readTime,
                duration: duration,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int bookId,
                required int chapterId,
                required int position,
                Value<DateTime> readTime = const Value.absent(),
                Value<int> duration = const Value.absent(),
              }) => ReadingHistoriesCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                readTime: readTime,
                duration: duration,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingHistoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false, chapterId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.bookId,
                                referencedTable:
                                    $$ReadingHistoriesTableReferences
                                        ._bookIdTable(db),
                                referencedColumn:
                                    $$ReadingHistoriesTableReferences
                                        ._bookIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (chapterId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.chapterId,
                                referencedTable:
                                    $$ReadingHistoriesTableReferences
                                        ._chapterIdTable(db),
                                referencedColumn:
                                    $$ReadingHistoriesTableReferences
                                        ._chapterIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingHistoriesTable,
      ReadingHistory,
      $$ReadingHistoriesTableFilterComposer,
      $$ReadingHistoriesTableOrderingComposer,
      $$ReadingHistoriesTableAnnotationComposer,
      $$ReadingHistoriesTableCreateCompanionBuilder,
      $$ReadingHistoriesTableUpdateCompanionBuilder,
      (ReadingHistory, $$ReadingHistoriesTableReferences),
      ReadingHistory,
      PrefetchHooks Function({bool bookId, bool chapterId})
    >;
typedef $$ReadingProgressesTableCreateCompanionBuilder =
    ReadingProgressesCompanion Function({
      required String bookId,
      required int chapterId,
      required int pageIndex,
      required int totalPages,
      required double progress,
      Value<int> readingTimeSeconds,
      required int lastReadTimestamp,
      Value<int> rowid,
    });
typedef $$ReadingProgressesTableUpdateCompanionBuilder =
    ReadingProgressesCompanion Function({
      Value<String> bookId,
      Value<int> chapterId,
      Value<int> pageIndex,
      Value<int> totalPages,
      Value<double> progress,
      Value<int> readingTimeSeconds,
      Value<int> lastReadTimestamp,
      Value<int> rowid,
    });

class $$ReadingProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReadTimestamp => $composableBuilder(
    column: $table.lastReadTimestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageIndex => $composableBuilder(
    column: $table.pageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReadTimestamp => $composableBuilder(
    column: $table.lastReadTimestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressesTable> {
  $$ReadingProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get pageIndex =>
      $composableBuilder(column: $table.pageIndex, builder: (column) => column);

  GeneratedColumn<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReadTimestamp => $composableBuilder(
    column: $table.lastReadTimestamp,
    builder: (column) => column,
  );
}

class $$ReadingProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressItem,
          $$ReadingProgressesTableFilterComposer,
          $$ReadingProgressesTableOrderingComposer,
          $$ReadingProgressesTableAnnotationComposer,
          $$ReadingProgressesTableCreateCompanionBuilder,
          $$ReadingProgressesTableUpdateCompanionBuilder,
          (
            ReadingProgressItem,
            BaseReferences<
              _$AppDatabase,
              $ReadingProgressesTable,
              ReadingProgressItem
            >,
          ),
          ReadingProgressItem,
          PrefetchHooks Function()
        > {
  $$ReadingProgressesTableTableManager(
    _$AppDatabase db,
    $ReadingProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<int> pageIndex = const Value.absent(),
                Value<int> totalPages = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<int> readingTimeSeconds = const Value.absent(),
                Value<int> lastReadTimestamp = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressesCompanion(
                bookId: bookId,
                chapterId: chapterId,
                pageIndex: pageIndex,
                totalPages: totalPages,
                progress: progress,
                readingTimeSeconds: readingTimeSeconds,
                lastReadTimestamp: lastReadTimestamp,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required int chapterId,
                required int pageIndex,
                required int totalPages,
                required double progress,
                Value<int> readingTimeSeconds = const Value.absent(),
                required int lastReadTimestamp,
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressesCompanion.insert(
                bookId: bookId,
                chapterId: chapterId,
                pageIndex: pageIndex,
                totalPages: totalPages,
                progress: progress,
                readingTimeSeconds: readingTimeSeconds,
                lastReadTimestamp: lastReadTimestamp,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressesTable,
      ReadingProgressItem,
      $$ReadingProgressesTableFilterComposer,
      $$ReadingProgressesTableOrderingComposer,
      $$ReadingProgressesTableAnnotationComposer,
      $$ReadingProgressesTableCreateCompanionBuilder,
      $$ReadingProgressesTableUpdateCompanionBuilder,
      (
        ReadingProgressItem,
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressesTable,
          ReadingProgressItem
        >,
      ),
      ReadingProgressItem,
      PrefetchHooks Function()
    >;
typedef $$LayoutCachesTableCreateCompanionBuilder =
    LayoutCachesCompanion Function({
      Value<int> id,
      required String bookId,
      required int chapterId,
      required String configHash,
      required String pageOffsets,
      required int totalPages,
      required int createdAt,
    });
typedef $$LayoutCachesTableUpdateCompanionBuilder =
    LayoutCachesCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<int> chapterId,
      Value<String> configHash,
      Value<String> pageOffsets,
      Value<int> totalPages,
      Value<int> createdAt,
    });

class $$LayoutCachesTableFilterComposer
    extends Composer<_$AppDatabase, $LayoutCachesTable> {
  $$LayoutCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configHash => $composableBuilder(
    column: $table.configHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pageOffsets => $composableBuilder(
    column: $table.pageOffsets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LayoutCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $LayoutCachesTable> {
  $$LayoutCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configHash => $composableBuilder(
    column: $table.configHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pageOffsets => $composableBuilder(
    column: $table.pageOffsets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LayoutCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LayoutCachesTable> {
  $$LayoutCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get configHash => $composableBuilder(
    column: $table.configHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pageOffsets => $composableBuilder(
    column: $table.pageOffsets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPages => $composableBuilder(
    column: $table.totalPages,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LayoutCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LayoutCachesTable,
          LayoutCacheItem,
          $$LayoutCachesTableFilterComposer,
          $$LayoutCachesTableOrderingComposer,
          $$LayoutCachesTableAnnotationComposer,
          $$LayoutCachesTableCreateCompanionBuilder,
          $$LayoutCachesTableUpdateCompanionBuilder,
          (
            LayoutCacheItem,
            BaseReferences<_$AppDatabase, $LayoutCachesTable, LayoutCacheItem>,
          ),
          LayoutCacheItem,
          PrefetchHooks Function()
        > {
  $$LayoutCachesTableTableManager(_$AppDatabase db, $LayoutCachesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LayoutCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LayoutCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LayoutCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<String> configHash = const Value.absent(),
                Value<String> pageOffsets = const Value.absent(),
                Value<int> totalPages = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => LayoutCachesCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                configHash: configHash,
                pageOffsets: pageOffsets,
                totalPages: totalPages,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required int chapterId,
                required String configHash,
                required String pageOffsets,
                required int totalPages,
                required int createdAt,
              }) => LayoutCachesCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                configHash: configHash,
                pageOffsets: pageOffsets,
                totalPages: totalPages,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LayoutCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LayoutCachesTable,
      LayoutCacheItem,
      $$LayoutCachesTableFilterComposer,
      $$LayoutCachesTableOrderingComposer,
      $$LayoutCachesTableAnnotationComposer,
      $$LayoutCachesTableCreateCompanionBuilder,
      $$LayoutCachesTableUpdateCompanionBuilder,
      (
        LayoutCacheItem,
        BaseReferences<_$AppDatabase, $LayoutCachesTable, LayoutCacheItem>,
      ),
      LayoutCacheItem,
      PrefetchHooks Function()
    >;
typedef $$ReadingStatsesTableCreateCompanionBuilder =
    ReadingStatsesCompanion Function({
      Value<int> id,
      Value<int> totalReadingTimeSeconds,
      Value<int> totalCharactersRead,
      Value<int> booksReadCount,
      Value<int> booksCompletedCount,
      Value<String?> lastReadDate,
      Value<int> consecutiveReadingDays,
      Value<int> rowid,
    });
typedef $$ReadingStatsesTableUpdateCompanionBuilder =
    ReadingStatsesCompanion Function({
      Value<int> id,
      Value<int> totalReadingTimeSeconds,
      Value<int> totalCharactersRead,
      Value<int> booksReadCount,
      Value<int> booksCompletedCount,
      Value<String?> lastReadDate,
      Value<int> consecutiveReadingDays,
      Value<int> rowid,
    });

class $$ReadingStatsesTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingStatsesTable> {
  $$ReadingStatsesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalReadingTimeSeconds => $composableBuilder(
    column: $table.totalReadingTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCharactersRead => $composableBuilder(
    column: $table.totalCharactersRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get booksReadCount => $composableBuilder(
    column: $table.booksReadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get booksCompletedCount => $composableBuilder(
    column: $table.booksCompletedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastReadDate => $composableBuilder(
    column: $table.lastReadDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveReadingDays => $composableBuilder(
    column: $table.consecutiveReadingDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingStatsesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingStatsesTable> {
  $$ReadingStatsesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalReadingTimeSeconds => $composableBuilder(
    column: $table.totalReadingTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCharactersRead => $composableBuilder(
    column: $table.totalCharactersRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get booksReadCount => $composableBuilder(
    column: $table.booksReadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get booksCompletedCount => $composableBuilder(
    column: $table.booksCompletedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastReadDate => $composableBuilder(
    column: $table.lastReadDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveReadingDays => $composableBuilder(
    column: $table.consecutiveReadingDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingStatsesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingStatsesTable> {
  $$ReadingStatsesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get totalReadingTimeSeconds => $composableBuilder(
    column: $table.totalReadingTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCharactersRead => $composableBuilder(
    column: $table.totalCharactersRead,
    builder: (column) => column,
  );

  GeneratedColumn<int> get booksReadCount => $composableBuilder(
    column: $table.booksReadCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get booksCompletedCount => $composableBuilder(
    column: $table.booksCompletedCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastReadDate => $composableBuilder(
    column: $table.lastReadDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveReadingDays => $composableBuilder(
    column: $table.consecutiveReadingDays,
    builder: (column) => column,
  );
}

class $$ReadingStatsesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingStatsesTable,
          ReadingStatsItem,
          $$ReadingStatsesTableFilterComposer,
          $$ReadingStatsesTableOrderingComposer,
          $$ReadingStatsesTableAnnotationComposer,
          $$ReadingStatsesTableCreateCompanionBuilder,
          $$ReadingStatsesTableUpdateCompanionBuilder,
          (
            ReadingStatsItem,
            BaseReferences<
              _$AppDatabase,
              $ReadingStatsesTable,
              ReadingStatsItem
            >,
          ),
          ReadingStatsItem,
          PrefetchHooks Function()
        > {
  $$ReadingStatsesTableTableManager(
    _$AppDatabase db,
    $ReadingStatsesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingStatsesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingStatsesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingStatsesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalReadingTimeSeconds = const Value.absent(),
                Value<int> totalCharactersRead = const Value.absent(),
                Value<int> booksReadCount = const Value.absent(),
                Value<int> booksCompletedCount = const Value.absent(),
                Value<String?> lastReadDate = const Value.absent(),
                Value<int> consecutiveReadingDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingStatsesCompanion(
                id: id,
                totalReadingTimeSeconds: totalReadingTimeSeconds,
                totalCharactersRead: totalCharactersRead,
                booksReadCount: booksReadCount,
                booksCompletedCount: booksCompletedCount,
                lastReadDate: lastReadDate,
                consecutiveReadingDays: consecutiveReadingDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> totalReadingTimeSeconds = const Value.absent(),
                Value<int> totalCharactersRead = const Value.absent(),
                Value<int> booksReadCount = const Value.absent(),
                Value<int> booksCompletedCount = const Value.absent(),
                Value<String?> lastReadDate = const Value.absent(),
                Value<int> consecutiveReadingDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingStatsesCompanion.insert(
                id: id,
                totalReadingTimeSeconds: totalReadingTimeSeconds,
                totalCharactersRead: totalCharactersRead,
                booksReadCount: booksReadCount,
                booksCompletedCount: booksCompletedCount,
                lastReadDate: lastReadDate,
                consecutiveReadingDays: consecutiveReadingDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingStatsesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingStatsesTable,
      ReadingStatsItem,
      $$ReadingStatsesTableFilterComposer,
      $$ReadingStatsesTableOrderingComposer,
      $$ReadingStatsesTableAnnotationComposer,
      $$ReadingStatsesTableCreateCompanionBuilder,
      $$ReadingStatsesTableUpdateCompanionBuilder,
      (
        ReadingStatsItem,
        BaseReferences<_$AppDatabase, $ReadingStatsesTable, ReadingStatsItem>,
      ),
      ReadingStatsItem,
      PrefetchHooks Function()
    >;
typedef $$DailyReadingRecordsTableCreateCompanionBuilder =
    DailyReadingRecordsCompanion Function({
      required String date,
      Value<int> readingTimeSeconds,
      Value<int> charactersRead,
      Value<int> chaptersRead,
      Value<int> pagesRead,
      Value<int> rowid,
    });
typedef $$DailyReadingRecordsTableUpdateCompanionBuilder =
    DailyReadingRecordsCompanion Function({
      Value<String> date,
      Value<int> readingTimeSeconds,
      Value<int> charactersRead,
      Value<int> chaptersRead,
      Value<int> pagesRead,
      Value<int> rowid,
    });

class $$DailyReadingRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyReadingRecordsTable> {
  $$DailyReadingRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chaptersRead => $composableBuilder(
    column: $table.chaptersRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyReadingRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyReadingRecordsTable> {
  $$DailyReadingRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chaptersRead => $composableBuilder(
    column: $table.chaptersRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pagesRead => $composableBuilder(
    column: $table.pagesRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyReadingRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyReadingRecordsTable> {
  $$DailyReadingRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get readingTimeSeconds => $composableBuilder(
    column: $table.readingTimeSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chaptersRead => $composableBuilder(
    column: $table.chaptersRead,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pagesRead =>
      $composableBuilder(column: $table.pagesRead, builder: (column) => column);
}

class $$DailyReadingRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyReadingRecordsTable,
          DailyReadingRecordItem,
          $$DailyReadingRecordsTableFilterComposer,
          $$DailyReadingRecordsTableOrderingComposer,
          $$DailyReadingRecordsTableAnnotationComposer,
          $$DailyReadingRecordsTableCreateCompanionBuilder,
          $$DailyReadingRecordsTableUpdateCompanionBuilder,
          (
            DailyReadingRecordItem,
            BaseReferences<
              _$AppDatabase,
              $DailyReadingRecordsTable,
              DailyReadingRecordItem
            >,
          ),
          DailyReadingRecordItem,
          PrefetchHooks Function()
        > {
  $$DailyReadingRecordsTableTableManager(
    _$AppDatabase db,
    $DailyReadingRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyReadingRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyReadingRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DailyReadingRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> date = const Value.absent(),
                Value<int> readingTimeSeconds = const Value.absent(),
                Value<int> charactersRead = const Value.absent(),
                Value<int> chaptersRead = const Value.absent(),
                Value<int> pagesRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyReadingRecordsCompanion(
                date: date,
                readingTimeSeconds: readingTimeSeconds,
                charactersRead: charactersRead,
                chaptersRead: chaptersRead,
                pagesRead: pagesRead,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String date,
                Value<int> readingTimeSeconds = const Value.absent(),
                Value<int> charactersRead = const Value.absent(),
                Value<int> chaptersRead = const Value.absent(),
                Value<int> pagesRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyReadingRecordsCompanion.insert(
                date: date,
                readingTimeSeconds: readingTimeSeconds,
                charactersRead: charactersRead,
                chaptersRead: chaptersRead,
                pagesRead: pagesRead,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyReadingRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyReadingRecordsTable,
      DailyReadingRecordItem,
      $$DailyReadingRecordsTableFilterComposer,
      $$DailyReadingRecordsTableOrderingComposer,
      $$DailyReadingRecordsTableAnnotationComposer,
      $$DailyReadingRecordsTableCreateCompanionBuilder,
      $$DailyReadingRecordsTableUpdateCompanionBuilder,
      (
        DailyReadingRecordItem,
        BaseReferences<
          _$AppDatabase,
          $DailyReadingRecordsTable,
          DailyReadingRecordItem
        >,
      ),
      DailyReadingRecordItem,
      PrefetchHooks Function()
    >;
typedef $$ReadingSessionsTableCreateCompanionBuilder =
    ReadingSessionsCompanion Function({
      required String sessionId,
      required String bookId,
      required int chapterId,
      required int startTimestamp,
      required int endTimestamp,
      required int durationSeconds,
      Value<int> charactersRead,
      Value<int> rowid,
    });
typedef $$ReadingSessionsTableUpdateCompanionBuilder =
    ReadingSessionsCompanion Function({
      Value<String> sessionId,
      Value<String> bookId,
      Value<int> chapterId,
      Value<int> startTimestamp,
      Value<int> endTimestamp,
      Value<int> durationSeconds,
      Value<int> charactersRead,
      Value<int> rowid,
    });

class $$ReadingSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimestamp => $composableBuilder(
    column: $table.startTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTimestamp => $composableBuilder(
    column: $table.endTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimestamp => $composableBuilder(
    column: $table.startTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTimestamp => $composableBuilder(
    column: $table.endTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get startTimestamp => $composableBuilder(
    column: $table.startTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endTimestamp => $composableBuilder(
    column: $table.endTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charactersRead => $composableBuilder(
    column: $table.charactersRead,
    builder: (column) => column,
  );
}

class $$ReadingSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingSessionsTable,
          ReadingSessionItem,
          $$ReadingSessionsTableFilterComposer,
          $$ReadingSessionsTableOrderingComposer,
          $$ReadingSessionsTableAnnotationComposer,
          $$ReadingSessionsTableCreateCompanionBuilder,
          $$ReadingSessionsTableUpdateCompanionBuilder,
          (
            ReadingSessionItem,
            BaseReferences<
              _$AppDatabase,
              $ReadingSessionsTable,
              ReadingSessionItem
            >,
          ),
          ReadingSessionItem,
          PrefetchHooks Function()
        > {
  $$ReadingSessionsTableTableManager(
    _$AppDatabase db,
    $ReadingSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterId = const Value.absent(),
                Value<int> startTimestamp = const Value.absent(),
                Value<int> endTimestamp = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<int> charactersRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingSessionsCompanion(
                sessionId: sessionId,
                bookId: bookId,
                chapterId: chapterId,
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp,
                durationSeconds: durationSeconds,
                charactersRead: charactersRead,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String bookId,
                required int chapterId,
                required int startTimestamp,
                required int endTimestamp,
                required int durationSeconds,
                Value<int> charactersRead = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingSessionsCompanion.insert(
                sessionId: sessionId,
                bookId: bookId,
                chapterId: chapterId,
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp,
                durationSeconds: durationSeconds,
                charactersRead: charactersRead,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingSessionsTable,
      ReadingSessionItem,
      $$ReadingSessionsTableFilterComposer,
      $$ReadingSessionsTableOrderingComposer,
      $$ReadingSessionsTableAnnotationComposer,
      $$ReadingSessionsTableCreateCompanionBuilder,
      $$ReadingSessionsTableUpdateCompanionBuilder,
      (
        ReadingSessionItem,
        BaseReferences<
          _$AppDatabase,
          $ReadingSessionsTable,
          ReadingSessionItem
        >,
      ),
      ReadingSessionItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ChaptersTableTableManager get chapters =>
      $$ChaptersTableTableManager(_db, _db.chapters);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ReadingHistoriesTableTableManager get readingHistories =>
      $$ReadingHistoriesTableTableManager(_db, _db.readingHistories);
  $$ReadingProgressesTableTableManager get readingProgresses =>
      $$ReadingProgressesTableTableManager(_db, _db.readingProgresses);
  $$LayoutCachesTableTableManager get layoutCaches =>
      $$LayoutCachesTableTableManager(_db, _db.layoutCaches);
  $$ReadingStatsesTableTableManager get readingStatses =>
      $$ReadingStatsesTableTableManager(_db, _db.readingStatses);
  $$DailyReadingRecordsTableTableManager get dailyReadingRecords =>
      $$DailyReadingRecordsTableTableManager(_db, _db.dailyReadingRecords);
  $$ReadingSessionsTableTableManager get readingSessions =>
      $$ReadingSessionsTableTableManager(_db, _db.readingSessions);
}
