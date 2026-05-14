import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/article/data/article_api.dart';

import '../domain/models/article.dart';

@LazySingleton()
class ArticleRepository {
  final ArticleApi _api;
  @factoryMethod
  ArticleRepository(this._api);

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
