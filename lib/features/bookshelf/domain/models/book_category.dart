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
    final colorValue = dbCategory.color;
    final validColor = (colorValue == null || colorValue.toString().isEmpty)
        ? '#FF5722'
        : colorValue.toString();
    return BookCategory(
      id: dbCategory.id ?? 0,
      name: dbCategory.name ?? '',
      color: validColor,
      sortOrder: dbCategory.sortOrder ?? 0,
      isSystem: dbCategory.isSystem ?? false,
      createdAt: dbCategory.createdAt,
      updatedAt: dbCategory.updatedAt,
    );
  }

  /// 获取颜色对象
  Color get colorValue {
    try {
      if (color.isEmpty) {
        return Colors.orange;
      }
      // 处理带 # 前缀的颜色值（如 #FF5722）
      if (color.startsWith('#')) {
        return Color(int.parse('FF${color.substring(1)}', radix: 16));
      }
      // 处理已经是 0xFF 格式的颜色值
      if (color.startsWith('0x')) {
        return Color(int.parse(color.substring(2), radix: 16));
      }
      // 尝试直接解析
      return Color(int.parse(color, radix: 16));
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
