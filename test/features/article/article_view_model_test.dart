library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/article/application/article_view_model.dart';
import 'package:zephyr_reader/features/article/data/article_api.dart';
import 'package:zephyr_reader/features/article/data/article_service.dart';
import 'package:zephyr_reader/features/article/domain/models/article.dart';

class _MockArticleApi implements ArticleApi {
  final _articles = <int, Article>{};
  bool _shouldThrow = false;

  void addArticle(Article a) => _articles[a.id] = a;
  void setThrowOnNextCall() => _shouldThrow = true;

  @override
  Future<List<Article>> getArticles() async {
    if (_shouldThrow) throw Exception('Network error');
    return _articles.values.toList();
  }

  @override
  Future<Article> getArticle(int id) async {
    if (_shouldThrow) throw Exception('Network error');
    return _articles[id] ?? (throw Exception('Article not found'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArticleViewModel', () {
    late _MockArticleApi api;
    late ArticleRepository repo;
    late ArticleViewModel vm;

    setUp(() {
      api = _MockArticleApi();
      repo = ArticleRepository(api);
      vm = ArticleViewModel(repo);
    });

    group('加载文章列表', () {
      test('初始状态应为 loading', () {
        expect(vm.articles.value.value, isNull);
        expect(vm.articles.value.error, isNull);
      });

      test('load 应加载所有文章', () async {
        api.addArticle(
          Article(
            id: 1,
            title: '测试文章',
            summary: '这是一篇测试文章',
            author: '作者',
            readDuration: 10,
            publishedAt: '2026-01-01',
            content: '正文内容',
            wordCount: 1000,
          ),
        );
        api.addArticle(
          Article(
            id: 2,
            title: '第二篇文章',
            summary: '这是第二篇',
            author: '作者',
            readDuration: 5,
            publishedAt: '2026-01-02',
            content: '正文内容2',
            wordCount: 500,
          ),
        );

        await vm.load();

        expect(vm.articles.value.value?.length, equals(2));
        expect(vm.articles.value.value?.first.title, equals('测试文章'));
        expect(vm.articles.value.error, isNull);
      });

      test('load 空列表应返回空', () async {
        await vm.load();

        expect(vm.articles.value.value, isEmpty);
        expect(vm.articles.value.error, isNull);
      });

      test('load 失败应设置 error 状态', () async {
        api.setThrowOnNextCall();

        await vm.load();

        expect(vm.articles.value.value, isNull);
        expect(vm.articles.value.error?.toString(), contains('Network error'));
      });
    });

    group('加载文章详情', () {
      test('loadDetail 应加载指定文章', () async {
        api.addArticle(
          Article(
            id: 1,
            title: '测试文章',
            summary: '摘要',
            author: '作者',
            readDuration: 10,
            publishedAt: '2026-01-01',
            content: '正文内容',
            wordCount: 1000,
          ),
        );

        await vm.loadDetail(1);

        expect(vm.selectedArticle.value.value?.id, equals(1));
        expect(vm.selectedArticle.value.value?.title, equals('测试文章'));
        expect(vm.selectedArticle.value.value?.content, equals('正文内容'));
      });

      test('loadDetail 不存在的文章应设置 error', () async {
        await vm.loadDetail(999);

        expect(vm.selectedArticle.value.value, isNull);
        expect(vm.selectedArticle.value.error, isNotNull);
      });
    });
  });
}
