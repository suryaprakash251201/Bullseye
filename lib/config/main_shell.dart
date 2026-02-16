import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/themes/semantic_theme.dart';
import '../shared/widgets/app_bottom_nav.dart';
import '../shared/widgets/custom_card.dart';
import '../shared/widgets/section_header.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/connections/presentation/screens/connections_screen.dart';
import '../features/website_monitor/presentation/screens/monitors_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

final currentTabProvider = NotifierProvider<CurrentTabNotifier, int>(CurrentTabNotifier.new);

class CurrentTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static final _screens = [
    const DashboardScreen(),
    const ConnectionsScreen(),
    const MonitorsScreen(),
    const ToolsGridScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    
    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: currentTab,
        onTap: (index) => ref.read(currentTabProvider.notifier).set(index),
      ),

    );
  }
}

// --- Tools Grid Screen ---
class ToolsGridScreen extends ConsumerWidget {
  const ToolsGridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light; // Fallback to avoid crash

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Admin Tools',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Professional network utilities',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'MONITORING'),
            _buildGrid([
              _ToolData(Icons.monitor_heart, 'Monitors', 'Uptime', semantic.success, '/monitors'),
              _ToolData(Icons.speed, 'Status', 'Health', theme.colorScheme.primary, '/status'),
            ], context, ref),
            const SizedBox(height: 24),

            const SectionHeader(title: 'REMOTE MANAGEMENT'),
            _buildGrid([
              _ToolData(Icons.terminal, 'SSH Client', 'Secure shell', theme.colorScheme.primary, '/ssh'),
              _ToolData(Icons.folder_shared, 'SFTP Client', 'File transfer', Colors.purple, '/ftp'),
            ], context, ref),
            const SizedBox(height: 24),

            const SectionHeader(title: 'NETWORK TOOLS'),
            _buildGrid([
              _ToolData(Icons.cell_tower, 'Ping', 'ICMP check', Colors.blue, '/ping'),
              _ToolData(Icons.route, 'Traceroute', 'Path trace', semantic.success, '/traceroute'),
              _ToolData(Icons.dns, 'DNS Lookup', 'Records', Colors.teal, '/dns'),
              _ToolData(Icons.radar, 'Port Scan', 'Open ports', semantic.warning, '/port-checker'),
              _ToolData(Icons.lan, 'Network Scan', 'LAN devices', semantic.success, '/network-scanner'),
              _ToolData(Icons.wifi, 'WiFi Info', 'Signal', semantic.info, '/wifi'),
            ], context, ref),
            const SizedBox(height: 24),

            const SectionHeader(title: 'DIAGNOSTICS'),
            _buildGrid([
              _ToolData(Icons.security, 'SSL Check', 'Certificates', semantic.error, '/ssl'),
              _ToolData(Icons.info_outline, 'Whois', 'Domain info', Colors.indigo, '/whois'),
              _ToolData(Icons.text_snippet, 'Logs', 'View', semantic.warning, '/logs'),
            ], context, ref),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<_ToolData> tools, BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return CustomCard(
          title: tool.title,
          subtitle: tool.subtitle,
          icon: tool.icon,
          iconColor: tool.color,
          onTap: () {
            if (tool.route == '/monitors') {
               ref.read(currentTabProvider.notifier).set(2);
            } else {
              Navigator.pushNamed(context, tool.route);
            }
          },
        );
      },
    );
  }
}

class _ToolData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  const _ToolData(this.icon, this.title, this.subtitle, this.color, this.route);
}

