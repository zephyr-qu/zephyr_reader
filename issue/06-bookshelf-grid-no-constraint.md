# P4.2: 书架页面网格缺少宽度约束

- **审查来源**: `issue/responsive-layout-review.md`
- **严重程度**: P4（一致性）
- **文件**: `lib/features/bookshelf/page/shelf/bookshelf_book_content.dart`

## 问题

网格（`GridView.builder`）直接渲染在 `Expanded` 中，没有 `Center` + `ConstrainedBox` 限制最大宽度。超宽显示器上，4 列书籍封面会拉伸到不切实际的大小。

## 建议

参考 `home_page.dart` 的做法，在网格外包裹 `Center(child: ConstrainedBox(maxWidth: …))`。
