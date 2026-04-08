// /// 书签管理页面测试
// library;

// import 'package:flutter_test/flutter_test.dart';
// import 'package:zephyr_reader/features/reader/page/bookmark_manage_page.dart';
// import 'package:zephyr_reader/src/rust/ffi/types.dart';

// void main() {
//   group('书签管理页面测试', () {
//     group('BookmarkSortType 枚举测试', () {
//       test('枚举值数量', () {
//         expect(BookmarkSortType.values.length, equals(3));
//       });

//       test('枚举值标签', () {
//         expect(BookmarkSortType.createdAt.label, equals('时间'));
//         expect(BookmarkSortType.chapterId.label, equals('章节'));
//         expect(BookmarkSortType.position.label, equals('位置'));
//       });
//     });

//     group('Bookmark 模型测试', () {
//       test('创建书签', () {
//         final bookmark = Bookmark(

//           bookId: 100,
//           chapterId: 5,
//           position: 1000,
//           note: '测试书签',
//           createdAt: DateTime.now(),
//           bookmarkId: '',
//           pageIndex: null,
//           title: '', createdTimestamp: null,
//         );

//         expect(bookmark.id, equals(1));
//         expect(bookmark.bookId, equals(100));
//         expect(bookmark.chapterId, equals(5));
//         expect(bookmark.position, equals(1000));
//         expect(bookmark.note, equals('测试书签'));
//       });

//       test('创建空书签', () {
//         final bookmark = Bookmark.empty();

//         expect(bookmark.id, equals(0));
//         expect(bookmark.bookId, equals(0));
//         expect(bookmark.chapterId, equals(0));
//         expect(bookmark.position, equals(0));
//       });

//       test('书签比较', () {
//         final now = DateTime.now();
//         final bookmark1 = Bookmark(
//           id: 1,
//           bookId: 100,
//           chapterId: 5,
//           position: 1000,
//           createdAt: now,
//         );
//         final bookmark2 = Bookmark(
//           id: 2,
//           bookId: 100,
//           chapterId: 10,
//           position: 2000,
//           createdAt: now.add(const Duration(hours: 1)),
//         );

//         // 比较章节 ID
//         expect(bookmark1.chapterId.compareTo(bookmark2.chapterId), lessThan(0));

//         // 比较位置
//         expect(bookmark1.position.compareTo(bookmark2.position), lessThan(0));

//         // 比较时间
//         expect(bookmark1.createdAt.compareTo(bookmark2.createdAt), lessThan(0));
//       });
//     });

//     group('书签排序逻辑测试', () {
//       test('按时间排序 - 升序', () {
//         final now = DateTime.now();
//         final bookmarks = [
//           Bookmark(
//             id: 1,
//             bookId: 100,
//             chapterId: 5,
//             position: 1000,
//             createdAt: now.subtract(const Duration(hours: 2)),
//           ),
//           Bookmark(
//             id: 2,
//             bookId: 100,
//             chapterId: 10,
//             position: 2000,
//             createdAt: now.subtract(const Duration(hours: 1)),
//           ),
//           Bookmark(
//             id: 3,
//             bookId: 100,
//             chapterId: 15,
//             position: 3000,
//             createdAt: now,
//           ),
//         ];

//         // 升序排序
//         bookmarks.sort((a, b) => a.createdAt.compareTo(b.createdAt));

//         expect(bookmarks[0].id, equals(1));
//         expect(bookmarks[1].id, equals(2));
//         expect(bookmarks[2].id, equals(3));
//       });

//       test('按时间排序 - 降序', () {
//         final now = DateTime.now();
//         final bookmarks = [
//           Bookmark(
//             id: 1,
//             bookId: 100,
//             chapterId: 5,
//             position: 1000,
//             createdAt: now.subtract(const Duration(hours: 2)),
//           ),
//           Bookmark(
//             id: 2,
//             bookId: 100,
//             chapterId: 10,
//             position: 2000,
//             createdAt: now.subtract(const Duration(hours: 1)),
//           ),
//           Bookmark(
//             id: 3,
//             bookId: 100,
//             chapterId: 15,
//             position: 3000,
//             createdAt: now,
//           ),
//         ];

