library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';
import 'package:zephyr_reader/features/profile/page/widgets/backup_dialog.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

class AppSettingsPage extends StatefulHookWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> with SignalsMixin {
  static const _kRadius8 = BorderRadius.all(Radius.circular(8));
  late final cacheSize = createSignal<String>('计算中...');
  late final isClearing = createSignal(false);
  late final isBackingUp = createSignal(false);
  late final isRestoring = createSignal(false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    try {
      final bytes = await CacheUtils.getCacheSize();
      cacheSize.value = CacheUtils.formatCacheSize(bytes);
    } catch (e) {
      cacheSize.value = '未知';
    }
  }

  Future<void> _clearCache() async {
    isClearing.value = true;
    try {
      final bytes = await CacheUtils.clearCache();
      final sizeText = CacheUtils.formatCacheSize(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已清理 $sizeText 缓存'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadCacheSize();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('清理缓存失败'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isClearing.value = false;
    }
  }

  Future<void> _createBackup() async {
    final selectedTypes = await _showBackupTypeDialog();
    if (selectedTypes == null || selectedTypes.isEmpty) return;
    isBackingUp.value = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${dir.path}/backup_$timestamp.db';
      await exportDatabase(destPath: destPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份已保存: $destPath'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isBackingUp.value = false;
    }
  }

  Future<void> _restoreBackup() async {
    isRestoring.value = true;
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) {
        isRestoring.value = false;
        return;
      }
      final filePath = result.files.single.path;
      if (filePath == null) {
        isRestoring.value = false;
        return;
      }
      await restoreDatabase(backupPath: filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据恢复成功，请重启应用'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢复失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isRestoring.value = false;
    }
  }

