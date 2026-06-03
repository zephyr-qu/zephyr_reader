import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';

void main() {
  group('adaptiveScrollPhysics', () {
    testWidgets('iOS 平台返回 BouncingScrollPhysics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) {
              final physics = adaptiveScrollPhysics(context);
              expect(physics, isA<BouncingScrollPhysics>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('macOS 平台返回 BouncingScrollPhysics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: Builder(
            builder: (context) {
              final physics = adaptiveScrollPhysics(context);
              expect(physics, isA<BouncingScrollPhysics>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('Android 平台返回 ClampingScrollPhysics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (context) {
              final physics = adaptiveScrollPhysics(context);
              expect(physics, isA<ClampingScrollPhysics>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('Linux 平台返回 ClampingScrollPhysics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: Builder(
            builder: (context) {
              final physics = adaptiveScrollPhysics(context);
              expect(physics, isA<ClampingScrollPhysics>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('Windows 平台返回 ClampingScrollPhysics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Builder(
            builder: (context) {
              final physics = adaptiveScrollPhysics(context);
              expect(physics, isA<ClampingScrollPhysics>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('fuchsia 平台返回 ClampingScrollPhysics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.fuchsia),
          home: Builder(
            builder: (context) {
              final physics = adaptiveScrollPhysics(context);
              expect(physics, isA<ClampingScrollPhysics>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('parent physics 被正确传递', (tester) async {
      const parent = NeverScrollableScrollPhysics();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Builder(
            builder: (context) {
              final physics = adaptiveScrollPhysics(context, physics: parent);
              expect(physics, isA<BouncingScrollPhysics>());
              // BouncingScrollPhysics 的 parent 应为我们传入的 physics
              expect((physics as BouncingScrollPhysics).parent, same(parent));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
