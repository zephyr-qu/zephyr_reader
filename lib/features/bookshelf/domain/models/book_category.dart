import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book_category.freezed.dart';

/// 书籍分类领域模型
@freezed
abstract class BookCategory with _$BookCategory {
  const BookCategory._();

  const factory BookCategory({
    required int id,
    required String name,
    required String color,
    required int sortOrder,
    required bool isSystem,
    required DateTime? createdAt,
    required DateTime? updatedAt,
  }) = _BookCategory;

  /// 从数据库模型转换
  factory BookCategory.fromDb(dynamic dbCategory) {
    return BookCategory(
      id: dbCategory.id ?? 0,
      name: dbCategory.name ?? '',
      color: dbCategory.color ?? '#FF5722',
      sortOrder: dbCategory.sortOrder ?? 0,
      isSystem: dbCategory.isSystem ?? false,
      createdAt: dbCategory.createdAt,
      updatedAt: dbCategory.updatedAt,
    );
  }

  /// 获取颜色对象
  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.orange;
    }
  }

  /// 空分类（用于初始化）
  factory BookCategory.empty() {
    return const BookCategory(
      id: 0,
      name: '',
      color: '#FF5722',
      sortOrder: 0,
      isSystem: false,
      createdAt: null,
      updatedAt: null,
    );
  }
}