//         // 降序排序
//         bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

//         expect(bookmarks[0].id, equals(3));
//         expect(bookmarks[1].id, equals(2));
//         expect(bookmarks[2].id, equals(1));
//       });

//       test('按章节排序', () {
//         final now = DateTime.now();
//         final bookmarks = [
//           Bookmark(
//             id: 1,
//             bookId: 100,
//             chapterId: 15,
//             position: 1000,
//             createdAt: now,
//           ),
//           Bookmark(
//             id: 2,
//             bookId: 100,
//             chapterId: 5,
//             position: 2000,
//             createdAt: now,
//           ),
//           Bookmark(
//             id: 3,
//             bookId: 100,
//             chapterId: 10,
//             position: 3000,
//             createdAt: now,
//           ),
//         ];

//         // 按章节升序
//         bookmarks.sort((a, b) => a.chapterId.compareTo(b.chapterId));

//         expect(bookmarks[0].chapterId, equals(5));
//         expect(bookmarks[1].chapterId, equals(10));
//         expect(bookmarks[2].chapterId, equals(15));
//       });

//       test('按位置排序', () {
//         final now = DateTime.now();
//         final bookmarks = [
//           Bookmark(
//             id: 1,
//             bookId: 100,
//             chapterId: 5,
//             position: 3000,
//             createdAt: now,
//           ),
//           Bookmark(
//             id: 2,
//             bookId: 100,
//             chapterId: 10,
//             position: 1000,
//             createdAt: now,
//           ),
//           Bookmark(
//             id: 3,
//             bookId: 100,
//             chapterId: 15,
//             position: 2000,
//             createdAt: now,
//           ),
//         ];

//         // 按位置升序
//         bookmarks.sort((a, b) => a.position.compareTo(b.position));

//         expect(bookmarks[0].position, equals(1000));
//         expect(bookmarks[1].position, equals(2000));
//         expect(bookmarks[2].position, equals(3000));
//       });
//     });

//     group('书签搜索逻辑测试', () {
//       test('搜索书签 - 匹配备注', () {
//         final bookmarks = [
//           Bookmark(
//             id: 1,
//             bookId: 100,
//             chapterId: 5,
//             position: 1000,
//             note: '重要内容',
//             createdAt: DateTime.now(),
//           ),
//           Bookmark(
//             id: 2,
//             bookId: 100,
//             chapterId: 10,
//             position: 2000,
//             note: '普通笔记',
//             createdAt: DateTime.now(),
//           ),
//           Bookmark(
//             id: 3,
//             bookId: 100,
//             chapterId: 15,
//             position: 3000,
//             note: '关键信息',
//             createdAt: DateTime.now(),
//           ),
//         ];

//         // 搜索"重"
//         final keyword = '重';
//         final filtered = bookmarks.where((b) {
//           return (b.note ?? '').toLowerCase().contains(keyword.toLowerCase());
//         }).toList();

//         expect(filtered.length, equals(1));
//         expect(filtered[0].note, equals('重要内容'));
//       });

//       test('搜索书签 - 匹配章节 ID', () {
//         final bookmarks = [
//           Bookmark(
//             id: 1,
//             bookId: 100,
//             chapterId: 5,
//             position: 1000,
//             note: '笔记 1',
//             createdAt: DateTime.now(),
//           ),
//           Bookmark(
//             id: 2,
//             bookId: 100,
//             chapterId: 10,
//             position: 2000,
//             note: '笔记 2',
//             createdAt: DateTime.now(),
//           ),
//           Bookmark(
//             id: 3,
//             bookId: 100,
//             chapterId: 15,
//             position: 3000,
//             note: '笔记 3',
//             createdAt: DateTime.now(),
//           ),
//         ];

//         // 搜索"1"
//         final keyword = '1';
//         final filtered = bookmarks.where((b) {
//           return (b.note ?? '').toLowerCase().contains(keyword) ||
//               b.chapterId.toString().contains(keyword);
//         }).toList();