  Future<List<BackupType>?> _showBackupTypeDialog() async {
    final selectedTypes = <BackupType>[BackupType.all];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('选择备份内容'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...BackupType.values.map((type) {
                  final isSelected = selectedTypes.contains(type);
                  return CheckboxListTile(
                    title: Text(_getBackupTypeName(type)),
                    value: isSelected,
                    onChanged: (value) {
                      if (value == true) {
                        if (type == BackupType.all) {
                          selectedTypes.clear();
                          selectedTypes.add(BackupType.all);
                        } else {
                          selectedTypes.remove(BackupType.all);
                          if (!selectedTypes.contains(type)) {
                            selectedTypes.add(type);
                          }
                        }
                      } else {
                        selectedTypes.remove(type);
                        if (selectedTypes.isEmpty) {
                          selectedTypes.add(BackupType.all);
                        }
                      }
                      setDialogState(() {});
                    },
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    if (result == true) return selectedTypes;
    return null;
  }

  String _getBackupTypeName(BackupType type) {
    switch (type) {
      case BackupType.all:
        return '全部数据';
      case BackupType.readingProgress:
        return '阅读进度';
      case BackupType.bookmarks:
        return '书签';
      case BackupType.bookshelf:
        return '书架';
      case BackupType.settings:
        return '设置';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tm = ThemeManager.instance;
    final themeMode = useSignal(tm.themeType.value.index);
    final localeCode = tm.locale.value;
    final language = useSignal(
      localeCode == null ? 0 : (localeCode == 'zh' ? 1 : 2),
    );
    final autoSync = useSignal(false);
    final syncInterval = useSignal(0);
    final pagePadding = LayoutBreakpoints.getPagePadding(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            title: Text('应用设置'),
            elevation: 0,
            scrolledUnderElevation: 2,
          ),
          SliverPadding(
            padding: pagePadding,
            sliver: SliverToBoxAdapter(
              child: _buildContent(
                context,
                theme,
                themeMode,
                language,
                autoSync,
                syncInterval,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    Signal<int> themeMode,
    Signal<int> language,
    Signal<bool> autoSync,
    Signal<int> syncInterval,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHero(context),
        const SizedBox(height: 28),
        _buildSection(
          context,
          icon: PhosphorIconsRegular.palette,
          title: '主题与外观',
          index: 0,
          children: [_buildThemeSelector(context, themeMode)],
        ),
        const SizedBox(height: 20),
        _buildSection(
          context,
          icon: PhosphorIconsRegular.globe,
          title: '语言与地区',
          index: 1,
          children: [
            _buildLanguageSelector(context, language),
            _buildSeparator(),
            _buildRegionSelector(context),
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          context,
          icon: PhosphorIconsRegular.arrowsClockwise,
          title: '同步设置',
          index: 2,
          children: [
            _buildSwitchSetting(
              context,
              icon: PhosphorIconsRegular.sparkle,
              title: '自动同步',
              subtitle: '定期同步阅读进度和书架',
              value: autoSync.value,
              onChanged: (v) => autoSync.value = v,
            ),
            _buildSeparator(),
            _buildSyncFrequencySelector(context, syncInterval),
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          context,
          icon: PhosphorIconsRegular.hardDrives,
          title: '存储管理',
          index: 3,
          children: [
            _buildCacheCleaner(context),
            _buildSeparator(),
            _buildStorageLocationSelector(context),
          ],
        ),
        const SizedBox(height: 20),
        _buildSection(
          context,
          icon: PhosphorIconsRegular.cloudArrowUp,
          title: '备份与恢复',
          index: 4,
          children: [
            _buildBackupItem(
              context,
              icon: PhosphorIconsRegular.cloudArrowUp,
              iconColor: DesignTokens.warmAccent,
              title: '备份数据',
              subtitle: '备份书架、阅读进度和设置',
              isLoading: isBackingUp.value,
              onTap: _createBackup,
            ),
            _buildSeparator(),
            _buildBackupItem(
              context,
              icon: PhosphorIconsRegular.cloudArrowDown,
              iconColor: theme.colorScheme.tertiary,
              title: '恢复数据',
              subtitle: '从备份文件恢复数据',
              isLoading: isRestoring.value,
              onTap: _restoreBackup,
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildFooter(context),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            PhosphorIconsRegular.sliders,
            size: 28,
            color: DesignTokens.warmAccent,
          ),
          const SizedBox(height: 12),
          Text(
            '应用设置',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '定制你的阅读体验',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
    required int index,
  }) {
    final theme = Theme.of(context);
    return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: DesignTokens.warmAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(icon, size: 18, color: DesignTokens.warmAccent),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...children,
              const SizedBox(height: 6),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 80).ms)
        .slideY(begin: 0.08, end: 0);
  }

  Widget _buildSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 0.5,
      color: const Color(0xFFE5E5EA).withValues(alpha: 0.5),
    );
  }

  Widget _buildThemeSelector(BuildContext context, Signal<int> themeMode) {
    final theme = Theme.of(context);
    final options = [
      {'label': '跟随系统', 'icon': PhosphorIconsRegular.circleHalf},
      {'label': '浅色模式', 'icon': PhosphorIconsRegular.sun},
      {'label': '深色模式', 'icon': PhosphorIconsRegular.moon},
      {'label': '纯黑模式', 'icon': PhosphorIconsRegular.moonStars},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = themeMode.value == index;
          return GestureDetector(
            onTap: () {
              themeMode.value = index;
              ThemeManager.instance.setThemeType(AppThemeType.values[index]);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? DesignTokens.warmAccentLight
                    : Colors.transparent,
                borderRadius: _kRadius8,
                border: Border.all(
                  color: isSelected
                      ? DesignTokens.warmAccent
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    option['icon'] as IconData,
                    size: 16,
                    color: isSelected
                        ? DesignTokens.warmAccent
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    option['label'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? DesignTokens.warmAccent
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, Signal<int> language) {
    final theme = Theme.of(context);
    final options = [
      {'label': '跟随系统', 'flag': '🌐'},
      {'label': '简体中文', 'flag': '🇨🇳'},
      {'label': 'English', 'flag': '🇺🇸'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = language.value == index;
          return Material(
            color: isSelected
                ? DesignTokens.warmAccentLight
                : Colors.transparent,
            borderRadius: _kRadius8,
            child: InkWell(
              onTap: () {
                language.value = index;
                final code = index == 0 ? null : (index == 1 ? 'zh' : 'en');
                ThemeManager.instance.setLocale(code);
              },
              borderRadius: _kRadius8,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Text(
                      option['flag'] as String,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        color: isSelected
                            ? DesignTokens.warmAccent
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(
                        PhosphorIconsBold.check,
                        size: 18,
                        color: DesignTokens.warmAccent,
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRegionSelector(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: DesignTokens.warmAccentLight,
            borderRadius: _kRadius8,
          ),
          child: const Center(
            child: Text('🇨🇳', style: TextStyle(fontSize: 18)),
          ),
        ),
        title: Text(
          '地区',
          style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        ),
        subtitle: Text(
          '中国大陆',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          PhosphorIconsLight.caretRight,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        onTap: () async {
          final regions = [
            {'code': 'CN', 'name': '中国大陆', 'flag': '🇨🇳'},
            {'code': 'HK', 'name': '中国香港', 'flag': '🇭🇰'},
            {'code': 'TW', 'name': '中国台湾', 'flag': '🇹🇼'},
            {'code': 'US', 'name': '美国', 'flag': '🇺🇸'},
            {'code': 'GB', 'name': '英国', 'flag': '🇬🇧'},
            {'code': 'JP', 'name': '日本', 'flag': '🇯🇵'},
            {'code': 'KR', 'name': '韩国', 'flag': '🇰🇷'},
            {'code': 'SG', 'name': '新加坡', 'flag': '🇸🇬'},
            {'code': 'MY', 'name': '马来西亚', 'flag': '🇲🇾'},
          ];
          final selectedRegion = await showDialog<Map<String, String>>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('选择地区'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return ListTile(
                      leading: Text(
                        region['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(region['name']!),
                      onTap: () => Navigator.pop(context, region),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ],
            ),
          );
          await _handleRegionSelection(selectedRegion);
        },
      ),
    );
  }

  Future<void> _handleRegionSelection(
    Map<String, String>? selectedRegion,
  ) async {
    if (selectedRegion == null) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('地区已更改为：${selectedRegion['name']}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSyncFrequencySelector(
    BuildContext context,
    Signal<int> syncInterval,
  ) {
    final theme = Theme.of(context);
    final options = [
      {'label': '手动同步', 'icon': PhosphorIconsRegular.arrowsCounterClockwise},
      {'label': '每天一次', 'icon': PhosphorIconsRegular.arrowsClockwise},
      {'label': '每周一次', 'icon': PhosphorIconsRegular.calendar},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await showModalBottomSheet<int>(
              context: context,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    return ListTile(
                      leading: Icon(
                        option['icon'] as IconData,
                        color: DesignTokens.warmAccent,
                      ),
                      title: Text(option['label'] as String),
                      trailing: syncInterval.value == index
                          ? const Icon(
                              PhosphorIconsBold.check,
                              size: 18,
                              color: DesignTokens.warmAccent,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, index),
                    );
                  }).toList(),
                ),
              ),
            );
            if (result != null) syncInterval.value = result;
          },
          borderRadius: _kRadius8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: DesignTokens.warmAccentLight,
                    borderRadius: _kRadius8,
                  ),
                  child: Icon(
                    options[syncInterval.value]['icon'] as IconData,
                    color: DesignTokens.warmAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    options[syncInterval.value]['label'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  PhosphorIconsLight.caretRight,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCacheCleaner(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: DesignTokens.warmAccentLight,
            borderRadius: _kRadius8,
          ),
          child: const Icon(
            PhosphorIconsRegular.broom,
            color: DesignTokens.warmAccent,
            size: 18,
          ),
        ),
        title: Text(
          '清理缓存',
          style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        ),
        subtitle: Text(
          cacheSize.value,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isClearing.value
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DesignTokens.warmAccent,
                ),
              )
            : Icon(
                PhosphorIconsLight.caretRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
        onTap: isClearing.value ? null : _clearCache,
      ),
    );
  }

  Widget _buildStorageLocationSelector(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: DesignTokens.warmAccentLight,
            borderRadius: _kRadius8,
          ),
          child: const Icon(
            PhosphorIconsRegular.folder,
            color: DesignTokens.warmAccent,
            size: 18,
          ),
        ),
        title: Text(
          '书籍存储位置',
          style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        ),
        subtitle: const Text(
          '内部存储/Documents/ZephyrReader/books',
          style: TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          PhosphorIconsLight.caretRight,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        onTap: () => _showStorageLocationDialog(context),
      ),
    );
  }

  Future<void> _showStorageLocationDialog(BuildContext context) async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('书籍存储位置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: DesignTokens.warmAccentLight,
                borderRadius: _kRadius8,
              ),
              child: const Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.folder,
                    size: 18,
                    color: DesignTokens.warmAccent,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '内部存储/Documents/ZephyrReader/books',
                      style: TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '说明',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '由于 Android 系统限制，应用只能访问其私有目录。书籍文件存储在应用私有目录中，卸载应用时会被清除。如需备份，请使用 WebDAV 同步功能。',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: _kRadius8,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              )
            : Icon(
                PhosphorIconsLight.caretRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
        onTap: isLoading ? null : onTap,
      ),
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData? icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: icon != null
            ? Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: DesignTokens.warmAccentLight,
                  borderRadius: _kRadius8,
                ),
                child: Icon(icon, color: DesignTokens.warmAccent, size: 18),
              )
            : null,
        title: Text(
          title,
          style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: DesignTokens.warmAccent.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              color: DesignTokens.warmAccent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Icon(
            PhosphorIconsRegular.bookOpen,
            size: 32,
            color: DesignTokens.warmAccent.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            'Zephyr Reader',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '版本 1.0.0',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
