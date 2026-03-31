/// 平板双栏布局组件
library;

/// 用于平板横屏模式下的双栏显示（如：左侧目录，右侧内容library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 双栏布局
class TwoPaneLayout extends HookWidget {
  /// 左侧面板（主列表
  final Widget firstPane;

  /// 右侧面板（详情内容）
  final Widget secondPane;

  /// 面板比例（默0.3
  final double paneProportion;

  /// 最小面板宽
  final double minPaneWidth;

  /// 是否可调整大
  final bool resizable;

  const TwoPaneLayout({
    super.key,
    required this.firstPane,
    required this.secondPane,
    this.paneProportion = 0.3,
    this.minPaneWidth = 200,
    this.resizable = true,
  });

  @override
  Widget build(BuildContext context) {
    final split = useState(paneProportion);

    return Row(
      children: [
        // 左侧面板
        SizedBox(
          width: max(
            minPaneWidth,
            MediaQuery.of(context).size.width * split.value,
          ),
          child: firstPane,
        ),
        // 分隔线（可拖动调整）
        if (resizable)
          _buildSplitter(context, split, minPaneWidth)
        else
          _buildDivider(context),
        // 右侧面板
        Expanded(child: secondPane),
      ],
    );
  }

  Widget _buildSplitter(
    BuildContext context,
    ValueNotifier<double> split,
    double minWidth,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        onPanUpdate: (details) {
          final width = MediaQuery.of(context).size.width;
          final newSplit = (split.value * width + details.delta.dx) / width;
          split.value = newSplit.clamp(0.2, 0.5);
        },
        child: Container(
          width: 4,
          color: Colors.transparent,
          child: VerticalDivider(
            thickness: 1,
            width: 1,
            color: Colors.grey[300],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return VerticalDivider(thickness: 1, width: 1, color: Colors.grey[300]!);
  }

  double max(double a, double b) => a > b ? a : b;
}

/// 平板阅读器布局（左侧目录，右侧阅读
class TabletReaderLayout extends StatelessWidget {
  /// 目录面板
  final Widget catalogPanel;

  /// 阅读内容
  final Widget readerContent;

  /// 目录面板宽度
  final double catalogWidth;

  const TabletReaderLayout({
    super.key,
    required this.catalogPanel,
    required this.readerContent,
    required this.catalogWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左侧目录
        SizedBox(
          width: catalogWidth,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                // 目录标题
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '目录',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                // 目录列表
                Expanded(child: catalogPanel),
              ],
            ),
          ),
        ),
        // 分隔
        VerticalDivider(thickness: 1, width: 1),
        // 右侧阅读
        Expanded(child: readerContent),
      ],
    );
  }
}

/// 主从布局（Master-Detail
class MasterDetailLayout extends StatelessWidget {
  final Widget master;
  final Widget detail;
  final double masterWidth;
  final bool showMasterOnWideScreen;

  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 320,
    this.showMasterOnWideScreen = true,
  });

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 840;

    if (isWideScreen && showMasterOnWideScreen) {
      return Row(
        children: [
          SizedBox(
            width: masterWidth,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: master,
            ),
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(child: detail),
        ],
      );
    } else {
      return detail;
    }
  }
}
