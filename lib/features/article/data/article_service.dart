import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/article/data/article_api.dart';

import '../domain/repositories/article_repository.dart';
import '../domain/models/article.dart';

@LazySingleton(as: ArticleRepository)
class ArticleService implements ArticleRepository {
  final ArticleApi _api;
  @factoryMethod
  ArticleService(this._api);

  @override
  Future<List<Article>> getArticles() async {
    try {
      final result = await _api.getArticles();
      return result;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<Article> getArticle(int id) async {
    try {
      return await _api.getArticle(id);
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
