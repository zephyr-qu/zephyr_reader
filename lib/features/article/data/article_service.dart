import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/article/data/article_api.dart';

import '../domain/models/article.dart';

@LazySingleton()
class ArticleRepository {
  final ArticleApi _api;
  @factoryMethod
  ArticleRepository(this._api);

  Future<List<Article>> getArticles() async => _api.getArticles();

  Future<Article> getArticle(int id) async => _api.getArticle(id);
}
