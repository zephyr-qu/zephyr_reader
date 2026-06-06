/// 隐私政策页面
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/profile/page/widgets/legal_section_card.dart';

/// 隐私政策页面
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('隐私政策')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const LegalSectionCard(
            title: '1. 信息收集',
            content: [
              '本应用采用最小化信息收集原则。',
              '本应用不收集任何个人敏感信息，包括但不限于：姓名、电话号码、邮箱地址、位置信息等。',
              '本应用仅在本地存储以下必要数据：',
              '  • 书架数据：您添加的书籍信息',
              '  • 阅读进度：您的阅读位置、书签',
              '  • 阅读统计：阅读时长、阅读书籍数量',
              '  • 应用设置：主题偏好、语言设置等',
            ],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '2. 信息使用',
            content: [
              '本应用收集的信息仅用于以下目的：',
              '  • 提供阅读服务：保存您的阅读进度和书签',
              '  • 改善用户体验：记录阅读统计信息',
              '  • 个性化设置：保存您的应用偏好设置',
              '  • 数据同步：通过 WebDAV 实现跨设备同步（可选功能）',
            ],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '3. 信息存储',
            content: [
              '本应用所有数据均存储在您的设备本地。',
              '数据存储在应用私有目录中，其他应用默认无法访问。',
              '您可以在应用的「数据管理」页面查看和清除本地数据。',
              '卸载应用时，所有本地数据将被清除。',
            ],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '4. 信息共享',
            content: [
              '本应用不会向任何第三方共享您的个人信息。',
              '本应用不包含任何广告 SDK、分析 SDK 或其他数据收集组件。',
              '仅在以下情况下，数据可能被传输：',
              '  • 您主动使用 WebDAV 同步功能，数据将存储到您指定的 WebDAV 服务器',
              '  • 您主动备份数据，数据将保存到您选择的存储位置',
            ],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '5. 权限使用',
            content: [
              '本应用仅申请以下必要权限：',
              '  • 网络权限：用于 WebDAV 数据同步功能（可选）',
              '本应用无需存储权限即可正常使用。文件选择通过系统文件选择器（SAF）完成，',
              '本应用无法访问您未主动选择的文件。',
              '本应用不会申请与阅读功能无关的权限。',
            ],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '6. 数据安全',
            content: [
              '本应用采用合理的技术措施保护您的数据安全。',
              '本地数据未加密存储，请您妥善保管设备。',
              '使用 WebDAV 同步时，建议使用 HTTPS 加密传输。',
              '您应定期备份重要数据，以防数据丢失。',
            ],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '7. 儿童隐私',
            content: ['本应用面向所有年龄段用户。', '本应用不专门针对儿童设计。', '儿童使用本应用时，建议由监护人指导。'],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '8. 政策更新',
            content: [
              '本隐私政策可能不时更新。',
              '更新后的政策将在应用内发布。',
              '继续使用本应用即表示您接受更新后的隐私政策。',
            ],
          ),
          const SizedBox(height: 16),
          const LegalSectionCard(
            title: '9. 联系我们',
            content: [
              '如您对隐私政策有任何疑问或建议，请通过 GitHub Issues 联系我们。',
              '我们重视您的隐私，并将认真处理您的反馈。',
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '最后更新：2026 年 3 月 31 日',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
