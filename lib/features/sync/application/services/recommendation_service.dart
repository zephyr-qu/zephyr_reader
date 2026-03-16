/// 阅读推荐服务
///
/// 基于阅读历史和行为提供个性化推荐
library;

import 'dart:math';

import 'package:flutter/foundation.dart';

/// 推荐服务
class RecommendationService {
  /// 基于阅读历史推荐
  List<BookRecommendation> recommendByHistory({
    required List<ReadingHistory> history,
    int limit = 10,
  }) {
    if (history.isEmpty) {
      return [];
    }

    // 分析阅读偏好
    final preferences = _analyzePreferences(history);

    // 生成推荐（示例）
    final recommendations = <BookRecommendation>[];

    // 基于作者推�?
    if (preferences.favoriteAuthors.isNotEmpty) {
      for (final author in preferences.favoriteAuthors.take(3)) {
        recommendations.add(
          BookRecommendation(
            reason: '你喜欢阅�?$author 的作�?',
            score: 0.9,
            metadata: {'author': author},
          ),
        );
      }
    }

    // 基于题材推荐
    if (preferences.favoriteGenres.isNotEmpty) {
      for (final genre in preferences.favoriteGenres.take(3)) {
        recommendations.add(
          BookRecommendation(
            reason: '你可能喜�?genre 题材',
            score: 0.8,
            metadata: {'genre': genre},
          ),
        );
      }
    }

    // 基于阅读时长推荐
    if (preferences.averageReadingTime > 30) {
      recommendations.add(
        BookRecommendation(
          reason: '推荐长篇作品',
          score: 0.7,
          metadata: {'type': 'long'},
        ),
      );
    }

    return recommendations.take(limit).toList();
  }

  /// 基于当前书籍推荐相似作品
  List<BookRecommendation> recommendSimilar({
    required String bookId,
    int limit = 5,
  }) {
    // TODO: 实现相似书籍推荐
    return List.generate(
      limit,
      (index) => BookRecommendation(
        reason: '与当前书籍相�?',
        score: 0.5 + (Random().nextDouble() * 0.3),
        metadata: {'bookId': bookId},
      ),
    );
  }

  /// 热门推荐（本地）
  List<BookRecommendation> getPopularRecommendations({int limit = 10}) {
    // TODO: 基于本地阅读统计生成热门推荐
    return List.generate(
      limit,
      (index) => BookRecommendation(
        reason: '热门书籍',
        score: 0.6 + (Random().nextDouble() * 0.3),
        metadata: {},
      ),
    );
  }

  /// 分析阅读偏好
  ReadingPreferences _analyzePreferences(List<ReadingHistory> history) {
    final authorCount = <String, int>{};
    final genreCount = <String, int>{};
    var totalTime = 0;

    for (final record in history) {
      // 统计作�?
        authorCount[record.author] = (authorCount[record.author] ?? 0) + 1;

      // 统计题材
      if (record.genre != null) {
        genreCount[record.genre!] = (genreCount[record.genre!] ?? 0) + 1;
      }

      // 累计阅读时长
      totalTime += record.readingTimeMinutes;
    }

    // 找出最喜欢的作�?
      final favoriteAuthors = authorCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 找出最喜欢的题�?
      final favoriteGenres = genreCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ReadingPreferences(
      favoriteAuthors: favoriteAuthors.take(5).map((e) => e.key).toList(),
      favoriteGenres: favoriteGenres.take(5).map((e) => e.key).toList(),
      averageReadingTime: totalTime ~/ history.length,
    );
  }
}

/// 阅读历史
class ReadingHistory {
  final String bookId;
  final String title;
  final String author;
  final String? genre;
  final int readingTimeMinutes;
  final DateTime lastReadAt;

  ReadingHistory({
    required this.bookId,
    required this.title,
    required this.author,
    this.genre,
    required this.readingTimeMinutes,
    required this.lastReadAt,
  });
}

/// 阅读偏好
class ReadingPreferences {
  final List<String> favoriteAuthors;
  final List<String> favoriteGenres;
  final int averageReadingTime;

  ReadingPreferences({
    required this.favoriteAuthors,
    required this.favoriteGenres,
    required this.averageReadingTime,
  });
}

/// 书籍推荐
class BookRecommendation {
  /// 推荐原因
  final String reason;

  /// 推荐分数�?-1�?
    final double score;

  /// 元数�?
   final Map<String, dynamic> metadata;

  BookRecommendation({
    required this.reason,
    required this.score,
    required this.metadata,
  });
}
