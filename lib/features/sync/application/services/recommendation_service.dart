/// 阅读推荐服务
///
/// 基于阅读历史和行为提供个性化推荐
library;

/// 推荐服务
class RecommendationService {
  // 本地书籍数据库（模拟）
  final List<BookInfo> _bookDatabase = [];
  
  // 阅读统计（模拟）
  final Map<String, ReadingStats> _readingStats = {};

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

    // 生成推荐
    final recommendations = <BookRecommendation>[];

    // 基于作者推荐
    if (preferences.favoriteAuthors.isNotEmpty) {
      for (final author in preferences.favoriteAuthors.take(3)) {
        recommendations.add(
          BookRecommendation(
            reason: '你喜欢阅读$author 的作品',
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
            reason: '你可能喜欢$genre 题材',
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
    // 获取当前书籍信息
    final currentBook = _bookDatabase.firstWhere(
      (b) => b.id == bookId,
      orElse: () => BookInfo(id: bookId, title: '', author: '', genres: []),
    );

    if (currentBook.id.isEmpty) {
      // 书籍不存在，返回空列表
      return [];
    }

    // 计算相似度分数
    final scoredBooks = <_ScoredBook>[];
    
    for (final book in _bookDatabase) {
      if (book.id == bookId) continue; // 跳过当前书籍

      double score = 0.0;

      // 作者相同，加分
      if (book.author == currentBook.author) {
        score += 0.4;
      }

      // 题材相似度（Jaccard 相似系数）
      final currentGenres = currentBook.genres.toSet();
      final bookGenres = book.genres.toSet();
      if (currentGenres.isNotEmpty && bookGenres.isNotEmpty) {
        final intersection = currentGenres.intersection(bookGenres).length;
        final union = currentGenres.union(bookGenres).length;
        if (union > 0) {
          score += (intersection / union) * 0.4;
        }
      }

      // 阅读人数相似度（受欢迎程度）
      final readerSimilarity = 1.0 / (1 + (book.readCount - currentBook.readCount).abs());
      score += readerSimilarity * 0.2;

      if (score > 0.3) {
        scoredBooks.add(_ScoredBook(book: book, score: score));
      }
    }

    // 按分数排序
    scoredBooks.sort((a, b) => b.score.compareTo(a.score));

    // 生成推荐列表
    return scoredBooks.take(limit).map((sb) {
      final book = sb.book;
      String reason = '';
      
      if (book.author == currentBook.author) {
        reason = '同作者${book.author}的作品';
      } else if (book.genres.any((g) => currentBook.genres.contains(g))) {
        final commonGenres = book.genres.where((g) => currentBook.genres.contains(g));
        reason = '相似题材：${commonGenres.join(', ')}';
      } else {
        reason = '读者也喜欢的作品';
      }

      return BookRecommendation(
        reason: reason,
        score: sb.score,
        metadata: {
          'bookId': book.id,
          'title': book.title,
          'author': book.author,
        },
      );
    }).toList();
  }

  /// 热门推荐（本地）
  List<BookRecommendation> getPopularRecommendations({int limit = 10}) {
    // 基于本地阅读统计生成热门推荐
    // 计算每本书的热门分数：阅读人数 * 0.4 + 平均评分 * 0.3 + 最近阅读量 * 0.3
    
    final scoredBooks = <_ScoredBook>[];
    
    for (final book in _bookDatabase) {
      final stats = _readingStats[book.id] ?? ReadingStats(readCount: 0, avgRating: 0, lastReadAt: DateTime(2000));
      
      // 归一化分数
      final readScore = stats.readCount / 100.0; // 假设最多 100 次阅读
      final ratingScore = stats.avgRating / 5.0; // 5 分制
      
      // 最近阅读时间分数（越近越高）
      final daysSinceRead = DateTime.now().difference(stats.lastReadAt).inDays;
      final recencyScore = 1.0 / (1 + daysSinceRead / 30.0); // 30 天内为高分
      
      final totalScore = readScore * 0.4 + ratingScore * 0.3 + recencyScore * 0.3;
      
      if (totalScore > 0.1) {
        scoredBooks.add(_ScoredBook(book: book, score: totalScore));
      }
    }

    // 按分数排序
    scoredBooks.sort((a, b) => b.score.compareTo(a.score));

    // 生成推荐列表
    return scoredBooks.take(limit).map((sb) {
      final book = sb.book;
      final stats = _readingStats[book.id];
      
      String reason = '';
      if (stats != null && stats.readCount > 50) {
        reason = '本周热门：${stats.readCount}人在读';
      } else if (stats != null && stats.avgRating >= 4.5) {
        reason = '高分推荐：${stats.avgRating.toStringAsFixed(1)}分';
      } else {
        reason = '精选好书';
      }

      return BookRecommendation(
        reason: reason,
        score: sb.score,
        metadata: {
          'bookId': book.id,
          'title': book.title,
          'author': book.author,
        },
      );
    }).toList();
  }

  /// 添加书籍到数据库（用于测试）
  void addBook(BookInfo book) {
    _bookDatabase.add(book);
  }

  /// 更新阅读统计（用于测试）
  void updateReadingStats(String bookId, ReadingStats stats) {
    _readingStats[bookId] = stats;
  }

  /// 分析阅读偏好
  ReadingPreferences _analyzePreferences(List<ReadingHistory> history) {
    final authorCount = <String, int>{};
    final genreCount = <String, int>{};
    var totalTime = 0;

    for (final record in history) {
      // 统计作者
      authorCount[record.author] = (authorCount[record.author] ?? 0) + 1;

      // 统计题材
      if (record.genre != null) {
        genreCount[record.genre!] = (genreCount[record.genre!] ?? 0) + 1;
      }

      // 累计阅读时长
      totalTime += record.readingTimeMinutes;
    }

    // 找出最喜欢的作者
    final favoriteAuthors = authorCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 找出最喜欢的题材
    final favoriteGenres = genreCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ReadingPreferences(
      favoriteAuthors: favoriteAuthors.take(5).map((e) => e.key).toList(),
      favoriteGenres: favoriteGenres.take(5).map((e) => e.key).toList(),
      averageReadingTime: totalTime ~/ history.length,
    );
  }
}

/// 内部类：带分数的书籍
class _ScoredBook {
  final BookInfo book;
  final double score;

  _ScoredBook({required this.book, required this.score});
}

/// 书籍信息
class BookInfo {
  final String id;
  final String title;
  final String author;
  final List<String> genres;
  final int readCount;

  BookInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.genres,
    this.readCount = 0,
  });
}

/// 阅读统计
class ReadingStats {
  final int readCount;
  final double avgRating;
  final DateTime lastReadAt;

  ReadingStats({
    required this.readCount,
    required this.avgRating,
    required this.lastReadAt,
  });
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

  /// 推荐分数 0-1
  final double score;

  /// 元数据
  final Map<String, dynamic> metadata;

  BookRecommendation({
    required this.reason,
    required this.score,
    required this.metadata,
  });
}
