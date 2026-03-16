/// 书籍分类
enum BookCategory {
  all('全部'),
  reading('阅读中'),
  completed('已完结'),
  dropped('已弃坑');

  final String displayName;
  const BookCategory(this.displayName);

  static BookCategory fromString(String value) {
    return BookCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => BookCategory.all,
    );
  }
}
