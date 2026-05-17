/// 同步历史页面
///
/// 显示同步历史记录和统计信息
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

import '../application/services/webdav_sync_service.dart';

/// 同步历史页面
class SyncHistoryPage extends HookWidget {
  const SyncHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = useMemoized(() => AdvancedWebDavSyncService());
    final history = useState<List<SyncHistoryRecord>>([]);
    final selectedFilter = useState<SyncStatus?>(null);

    useEffect(() {
      _loadHistory(syncService, history);
      return null;
    }, []);

    final filteredHistory = selectedFilter.value == null
        ? history.value
        : history.value
              .where(
                (h) =>
                    h.result.success ==
                    (selectedFilter.value == SyncStatus.success),
              )
              .toList();

    final stats = _calculateStats(history.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadHistory(syncService, history),
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _clearHistory(syncService, context, history),
            tooltip: '清除历史',
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计卡片
          _buildStatsCard(stats),
          // 筛选器
          _buildFilterBar(selectedFilter),
          // 历史列表
          Expanded(
            child: filteredHistory.isEmpty
                ? _buildEmptyState()
                : _buildHistoryList(filteredHistory),
          ),
        ],
      ),
    );
  }

  Future<void> _loadHistory(
    AdvancedWebDavSyncService syncService,
    ValueNotifier<List<SyncHistoryRecord>> history,
  ) async {
    final historyList = syncService.getHistory(limit: 100);
    history.value = historyList;
  }

  Widget _buildStatsCard(SyncStats stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem(
              Icons.check_circle,
              Colors.green,
              stats.successCount.toString(),
              '成功',
            ),
            _buildStatItem(
              Icons.error,
              Colors.red,
              stats.failedCount.toString(),
              '失败',
            ),
            _buildStatItem(
              Icons.upload_file,
              Colors.blue,
              _formatBytes(stats.totalUploaded),
              '上传',
            ),
            _buildStatItem(
              Icons.download,
              Colors.orange,
              _formatBytes(stats.totalDownloaded),
              '下载',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    Color color,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildFilterBar(ValueNotifier<SyncStatus?> selectedFilter) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('筛选：'),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('全部'),
            selected: selectedFilter.value == null,
            onSelected: (selected) {
              if (selected) {
                selectedFilter.value = null;
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('成功'),
            selected: selectedFilter.value == SyncStatus.success,
            onSelected: (selected) {
              selectedFilter.value = selected ? SyncStatus.success : null;
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('失败'),
            selected: selectedFilter.value == SyncStatus.failed,
            onSelected: (selected) {
              selectedFilter.value = selected ? SyncStatus.failed : null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '暂无同步历史',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<SyncHistoryRecord> history) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = history[index];
        return _buildHistoryCard(record);
      },
    );
  }

  Widget _buildHistoryCard(SyncHistoryRecord record) {
    final isSuccess = record.result.success;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getDirectionName(record.direction),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatDateTime(record.startTime),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(Icons.access_time, record.formattedDuration),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.upload_file, '${record.uploadedCount} 上传'),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.download, '${record.downloadedCount} 下载'),
              ],
            ),
            if (record.changedFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: record.changedFiles
                    .map(
                      (file) => Chip(
                        label: Text(file, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (!isSuccess && record.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Future<void> _clearHistory(
    AdvancedWebDavSyncService syncService,
    BuildContext context,
    ValueNotifier<List<SyncHistoryRecord>> history,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除'),
        content: const Text('确定要清空所有同步历史记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await syncService.clearHistory();
    history.value = [];

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('历史记录已清除'), backgroundColor: Colors.green),
    );
  }

  SyncStats _calculateStats(List<SyncHistoryRecord> history) {
    int successCount = 0;
    int failedCount = 0;
    int totalUploaded = 0;
    int totalDownloaded = 0;

    for (final record in history) {
      if (record.result.success) {
        successCount++;
      } else {
        failedCount++;
      }
      totalUploaded += record.uploadedBytes;
      totalDownloaded += record.downloadedBytes;
    }

    return SyncStats(
      successCount: successCount,
      failedCount: failedCount,
      totalUploaded: totalUploaded,
      totalDownloaded: totalDownloaded,
    );
  }

  String _getDirectionName(SyncDirection direction) {
    switch (direction) {
      case SyncDirection.upload:
        return '上传';
      case SyncDirection.download:
        return '下载';
      case SyncDirection.both:
        return '双向同步';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// 同步统计
class SyncStats {
  final int successCount;
  final int failedCount;
  final int totalUploaded;
  final int totalDownloaded;

  SyncStats({
    required this.successCount,
    required this.failedCount,
    required this.totalUploaded,
    required this.totalDownloaded,
  });
}
