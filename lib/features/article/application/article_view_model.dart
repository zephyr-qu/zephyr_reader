import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../domain/article_repository.dart';
import '../domain/models/article.dart';

@injectable
class ArticleViewModel {
  final ArticleRepository _repo;

  @factoryMethod
  ArticleViewModel(this._repo);

  final articles = asyncSignal<List<Article>>(AsyncState.loading());

  final selectedArticle = asyncSignal<Article?>(AsyncState.data(null));

  Future<void> load() async {
    articles.value = AsyncState.loading();
    try {
      final data = await _repo.getArticles();
      articles.value = AsyncState.data(data);
    } catch (e) {
      articles.value = AsyncState.error(e);
    }
  }

  Future<void> loadDetail(int id) async {
    selectedArticle.value = AsyncState.loading();
    try {
      final data = await _repo.getArticle(id);
      selectedArticle.value = AsyncState.data(data);
    } catch (e) {
      selectedArticle.value = AsyncState.error(e);
    }
  }
}