//         expect(filtered.length, equals(3)); // 3 个书签的章节 ID 都包含 1 或 5
//       });

//       test('搜索书签 - 无结果', () {
//         final bookmarks = [
//           Bookmark(
//             id: 1,
//             bookId: 100,
//             chapterId: 5,
//             position: 1000,
//             note: '笔记',
//             createdAt: DateTime.now(),
//           ),
//         ];

//         // 搜索不存在的关键词
//         final keyword = '不存在的关键词';
//         final filtered = bookmarks.where((b) {
//           return (b.note ?? '').toLowerCase().contains(keyword.toLowerCase());
//         }).toList();

//         expect(filtered.length, equals(0));
//       });
//     });

//     group('书签批量操作测试', () {
//       test('选择多个书签', () {
//         final selectedIds = <int>{};

//         // 选择书签 1
//         selectedIds.add(1);
//         expect(selectedIds.contains(1), isTrue);
//         expect(selectedIds.length, equals(1));

//         // 选择书签 2
//         selectedIds.add(2);
//         expect(selectedIds.contains(2), isTrue);
//         expect(selectedIds.length, equals(2));

//         // 选择书签 3
//         selectedIds.add(3);
//         expect(selectedIds.contains(3), isTrue);
//         expect(selectedIds.length, equals(3));
//       });

//       test('取消选择书签', () {
//         final selectedIds = <int>{1, 2, 3};

//         // 取消选择书签 2
//         selectedIds.remove(2);
//         expect(selectedIds.contains(2), isFalse);
//         expect(selectedIds.length, equals(2));

//         // 取消选择书签 1
//         selectedIds.remove(1);
//         expect(selectedIds.contains(1), isFalse);
//         expect(selectedIds.length, equals(1));
//       });

//       test('切换选择状态', () {
//         final selectedIds = <int>{};
//         final bookmarkId = 1;

//         // 第一次切换 - 选中
//         if (selectedIds.contains(bookmarkId)) {
//           selectedIds.remove(bookmarkId);
//         } else {
//           selectedIds.add(bookmarkId);
//         }
//         expect(selectedIds.contains(bookmarkId), isTrue);

//         // 第二次切换 - 取消选中
//         if (selectedIds.contains(bookmarkId)) {
//           selectedIds.remove(bookmarkId);
//         } else {
//           selectedIds.add(bookmarkId);
//         }
//         expect(selectedIds.contains(bookmarkId), isFalse);
//       });
//     });

//     group('时间格式化测试', () {
//       test('刚刚', () {
//         final now = DateTime.now();
//         final result = _formatDate(now);
//         expect(result, equals('刚刚'));
//       });

//       test('几分钟前', () {
//         final now = DateTime.now();
//         final time = now.subtract(const Duration(minutes: 5));
//         final result = _formatDate(time);
//         expect(result, contains('分钟前'));
//       });

//       test('几小时前', () {
//         final now = DateTime.now();
//         final time = now.subtract(const Duration(hours: 3));
//         final result = _formatDate(time);
//         expect(result, contains('小时前'));
//       });

//       test('几天前', () {
//         final now = DateTime.now();
//         final time = now.subtract(const Duration(days: 3));
//         final result = _formatDate(time);
//         expect(result, contains('天前'));
//       });

//       test('超过 7 天显示日期', () {
//         final time = DateTime(2026, 3, 1);
//         final result = _formatDate(time);
//         expect(result, matches(RegExp(r'\d{4}-\d{2}-\d{2}')));
//       });
//     });
//   });
// }

// /// 时间格式化辅助函数（从 _BookmarkTile 复制）
// String _formatDate(DateTime date) {
//   final now = DateTime.now();
//   final difference = now.difference(date);

//   if (difference.inMinutes < 1) {
//     return '刚刚';
//   } else if (difference.inHours == 0) {
//     return '${difference.inMinutes}分钟前';
//   } else if (difference.inDays == 0) {
//     return '${difference.inHours}小时前';
//   } else if (difference.inDays < 7) {
//     return '${difference.inDays}天前';
//   } else {
//     return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
//   }
// }
