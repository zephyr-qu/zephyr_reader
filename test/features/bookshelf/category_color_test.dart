// test/features/bookshelf/category_color_test.dart
//
// CategoryColor extension — hex 颜色解析（纯 Dart，无 FFI）

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/bookshelf/page/category_management_page.dart';
import 'package:zephyr_reader/src/rust/domain/category/models.dart';

void main() {
  group('CategoryColor.colorValue', () {
    // ── 空值/边界 ──
    test('empty color returns null', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, isNull);
    });

    test('blank color returns null', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '  ',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, isNull);
    });

    // ── 6 位 hex ──
    test('6-digit hex with # prefix', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#FF5722',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, equals(const Color(0xFFFF5722)));
    });

    test('6-digit hex without # prefix', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: 'FF5722',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, equals(const Color(0xFFFF5722)));
    });

    test('lowercase 6-digit hex', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#ff5722',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, equals(const Color(0xFFFF5722)));
    });

    test('mixed case 6-digit hex', () => _assertColor('#fF57aA', 0xFFfF57aA));

    // ── 8 位 hex（带 alpha）──
    test('8-digit hex with # prefix', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#80FF5722',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, equals(const Color(0x80FF5722)));
    });

    test('8-digit hex preserves alpha channel', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#00FFFFFF',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, equals(const Color(0x00FFFFFF)));
    });

    // ── 无效格式 ──
    test('5-digit hex returns null', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#FFFFF',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, isNull);
    });

    test('7-digit hex returns null', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#FFFFFFF',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, isNull);
    });

    test('9-digit hex returns null', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#FFFFFFFFF',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, isNull);
    });

    test('non-hex characters returns null', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#GGGGGG',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, isNull);
    });

    test('just hash returns null', () {
      final cat = const Category(
        id: '1',
        name: 't',
        description: null,
        color: '#',
        sortOrder: 0,
        isSystem: false,
      );
      expect(cat.colorValue, isNull);
    });
  });
}

/// Helper: 简洁断言
void _assertColor(String hex, int expected) {
  final cat = Category(
    id: '1',
    name: 't',
    description: null,
    color: hex,
    sortOrder: 0,
    isSystem: false,
  );
  expect(cat.colorValue, equals(Color(expected)));
}
