import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/animated_toolbar_panel.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_toolbar.dart';
import 'package:zephyr_reader/features/reader/page/touch/tap_zone.dart';
import 'package:zephyr_reader/features/reader/page/ui/brightness_mask.dart';
import 'package:zephyr_reader/features/reader/page/ui/battery_indicator.dart';

/// 阅读器公共壳层组件。
///
/// 封装了阅读器页面的通用 UI 框架：
/// - [Theme] 包装 + [ReaderThemeExtension] 解析
/// - [PopScope] 返回拦截 + [Scaffold] 外壳
/// - [AnimatedContainer] 自适应背景色
/// - [SafeArea] 包裹内容区
/// - 顶部工具栏（自动隐藏，4 秒无操作后自动收起）
/// - 点击翻页区域（左/中/右三区 + 水平滑动）
/// - [BrightnessMask]（双击循环切换亮度预设档位）
/// - [BatteryIndicator]（底部右端进度提示）
///
/// TXT 引擎和 Readium/EPUB 引擎复用此壳层，避免 UI 代码重复。
/// 只需传入标题、进度、翻页/工具栏回调等即可。
class ReaderChromeShell extends HookWidget {
  const ReaderChromeShell({
    super.key,
    required this.config,
    required this.content,
    required this.title,
    this.progress,
    this.isReady = false,
    this.onPreviousPage,
    this.onNextPage,
    this.onClose,
    this.overlays,
  });

  /// 阅读器全局配置（主题、背景色、翻页布局等）。
  final ReaderConfig config;

  /// 引擎内容组件（如 [ReadiumReaderContent]）。
  final Widget content;

  /// 工具栏标题（仅文本显示，必填）。
  final String title;

  /// 工具栏进度文字（可为空）。
  final String? progress;

  /// 引擎是否已就绪（控制翻页区域显示）。
  final bool isReady;

  /// 上一页/上一章节回调（翻页区域左侧点击 + 右滑）。
  final VoidCallback? onPreviousPage;

  /// 下一页/下一章节回调（翻页区域右侧点击 + 左滑）。
  final VoidCallback? onNextPage;

  /// 自定义返回回调（默认 [context.pop]）。
  final VoidCallback? onClose;

  /// 额外覆盖层，放置在 [Stack] 末尾。
  final List<Widget>? overlays;

  @override
  Widget build(BuildContext context) {
    // ==================== UI 状态信号 ====================

    final Signal<bool> showToolbarSig = useSignal<bool>(false);
    final bool showToolbar = useSignalValue(showToolbarSig) as bool;
    final ObjectRef<Timer?> autoHideTimer = useRef<Timer?>(null);

    // ==================== 主题信号 ====================

    final ReaderTheme readTheme =
        useSignalValue(config.theme.signal) as ReaderTheme;
    final int bgIndex = useSignalValue(config.readerBgColorIndex.signal) as int;
    final double brightness =
        useSignalValue(config.brightnessOverlay) as double;
    final TapLayout tapLayout =
        useSignalValue(config.tapLayout.signal) as TapLayout;

    final ThemeMode themeMode;
    switch (readTheme) {
      case ReaderTheme.dark:
        themeMode = ThemeMode.dark;
      case ReaderTheme.sepia:
      case ReaderTheme.light:
        themeMode = ThemeMode.light;
    }

    final ReaderThemeExtension readerExt = ReaderThemeExtension.resolve(
      readTheme,
    );
    final ThemeData readerData = Theme.of(
      context,
    ).copyWith(extensions: [readerExt]);

    // ==================== 自动隐藏定时器 ====================

    void withTimer(VoidCallback action) {
      action();
      autoHideTimer.value?.cancel();
      if (!context.mounted) return;
      autoHideTimer.value = Timer(const Duration(seconds: 4), () {
        if (!context.mounted) return;
        if (showToolbarSig.value) {
          showToolbarSig.value = false;
        }
      });
    }

    // ==================== 生命周期 ====================

    useEffect(() {
      return () {
        autoHideTimer.value?.cancel();
      };
    }, []);

    // ==================== 渲染 ====================

    return Theme(
      data: readerData,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          autoHideTimer.value?.cancel();
          if (onClose != null) {
            onClose!();
          } else {
            context.pop();
          }
        },
        child: Scaffold(
          body: AnimatedContainer(
            duration: AnimTokens.slow,
            curve: Curves.easeInOut,
            color: readTheme == ReaderTheme.dark
                ? ReaderBgColors.darkBackground
                : ReaderBgColors.presets[bgIndex.clamp(
                    0,
                    ReaderBgColors.presets.length - 1,
                  )],
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // 内容区 + 顶部工具栏（SafeArea）
                SafeArea(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      content,

                      // 顶部工具栏
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedToolbarPanel(
                          visible: showToolbar,
                          slideBeginY: -1,
                          child: ReaderToolbar(
                            title: title,
                            progress: progress ?? '',
                            themeMode: themeMode,
                            onClose: () {
                              autoHideTimer.value?.cancel();
                              if (onClose != null) {
                                onClose!();
                              } else {
                                context.pop();
                              }
                            },
                            onToggleToolbar: () => withTimer(() {
                              showToolbarSig.value = !showToolbarSig.value;
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 点击翻页区域（引擎就绪且工具栏隐藏时显示）
                if (isReady && !showToolbar)
                  TapZone(
                    tapLayout: tapLayout,
                    pageIndex: 0,
                    totalPages: 1,
                    onPreviousPage: () {
                      onPreviousPage?.call();
                      HapticFeedback.lightImpact();
                    },
                    onNextPage: () {
                      onNextPage?.call();
                      HapticFeedback.lightImpact();
                    },
                    onCenterTap: () => withTimer(() {
                      showToolbarSig.value = !showToolbarSig.value;
                      HapticFeedback.selectionClick();
                    }),
                  ),

                // 亮度遮罩层
                BrightnessMask(
                  brightness: brightness,
                  readingMode: ReadingMode.pagination,
                  onDoubleTap: () {
                    const presets = [0.0, 0.3, 0.5, 0.7];
                    final double current = brightness;
                    final int idx = presets.indexWhere(
                      (p) => (p - current).abs() < 0.05,
                    );
                    final int nextIdx = idx == -1
                        ? 0
                        : (idx + 1) % presets.length;
                    config.brightnessOverlay.value = presets[nextIdx];
                  },
                ),

                // 底部进度/电量指示
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: BatteryIndicator(progressText: progress ?? ''),
                ),

                // 额外覆盖层
                ...?overlays,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
