/// 用户协议页面

import 'package:flutter/material.dart';

/// 用户协议页面
class UserAgreementPage extends StatelessWidget {
  const UserAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('用户协议')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            theme,
            title: '1. 接受条款',
            content: [
              '欢迎使用 Zephyr Reader（以下简称"本应用"）。',
              '下载、安装、使用本应用即表示您同意本用户协议的所有条款。',
              '如果您不同意本协议的任何条款，请立即停止使用本应用。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '2. 服务说明',
            content: [
              '本应用是一款纯本地、高性能、双语友好的安卓离线小说阅读器。',
              '核心功能 100% 离线可用，仅 WebDAV 同步功能需要网络连接。',
              '本应用采用 Flutter + Rust 技术架构，提供优质的阅读体验。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '3. 用户权利',
            content: [
              '您有权免费使用本应用的所有功能。',
              '您可以将本应用用于个人学习、阅读等非商业用途。',
              '您可以随时停止使用本应用，并删除已安装的应用程序。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '4. 用户义务',
            content: [
              '您应确保使用本应用的行为符合当地法律法规。',
              '您不得利用本应用传播任何违法、有害、不当的信息。',
              '您不得对本应用进行反向工程、反编译或试图提取源代码。',
              '您不得利用本应用从事任何商业活动或盈利行为。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '5. 知识产权',
            content: [
              '本应用及其所有组成部分（包括但不限于代码、界面设计、图标、商标等）的知识产权归开发者所有。',
              '未经开发者书面许可，您不得复制、修改、传播、销售本应用的任何部分。',
              '您通过本应用阅读的小说内容，其版权归原作者或版权方所有。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '6. 隐私保护',
            content: [
              '本应用尊重并保护用户隐私。',
              '本应用不收集任何个人敏感信息。',
              '本应用仅在本地存储您的阅读记录、书架数据等必要信息。',
              '详细的隐私政策请参阅《隐私政策》页面。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '7. 免责声明',
            content: [
              '本应用按"原样"提供，不提供任何形式的明示或暗示保证。',
              '开发者不对本应用的适用性、准确性、完整性做任何保证。',
              '因使用本应用导致的任何数据丢失、设备损坏等后果，开发者不承担责任。',
              '您通过本应用阅读的小说内容，请确保来源合法，开发者不承担版权责任。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '8. 协议变更',
            content: [
              '开发者保留随时修改本用户协议的权利。',
              '协议变更后，将在应用内更新协议内容。',
              '继续使用本应用即表示您接受修改后的协议。',
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            theme,
            title: '9. 联系方式',
            content: [
              '如您对本协议有任何疑问，请通过 GitHub Issues 联系我们。',
              '开发者将在合理时间内回复您的问题。',
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

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required List<String> content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...content.map(
              (text) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(text, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
