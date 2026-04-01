// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Article _$ArticleFromJson(Map<String, dynamic> json) => Article(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  summary: json['summary'] as String,
  author: json['author'] as String,
  coverUrl: json['coverUrl'] as String?,
  readDuration: (json['readDuration'] as num).toInt(),
  publishedAt: json['publishedAt'] as String,
  content: json['content'] as String,
  wordCount: (json['wordCount'] as num).toInt(),
);

Map<String, dynamic> _$ArticleToJson(Article instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'summary': instance.summary,
  'author': instance.author,
  'coverUrl': instance.coverUrl,
  'readDuration': instance.readDuration,
  'publishedAt': instance.publishedAt,
  'content': instance.content,
  'wordCount': instance.wordCount,
};
