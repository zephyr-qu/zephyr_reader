import 'package:flutter/material.dart';

/// 阅读统计组件
class ReadingStats extends StatelessWidget {
  final int totalDuration; // 总阅读时长（秒）
  final int totalWords; // 总阅读字数
  final int chaptersRead; // 已读章节数
  final int totalChapters; // 总章节数

  const ReadingStats({
    super.key,
    required this.totalDuration,
    required this.totalWords,
    required this.chaptersRead,
    required this.totalChapters,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '阅读统计',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatItem('阅读时长', _formatDuration(totalDuration), Icons.access_time),
            const SizedBox(height: 12),
            _buildStatItem('阅读字数', '$totalWords 字', Icons.text_fields),
            const SizedBox(height: 12),
            _buildStatItem('阅读进度', '$chaptersRead / $totalChapters 章', Icons.menu_book),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds 秒';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes 分钟';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '$hours 小时 $minutes 分钟';
    }
  }
}