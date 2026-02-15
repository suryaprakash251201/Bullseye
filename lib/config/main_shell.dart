import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/themes/app_theme.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: _screens,
      ),
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: currentTab,
        onTap: (index) => ref.read(currentTabProvider.notifier).set(index),
        isDark: isDark,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-connection'),
        backgroundColor: AppTheme.cyan,
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _CustomBottomNav({required this.currentIndex, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Console', isSelected: currentIndex == 0, onTap: () => onTap(0), isDark: isDark),
          _NavItem(icon: Icons.link_outlined, selectedIcon: Icons.link, label: 'Connect', isSelected: currentIndex == 1, onTap: () => onTap(1), isDark: isDark),
          const SizedBox(width: 56),
          _NavItem(icon: Icons.build_outlined, selectedIcon: Icons.build, label: 'Tools', isSelected: currentIndex == 3, onTap: () => onTap(3), isDark: isDark),
          _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings', isSelected: currentIndex == 4, onTap: () => onTap(4), isDark: isDark),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppTheme.cyan;
    final inactiveColor = isDark ? Colors.white54 : const Color(0xFF718096);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Tools Grid Screen ---
class ToolsGridScreen extends StatelessWidget {
  const ToolsGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A202C),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search, color: isDark ? Colors.white70 : const Color(0xFF4A5568)),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Professional network utilities',
              style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white54 : const Color(0xFF718096)),
            ),
            const SizedBox(height: 24),

            _ToolSection(title: 'MONITORING', isDark: isDark, tools: [
              _ToolData(Icons.monitor_heart, 'Monitors', 'Uptime', AppTheme.success, '/monitors'),
              _ToolData(Icons.speed, 'Status', 'Health', AppTheme.cyan, '/status'),
            ]),
            const SizedBox(height: 24),

            _ToolSection(title: 'QUICK ACCESS', isDark: isDark, tools: [
              _ToolData(Icons.terminal, 'SSH', 'Terminal', AppTheme.cyan, '/ssh'),
              _ToolData(Icons.folder_copy, 'SFTP', 'Files', Colors.purple, '/ftp'),
              _ToolData(Icons.text_snippet, 'Logs', 'View', Colors.orange, '/logs'),
            ]),
            const SizedBox(height: 24),

            _ToolSection(title: 'REMOTE ACCESS', isDark: isDark, tools: [
              _ToolData(Icons.computer, 'SSH Client', 'Secure shell', AppTheme.cyan, '/ssh'),
              _ToolData(Icons.folder_shared, 'FTP Client', 'File transfer', Colors.purple, '/ftp'),
            ]),
            const SizedBox(height: 24),

            _ToolSection(title: 'NETWORK ANALYSIS', isDark: isDark, tools: [
              _ToolData(Icons.cell_tower, 'Ping', 'ICMP check', Colors.blue, '/ping'),
              _ToolData(Icons.route, 'Traceroute', 'Path trace', Colors.green, '/traceroute'),
              _ToolData(Icons.dns, 'DNS Lookup', 'Records', Colors.teal, '/dns'),
              _ToolData(Icons.radar, 'Port Scan', 'Open ports', Colors.orange, '/port-checker'),
            ]),
            const SizedBox(height: 24),

            _ToolSection(title: 'DIAGNOSTICS', isDark: isDark, tools: [
              _ToolData(Icons.security, 'SSL Check', 'Certificates', Colors.red, '/ssl'),
              _ToolData(Icons.info_outline, 'Whois', 'Domain info', Colors.indigo, '/whois'),
              _ToolData(Icons.lan, 'Network Scan', 'LAN devices', AppTheme.success, '/network-scanner'),
              _ToolData(Icons.wifi, 'WiFi Info', 'Signal', AppTheme.info, '/wifi'),
            ]),
            const SizedBox(height: 100),
          ],
        ),
      ),
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

class _ToolSection extends StatelessWidget {
  final String title;
  final List<_ToolData> tools;
  final bool isDark;

  const _ToolSection({required this.title, required this.tools, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : const Color(0xFF718096),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: tools.length <= 3 ? tools.length : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: tools.length == 3 ? 1.0 : 1.2,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _ToolCard(
              icon: tool.icon,
              title: tool.title,
              subtitle: tool.subtitle,
              color: tool.color,
              isDark: isDark,
              onTap: () {
                if (tool.route == '/monitors') {
                  // Navigate to monitors tab
                  final container = ProviderScope.containerOf(context);
                  container.read(currentTabProvider.notifier).set(2);
                } else {
                  Navigator.pushNamed(context, tool.route);
                }
              },
            );
          },
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0), width: 1),
            boxShadow: isDark ? null : [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : const Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
