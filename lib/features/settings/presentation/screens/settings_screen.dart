import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Appearance
          _SectionTitle('Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Optimized for low-light environments'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (_) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('Font Size'),
                  subtitle: const Text('Medium'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.terminal),
                  title: const Text('Terminal Theme'),
                  subtitle: const Text('Dark (default)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Security
          _SectionTitle('Security'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric Authentication'),
                  subtitle: const Text('Use fingerprint or Face ID'),
                  value: false,
                  onChanged: (v) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Biometric auth configuration')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.password),
                  title: const Text('Master Password'),
                  subtitle: const Text('Not configured'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showMasterPasswordDialog(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Auto-Lock Timeout'),
                  subtitle: const Text('5 minutes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: AppTheme.error),
                  title: const Text('Secure Erase All Data'),
                  subtitle: const Text('Remove all stored credentials'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmSecureErase(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Monitoring
          _SectionTitle('Monitoring'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  subtitle: const Text('Alert when monitor goes down'),
                  trailing: Switch(
                    value: true,
                    onChanged: (v) {},
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Default Check Interval'),
                  subtitle: const Text('60 seconds'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.battery_saver),
                  title: const Text('Background Monitoring'),
                  subtitle: const Text('Continue monitoring when app is closed'),
                  value: false,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Data
          _SectionTitle('Data Management'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('Export Configurations'),
                  subtitle: const Text('Backup connections and monitors'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export feature - configurations would be saved')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Configurations'),
                  subtitle: const Text('Restore from backup file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Import feature - file picker would open')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Clear Monitor History'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About
          _SectionTitle('About'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: Text(AppConstants.appVersion),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.policy),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: AppConstants.appVersion,
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showMasterPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Master Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Set Password')),
        ],
      ),
    );
  }

  void _confirmSecureErase(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Secure Erase'),
        content: const Text(
          'This will permanently delete ALL stored credentials, connections, and monitor data. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data securely erased')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Erase Everything'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
