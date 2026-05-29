import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/features/sync/application/services/sync_models.dart';
import 'package:zephyr_reader/features/sync/application/services/webdav_sync_service.dart';
import 'package:zephyr_reader/features/sync/page/conflict_resolution_page.dart';

Future<void> showWebDavConflictsDialog(
  BuildContext context,
  WebDavSyncService syncService,
  List<ConflictInfo> conflicts,
) async {
  final result = await showDialog<List<ConflictInfo>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(PhosphorIconsFill.warning, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Text('需要同步冲突 (${conflicts.length})'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: conflicts.length,
          itemBuilder: (context, index) {
            final conflict = conflicts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  PhosphorIconsFill.warning,
                  color: Colors.orange.shade700,
                ),
                title: Text(_getDataTypeName(conflict.dataType)),
                subtitle: Text(conflict.description),
                trailing: conflict.autoResolution != null
                    ? Chip(
                        label: Text(
                          _getResolutionName(conflict.autoResolution!),
                        ),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                        ),
                      )
                    : null,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后处理'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(conflicts),
          child: const Text('解决冲突'),
        ),
      ],
    ),
  );

  if (result != null && result.isNotEmpty) {
    for (final conflict in result) {
      if (!context.mounted) break;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ConflictResolutionPage(
            syncService: syncService,
            conflictInfo: conflict,
          ),
        ),
      );
    }
  }
}

String _getDataTypeName(SyncDataType type) {
  switch (type) {
    case SyncDataType.readingProgress:
      return '阅读进度';
    case SyncDataType.bookmarks:
      return '书签';
    case SyncDataType.bookshelf:
      return '书架';
    case SyncDataType.settings:
      return '设置';
  }
}

String _getResolutionName(ConflictResolution resolution) {
  switch (resolution) {
    case ConflictResolution.useLocal:
      return '使用本地';
    case ConflictResolution.useRemote:
      return '使用远程';
    case ConflictResolution.merge:
      return '合并';
  }
}
