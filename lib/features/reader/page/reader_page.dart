import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:signals_flutter/signals_flutter.dart';

class ReaderPage extends StatefulWidget {
  final int bookId;
  final int chapterId;

  const ReaderPage({
    super.key,
    required this.bookId,
    required this.chapterId,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final vm = getIt<ReaderViewModel>();
  final ScrollController _scrollController = ScrollController();
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadBook();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _saveTimer?.cancel();
    vm.stopReading();
    super.dispose();
  }

  Future<void> _loadBook() async {
    await vm.loadBook(widget.bookId);
    await vm.loadChapter(widget.chapterId);
    vm.startReading();
  }

  void _onScroll() {
    vm.updateScrollPosition(_scrollController.position.pixels);

    // 防抖保存阅读位置
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      vm.stopReading();
      vm.startReading();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Watch.builder(
      builder: (context) {
        final theme = vm.config.theme.value;
        final fontSize = vm.config.fontSize.value;
        final lineHeight = vm.config.lineHeight.value;
        final padding = vm.config.padding.value;

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                _buildContent(theme, fontSize, lineHeight, padding),
                _buildTopBar(theme),
                _buildBottomBar(theme),
                if (vm.showCatalog.value) _buildCatalogPanel(theme),
                if (vm.showSettings.value) _buildSettingsPanel(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(ReaderTheme theme, ReaderFontSize fontSize, double lineHeight, double padding) {
    return GestureDetector(
      onTap: () {
        // 点击中间区域切换菜单
        if (!vm.showCatalog.value && !vm.showSettings.value) {
          // 显示底部菜单
          vm.showSettings.value = true;
        } else {
          vm.showCatalog.value = false;
          vm.showSettings.value = false;
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.all(padding),
        child: Watch.builder(
          builder: (context) {
            final async = vm.chapterContent.value;

            if (async.isLoading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(100),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (async.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(100),
                  child: Column(
                    children: [
                      Text('加载失败: ${async.error}', style: TextStyle(color: theme.textColor)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => vm.loadChapter(vm.chapterIndex.value),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final content = async.value ?? '';

            return Text(
              content,
              style: TextStyle(
                fontSize: fontSize.size,
                height: lineHeight,
                color: theme.textColor,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(ReaderTheme theme) {
    return Watch.builder(
      builder: (context) {
        if (!vm.showSettings.value) return const SizedBox.shrink();

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: theme.backgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: theme.textColor),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    '第 ${vm.chapterIndex.value} 章',
                    style: TextStyle(color: theme.textColor),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.bookmark_border, color: theme.textColor),
                  onPressed: () => _showAddBookmarkDialog(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(ReaderTheme theme) {
    return Watch.builder(
      builder: (context) {
        if (!vm.showSettings.value) return const SizedBox.shrink();

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: theme.backgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('进度: ${vm.progressText}', style: TextStyle(color: theme.textColor, fontSize: 12)),
                    const Spacer(),
                    Text('${vm.readingDuration.value ~/ 60}分${vm.readingDuration.value % 60}秒',
                        style: TextStyle(color: theme.textColor, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildIconButton(Icons.list, '目录', vm.toggleCatalog, theme),
                    _buildIconButton(Icons.settings, '设置', vm.toggleSettings, theme),
                    _buildIconButton(Icons.arrow_back_ios, '上一章', vm.previousChapter, theme),
                    _buildIconButton(Icons.arrow_forward_ios, '下一章', vm.nextChapter, theme),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconButton(IconData icon, String label, VoidCallback onTap, ReaderTheme theme) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.textColor),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: theme.textColor, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildCatalogPanel(ReaderTheme theme) {
    return Watch.builder(
      builder: (context) {
        final async = vm.chapters.value;

        if (!vm.showCatalog.value) return const SizedBox.shrink();

        return Container(
          color: theme.backgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('目录', style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.textColor),
                        onPressed: () => vm.showCatalog.value = false,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: async.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : async.hasError
                          ? Center(child: Text('加载失败: ${async.error}', style: TextStyle(color: theme.textColor)))
                          : ListView.builder(
                              itemCount: async.value?.length ?? 0,
                              itemBuilder: (context, index) {
                                final chapter = async.value![index];
                                final isCurrent = chapter.chapterIndex == vm.chapterIndex.value;
                                return ListTile(
                                  title: Text(
                                    chapter.title,
                                    style: TextStyle(
                                      color: isCurrent ? theme.backgroundColor : theme.textColor,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  onTap: () => vm.jumpToChapter(chapter.chapterIndex),
                                  tileColor: isCurrent ? theme.textColor.withValues(alpha: .1) : null,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsPanel(ReaderTheme theme) {
    return Watch.builder(
      builder: (context) {
        if (!vm.showSettings.value) return const SizedBox.shrink();

        return Container(
          color: theme.backgroundColor,
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text('设置', style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.textColor),
                        onPressed: () => vm.showSettings.value = false,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildThemeSelector(theme),
                      const SizedBox(height: 24),
                      _buildFontSizeSelector(theme),
                      const SizedBox(height: 24),
                      _buildLineHeightSlider(theme),
                      const SizedBox(height: 24),
                      _buildPaddingSlider(theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThemeSelector(ReaderTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题', style: TextStyle(color: theme.textColor, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ReaderTheme.values.map((t) {
            final isSelected = t.id == vm.config.theme.value.id;
            return FilterChip(
              label: Text(t.displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  vm.config.setTheme(t);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFontSizeSelector(ReaderTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('字体大小', style: TextStyle(color: theme.textColor, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: ReaderFontSize.values.map((size) {
            final isSelected = size.size == vm.config.fontSize.value.size;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  label: Text(size.displayName, textAlign: TextAlign.center),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      vm.config.setFontSize(size);
                    }
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLineHeightSlider(ReaderTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('行间距: ${vm.config.lineHeight.value.toStringAsFixed(1)}', style: TextStyle(color: theme.textColor, fontSize: 16)),
        Slider(
          value: vm.config.lineHeight.value,
          min: 1.2,
          max: 2.5,
          divisions: 13,
          onChanged: (value) {
            vm.config.setLineHeight(value);
          },
        ),
      ],
    );
  }

  Widget _buildPaddingSlider(ReaderTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('页边距: ${vm.config.padding.value.toInt()}', style: TextStyle(color: theme.textColor, fontSize: 16)),
        Slider(
          value: vm.config.padding.value,
          min: 8,
          max: 32,
          divisions: 12,
          onChanged: (value) {
            vm.config.setPadding(value);
          },
        ),
      ],
    );
  }

  void _showAddBookmarkDialog() {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加书签'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: '备注（可选）',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final success = await vm.addBookmark(noteController.text.isEmpty ? null : noteController.text);
              if (success && mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('书签添加成功')),
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}