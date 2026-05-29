import 'package:flutter/material.dart';

void showWebDavHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('WebDAV 同步帮助'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '什么是 WebDAV 同步',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('WebDAV 同步功能可以将您的阅读进度、书签、书架等数据同步到云端存储，实现多设备间的数据同步'),
            SizedBox(height: 16),
            Text('如何配置', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. 选择一个 WebDAV 服务提供商（如坚果云）'),
            Text('2. 获取 WebDAV 服务器地址、用户名和密码'),
            Text('3. 在配置页面填写相关信息'),
            Text('4. 点击"测试连接"验证配置'),
            SizedBox(height: 16),
            Text('同步说明', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('上传：将本地数据上传到服务器'),
            Text('下载：从服务器下载数据到本地'),
            Text('双向同步：自动处理冲突，保持数据一致'),
            SizedBox(height: 16),
            Text(
              '注意事项',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 8),
            Text('首次使用建议先上传本地数据', style: TextStyle(color: Colors.red)),
            Text('同步前请确保网络连接稳定', style: TextStyle(color: Colors.red)),
            Text(
              '如遇冲突，系统会自动处理，但建议定期检查同步状态',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
