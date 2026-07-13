
## 2026-07-13: WebDAV lastSyncTime 未初始化时返回 epoch

**文件**: `lib/features/data/application/services/webdav_config_service.dart:94`
**问题**: `getLastSyncTime()` 在 `_prefs.getInt(_keyLastSyncTime)` 返回 null 时，
直接 `DateTime.fromMillisecondsSinceEpoch(null)` → 1970-01-01 而非 null。
**测试**: `test/features/sync/webdav_sync_service_test.dart:175` 期望 null，实测 epoch。
**修复方向**: `if (timestamp == null) return null;`

## Pre-existing: paginated_renderer_test 找不到 staging 图片 widget

**文件**: `test/features/reader/page/widgets/paginated_renderer_test.dart`
**问题**: `contentBlocks staging 渲染 Image 占位` 找不到匹配 widget。
可能是渲染逻辑或 mock 数据与当前 PageBlockSlice/image 结构不匹配。非 P6-P8 引入。
