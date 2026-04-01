import 'package:json_annotation/json_annotation.dart';

part 'article.g.dart';

@JsonSerializable()
class Article {
  final int id;
  final String title;
  final String summary;
  final String author;
  final String? coverUrl;
  final int readDuration; // 阅读时长（分钟）
  final String publishedAt;
  final String content;
  final int wordCount;

  Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.author,
    this.coverUrl,
    required this.readDuration,
    required this.publishedAt,
    required this.content,
    required this.wordCount,
  });

  factory Article.fromJson(Map<String, dynamic> json) =>
      _$ArticleFromJson(json);

  Map<String, dynamic> toJson() => _$ArticleToJson(this);
}
