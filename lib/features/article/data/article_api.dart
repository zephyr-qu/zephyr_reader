import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/article/domain/models/article.dart';

@injectable
class ArticleApi {
  final Dio _dio;

  @factoryMethod
  ArticleApi(this._dio);

  Future<List<Article>> getArticles() async {
    final res = await _dio.get('/articles');
    return (res.data as List)
        .map((e) => Article.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Article> getArticle(int id) async {
    final res = await _dio.get('/articles/$id');
    return Article.fromJson(res.data as Map<String, dynamic>);
  }
}
