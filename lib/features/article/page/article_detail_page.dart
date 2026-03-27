import 'package:flutter/material.dart';

/// 文章详情页面
class ArticleDetailPage extends StatelessWidget {
  final int articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 模拟文章数据（实际应从 API 获取）
    final article = _mockArticles.firstWhere(
      (a) => a.id == articleId,
      orElse: () => _mockArticles.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(article.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('分享功能开发中')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已收藏')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文章元信息
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.author,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        article.publishedAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 文章标题
            Text(
              article.title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // 文章封面图
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.image,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            // 文章内容
            Text(
              article.content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
            ),
          ],
        ),
      ),
    );
  }

  // 模拟文章数据
  static final List<_Article> _mockArticles = [
    _Article(
      id: 1,
      title: 'Flutter 最佳实践',
      author: '张三',
      publishedAt: '2026 年 3 月 20 日',
      content: '''
Flutter 是一个由 Google 开发的开源 UI 软件工具包，用于使用单一代码库为移动、Web 和桌面平台创建编译为本机的应用程序。

## 为什么选择 Flutter？

Flutter 提供了丰富的预构建小部件、热重载功能以及跨平台开发能力，使得开发者可以快速构建高质量的应用程序。

### 主要特性

- **热重载**：无需重新启动即可实时查看代码更改的效果
- **丰富的组件**：提供 Material Design 和 Cupertino 风格的组件
- **高性能**：直接编译为原生 ARM 代码
- **跨平台**：一套代码支持 iOS、Android、Web、Windows、macOS 和 Linux

### 开始使用

```dart
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
```

这就是 Flutter 的魅力所在，简洁而强大！
''',
    ),
    _Article(
      id: 2,
      title: 'Dart 语言入门',
      author: '李四',
      publishedAt: '2026 年 3 月 18 日',
      content: 'Dart 是一种由 Google 开发的编程语言，主要用于构建 Web、服务器和移动应用程序...',
    ),
  ];
}

class _Article {
  final int id;
  final String title;
  final String author;
  final String publishedAt;
  final String content;

  _Article({
    required this.id,
    required this.title,
    required this.author,
    required this.publishedAt,
    required this.content,
  });
}
