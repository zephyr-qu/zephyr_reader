import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/sync/application/storage_sync_view_model.dart';

class StorageSyncPage extends StatefulWidget {
  const StorageSyncPage({super.key});

  @override
  State<StorageSyncPage> createState() => _StorageSyncPageState();
}

class _StorageSyncPageState extends State<StorageSyncPage> {
  final _vm = StorageSyncViewModel();

  @override
  void initState() {
    super.initState();
    _vm.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '存储与同步',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 20),
            onPressed: () => _vm.refresh(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Watch.builder(
        builder: (context) {
          if (_vm.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              _buildStatusHeader(cs),
              const SizedBox(height: 20),
              _buildStorageCard(cs),
              const SizedBox(height: 24),
              _buildSyncConfigSection(cs),
              const SizedBox(height: 24),
              _buildDataManagementSection(cs),
              const SizedBox(height: 24),
              _buildDangerZone(cs),
            ],
          );
        },
      ),
    );
  }

  // ==================== Status Header ====================

  Widget _buildStatusHeader(ColorScheme cs) {
    return Watch.builder(
      builder: (context) {
        final syncing = _vm.isSyncing.value;
        final configured = _vm.isConfigured.value;
        final lastTime = _vm.lastSyncTime.value;

        String statusText;
        if (syncing) {
          statusText = '正在同步…';
        } else if (!configured) {
          statusText = '未配置同步';
        } else if (lastTime == null) {
          statusText = '尚未同步';
        } else {
          statusText = '数据已同步';
        }

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      syncing
                          ? PhosphorIconsRegular.arrowsClockwise
                          : configured
                          ? PhosphorIconsRegular.cloudCheck
                          : PhosphorIconsRegular.cloudSlash,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (lastTime != null)
                          Text(
                            '上次同步：${_formatDateTime(lastTime)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: configured
                        ? () => _triggerSync()
                        : () => context.push(RoutePaths.sync),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        configured ? '立即同步' : '去配置',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '下次自动同步：明天 08:00（仅前台启动时）',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }

  // ==================== Storage Card ====================

  Widget _buildStorageCard(ColorScheme cs) {
    return Watch.builder(
      builder: (context) {
        final total = _vm.totalUsed.value;
        final cache = _vm.cacheSize.value;
        final books = _vm.booksSize.value;
        final db = _vm.dbSize.value;
        final available = _vm.totalAvailable.value;

        final booksPct = total > 0 ? books / total : 0.0;
        final cachePct = total > 0 ? cache / total : 0.0;
        final dbPct = total > 0 ? db / total : 0.0;

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '本地存储',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${_vm.formatBytes(total)} / ${available > 0 ? _vm.formatBytes(available) : '—'}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(
                    children: [
                      if (booksPct > 0.01)
                        Expanded(
                          flex: (booksPct * 100).round().clamp(1, 100),
                          child: Container(color: const Color(0xFF42A5F5)),
                        ),
                      if (dbPct > 0.01)
                        Expanded(
                          flex: (dbPct * 100).round().clamp(1, 100),
                          child: Container(color: const Color(0xFFFFA726)),
                        ),
                      if (cachePct > 0.01)
                        Expanded(
                          flex: (cachePct * 100).round().clamp(1, 100),
                          child: Container(color: const Color(0xFFBDBDBD)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _legendDot(
                    const Color(0xFF42A5F5),
                    '书籍',
                    _vm.formatBytes(books),
                  ),
                  const SizedBox(width: 16),
                  _legendDot(
                    const Color(0xFFFFA726),
                    '数据库',
                    _vm.formatBytes(db),
                  ),
                  const SizedBox(width: 16),
                  _legendDot(
                    const Color(0xFFBDBDBD),
                    '缓存',
                    _vm.formatBytes(cache),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.03, end: 0);
  }

  Widget _legendDot(Color color, String label, String size) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$label $size',
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Sync Config Section ====================

  Widget _buildSyncConfigSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('同步配置', cs),
            _settingsCard([
              _listItem(
                cs,
                icon: const Icon(
                  PhosphorIconsRegular.cloud,
                  size: 16,
                  color: Color(0xFF5C6BC0),
                ),
                iconBg: const Color(0xFFE8EAF6),
                title: 'WebDAV 服务器',
                subtitle: _vm.serverUrl.value.isNotEmpty
                    ? _vm.serverUrl.value
                    : '未配置',
                onTap: () => context.push(RoutePaths.sync),
              ),
              _listItem(
                cs,
                icon: const Icon(
                  PhosphorIconsRegular.clockClockwise,
                  size: 16,
                  color: Color(0xFF00897B),
                ),
                iconBg: const Color(0xFFE0F2F1),
                title: '自动同步策略',
                subtitle: '启动时 + 每日首次打开',
                onTap: () => _showAutoSyncSheet(cs),
              ),
              _listItem(
                cs,
                icon: const Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: 16,
                  color: Color(0xFFEF6C00),
                ),
                iconBg: const Color(0xFFFFF3E0),
                title: '冲突解决偏好',
                subtitle: '始终询问',
                onTap: () => context.push(RoutePaths.syncHistory),
              ),
              _listItem(
                cs,
                icon: const Icon(
                  PhosphorIconsRegular.listBullets,
                  size: 16,
                  color: Color(0xFF66BB6A),
                ),
                iconBg: const Color(0xFFE8F5E9),
                title: '同步历史记录',
                subtitle: '查看最近同步详情',
                onTap: () => context.push(RoutePaths.syncHistory),
              ),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _listItem(
    ColorScheme cs, {
    required Widget icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Data Management Section ====================

  Widget _buildDataManagementSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('数据管理', cs),
            _settingsCard([
              _listItem(
                cs,
                icon: const Icon(
                  PhosphorIconsRegular.upload,
                  size: 16,
                  color: Color(0xFF42A5F5),
                ),
                iconBg: const Color(0xFFE3F2FD),
                title: '手动备份到 WebDAV',
                subtitle: '立即上传全部数据快照',
                onTap: () => context.push(RoutePaths.backupRestore),
              ),
              _listItem(
                cs,
                icon: const Icon(
                  PhosphorIconsRegular.download,
                  size: 16,
                  color: Color(0xFFAB47BC),
                ),
                iconBg: const Color(0xFFF3E5F5),
                title: '从 WebDAV 恢复',
                subtitle: '覆盖本地数据（需谨慎）',
                onTap: () => context.push(RoutePaths.backupRestore),
              ),
              _buildClearCacheItem(cs),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildClearCacheItem(ColorScheme cs) {
    return Watch.builder(
      builder: (context) {
        return InkWell(
          onTap: () => _confirmClearCache(cs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEFF1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.trash,
                    size: 16,
                    color: Color(0xFF78909C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '清理本地缓存',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '释放 ${_vm.cacheSize.value > 0 ? _vm.formatBytes(_vm.cacheSize.value) : '0 B'} · 不影响书籍与笔记',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== Danger Zone ====================

  Widget _buildDangerZone(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                '危险操作',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.error.withValues(alpha: 0.8),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.error.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: InkWell(
                onTap: () => _confirmReset(cs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PhosphorIconsRegular.lightning,
                          size: 16,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '重置所有本地数据',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.error,
                              ),
                            ),
                            Text(
                              '清除全部书籍、笔记、生词本与设置',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.03, end: 0);
  }

  // ==================== Dialogs ====================

  void _confirmClearCache(ColorScheme cs) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('清理缓存'),
        content: Text(
          '将释放 ${_vm.formatBytes(_vm.cacheSize.value)} 空间。'
          '不会影响您的书籍、笔记和生词数据。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _vm.clearCache();
            },
            child: const Text('清理'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(ColorScheme cs) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(PhosphorIconsRegular.warning, size: 20, color: cs.error),
            const SizedBox(width: 8),
            const Text('确认重置', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('此操作将清除全部书籍、笔记、生词本、阅读进度与应用设置。\n\n此操作不可撤销，请慎重。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(ctx);
              _showFinalConfirm(cs);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  void _showFinalConfirm(ColorScheme cs) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('二次确认'),
        content: const Text('请输入 RESET 以确认操作：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  void _showAutoSyncSheet(ColorScheme cs) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '自动同步策略',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _syncOption(cs, '启动时同步', '应用启动时自动执行一次完整同步'),
              const SizedBox(height: 8),
              _syncOption(cs, '每日首次打开', '每天首次打开应用时自动同步'),
              const SizedBox(height: 8),
              _syncOption(cs, '仅手动同步', '不自动同步，仅通过按钮触发'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _syncOption(ColorScheme cs, String title, String desc) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== Sync Action ====================

  Future<void> _triggerSync() async {
    final result = await _vm.triggerSync();
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('同步配置无效，请检查 WebDAV 设置'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success ? '同步成功' : '同步失败：${result.error ?? "未知错误"}',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ==================== Shared Widgets ====================

  Widget _sectionLabel(String label, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 0.5,
                  color: cs.outlineVariant.withValues(alpha: 0.15),
                ),
              children[i],
            ],
          );
        }),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    String prefix;
    if (diff == 0) {
      prefix = '今天';
    } else if (diff == 1) {
      prefix = '昨天';
    } else {
      prefix = '${dt.month}/${dt.day}';
    }
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$prefix $hour:$minute';
  }
}
