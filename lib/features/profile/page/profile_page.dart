import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      'JD',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'John Doe',
                    style: theme.textTheme.headlineMedium,
                  ),
                  Text(
                    'UI/UX Designer',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Settings Section
            Text('Settings', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildSettingItem(context, 'Notifications', Icons.notifications_outlined),
            _buildSettingItem(context, 'Privacy', Icons.lock_outline),
            _buildSettingItem(context, 'Appearance', Icons.palette_outlined),
            _buildSettingItem(context, 'Help & Support', Icons.help_outline),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(color: theme.colorScheme.error),
                  foregroundColor: theme.colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, String title, IconData icon) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {},
    );
  }
}
