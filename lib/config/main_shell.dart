import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
            const SectionHeader(title: 'REMOTE MANAGEMENT'),
            const SizedBox(height: 12),
            _RemoteManagementCard(
              icon: Icons.terminal,
              title: 'SSH Client',
              subtitle: 'Secure shell access',
              color: Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/ssh'),
            ),
            const SizedBox(height: 12),
            _RemoteManagementCard(
              icon: Icons.folder,
              title: 'SFTP Client',
              subtitle: 'File transfer protocol',
              color: Colors.purple,
              onTap: () => Navigator.pushNamed(context, '/ftp'),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'NETWORK UTILITIES'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ping - Large Card
                Expanded(
                  flex: 4,
                  child: _LargeToolCard(
                    icon: Icons.wifi_tethering, 
                    title: 'Ping', 
                    subtitle: 'Latency check', 
                    color: const Color(0xFF00C853), // Green
                    onTap: () => Navigator.pushNamed(context, '/ping'),
                  ),
                ),
                const SizedBox(width: 12),
                // Right Column
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _SmallToolCard(
                        icon: Icons.dns, 
                        title: 'DNS Lookup', 
                        color: Colors.orange, 
                        onTap: () => Navigator.pushNamed(context, '/dns'),
                      ),
                      const SizedBox(height: 12),
                      _SmallToolCard(
                        icon: Icons.timeline, 
                        title: 'Traceroute', 
                        color: Colors.teal, 
                        onTap: () => Navigator.pushNamed(context, '/traceroute'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Status Monitor - Wide
            SizedBox(
              height: 120,
              child: CustomCard(
                title: 'Status Monitor',
                subtitle: 'Check uptime',
                icon: Icons.monitor_heart,
                iconColor: Colors.blue,
                onTap: () {
                   ref.read(currentTabProvider.notifier).set(2);
                },
              ),
            ),

            const SizedBox(height: 24),

            const SectionHeader(title: 'QUICK ACTIONS'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _QuickActionItem(icon: Icons.speed, label: 'Speedtest', onTap: () => Navigator.pushNamed(context, '/speedtest'))),
                const SizedBox(width: 12),
                Expanded(child: _QuickActionItem(icon: Icons.lan, label: 'Port Scan', onTap: () => Navigator.pushNamed(context, '/port-checker'))),
                const SizedBox(width: 12),
                Expanded(child: _QuickActionItem(icon: Icons.calculate, label: 'Subnet', onTap: () {})),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _RemoteManagementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RemoteManagementCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300]),
            ],
          ),
        ),
      ),
    );
  }
}

class _LargeToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _LargeToolCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _SmallToolCard({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.grey[700], size: 24),
              ),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily,fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}

