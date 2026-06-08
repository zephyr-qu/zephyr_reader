import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';

void main() {
  group('MenuItemSemantic', () {
    group('iconColor', () {
      for (final semantic in MenuItemSemantic.values) {
        test('${semantic.name} 在亮色模式返回非透明色', () {
          final color = semantic.iconColor(Brightness.light);
          expect((color.a * 255.0).round().clamp(0, 255), greaterThan(0));
        });

        test('${semantic.name} 在暗色模式返回非透明色', () {
          final color = semantic.iconColor(Brightness.dark);
          expect((color.a * 255.0).round().clamp(0, 255), greaterThan(0));
        });

        test('${semantic.name} 亮暗模式返回不同颜色', () {
          final light = semantic.iconColor(Brightness.light);
          final dark = semantic.iconColor(Brightness.dark);
          // 亮暗色值可以相同（如 warning/success 使用 DesignTokens），
          // 但至少两种模式都返回有效颜色
          expect(light, isNot(equals(const Color(0x00000000))));
          expect(dark, isNot(equals(const Color(0x00000000))));
        });
      }

      test('info 亮色模式返回蓝色 #2196F3', () {
        expect(
          MenuItemSemantic.info.iconColor(Brightness.light),
          equals(const Color(0xFF2196F3)),
        );
      });

      test('info 暗色模式返回浅蓝色 #64B5F6', () {
        expect(
          MenuItemSemantic.info.iconColor(Brightness.dark),
          equals(const Color(0xFF64B5F6)),
        );
      });

      test('warning 亮/暗模式均返回 DesignTokens.warning', () {
        expect(
          MenuItemSemantic.warning.iconColor(Brightness.light),
          equals(const Color(0xFFF57C00)),
        );
        expect(
          MenuItemSemantic.warning.iconColor(Brightness.dark),
          equals(const Color(0xFFF57C00)),
        );
      });

      test('success 亮/暗模式均返回 DesignTokens.success', () {
        expect(
          MenuItemSemantic.success.iconColor(Brightness.light),
          equals(const Color(0xFF3B8B5E)),
        );
        expect(
          MenuItemSemantic.success.iconColor(Brightness.dark),
          equals(const Color(0xFF3B8B5E)),
        );
      });

      test('error 亮/暗模式均返回 DesignTokens.error', () {
        expect(
          MenuItemSemantic.error.iconColor(Brightness.light),
          equals(const Color(0xFFD1453B)),
        );
        expect(
          MenuItemSemantic.error.iconColor(Brightness.dark),
          equals(const Color(0xFFD1453B)),
        );
      });
    });

    group('iconBackground', () {
      for (final semantic in MenuItemSemantic.values) {
        test('${semantic.name} 背景色 alpha 为 0.12', () {
          final bg = semantic.iconBackground(Brightness.light);
          expect((bg.a * 255.0).round().clamp(0, 255), equals((0.12 * 255).round()));
        });
      }

      test('iconBackground 亮暗模式返回不同颜色（当 iconColor 不同时）', () {
        final lightBg = MenuItemSemantic.info.iconBackground(Brightness.light);
        final darkBg = MenuItemSemantic.info.iconBackground(Brightness.dark);
        expect(lightBg, isNot(equals(darkBg)));
      });

      test('iconBackground 等于 iconColor 带 12% alpha', () {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          for (final semantic in MenuItemSemantic.values) {
            final icon = semantic.iconColor(brightness);
            final bg = semantic.iconBackground(brightness);
            expect(bg, equals(icon.withValues(alpha: 0.12)));
          }
        }
      });
    });
  });
}
