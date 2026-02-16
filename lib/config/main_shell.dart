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

  final _screens = const [
    DashboardScreen(),
    ConnectionsScreen(),
    MonitorsScreen(),
    ToolsGridScreen(),
    SettingsScreen(),
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

// --- Tools data model ---
class _ToolItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;
  final String category;

  const _ToolItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    required this.category,
  });
}

const _allTools = <_ToolItem>[
  _ToolItem(icon: Icons.terminal, title: 'SSH Client', subtitle: 'Secure shell access', color: Colors.blue, route: '/ssh', category: 'Remote'),
  _ToolItem(icon: Icons.folder, title: 'SFTP Client', subtitle: 'File transfer protocol', color: Colors.purple, route: '/ftp', category: 'Remote'),
  _ToolItem(icon: Icons.wifi_tethering, title: 'Ping', subtitle: 'Latency check', color: Color(0xFF00C853), route: '/ping', category: 'Network'),
  _ToolItem(icon: Icons.dns, title: 'DNS Lookup', subtitle: 'Domain name resolution', color: Colors.orange, route: '/dns', category: 'Network'),
  _ToolItem(icon: Icons.timeline, title: 'Traceroute', subtitle: 'Network path trace', color: Colors.teal, route: '/traceroute', category: 'Network'),
  _ToolItem(icon: Icons.radar, title: 'Nmap Scanner', subtitle: 'Advanced port & host scan', color: Color(0xFFE91E63), route: '/nmap', category: 'Security'),
  _ToolItem(icon: Icons.lan, title: 'Port Checker', subtitle: 'Check open ports', color: Colors.indigo, route: '/port-checker', category: 'Security'),
  _ToolItem(icon: Icons.security, title: 'SSL Inspector', subtitle: 'Certificate analysis', color: Colors.red, route: '/ssl', category: 'Security'),
  _ToolItem(icon: Icons.search, title: 'WHOIS Lookup', subtitle: 'Domain registration info', color: Color(0xFF795548), route: '/whois', category: 'Security'),
  _ToolItem(icon: Icons.wifi_find, title: 'Network Scanner', subtitle: 'Discover devices', color: Colors.cyan, route: '/network-scanner', category: 'Security'),
  _ToolItem(icon: Icons.speed, title: 'Ookla Speedtest', subtitle: 'Accurate speed test', color: Color(0xFF00B4D8), route: '/ookla-speedtest', category: 'Performance'),
  _ToolItem(icon: Icons.speed, title: 'Quick Speedtest', subtitle: 'Fast speed check', color: Colors.blueAccent, route: '/speedtest', category: 'Performance'),
  _ToolItem(icon: Icons.bar_chart, title: 'Bandwidth', subtitle: 'Monitor bandwidth', color: Colors.green, route: '/bandwidth', category: 'Performance'),
  _ToolItem(icon: Icons.wifi, title: 'WiFi Analyzer', subtitle: 'Signal & channel analysis', color: Colors.teal, route: '/wifi', category: 'Wireless'),
  _ToolItem(icon: Icons.calculate, title: 'Subnet Calc', subtitle: 'CIDR & IP subnetting', color: Color(0xFF7C4DFF), route: '/subnet', category: 'Utilities'),
  _ToolItem(icon: Icons.http, title: 'HTTP Headers', subtitle: 'Inspect HTTP headers', color: Colors.blue, route: '/http-headers', category: 'Utilities'),
  _ToolItem(icon: Icons.public, title: 'IP Geolocation', subtitle: 'Locate IP address', color: Colors.red, route: '/ip-geo', category: 'Utilities'),
  _ToolItem(icon: Icons.person_search, title: 'UA Parser', subtitle: 'Parse user-agent strings', color: Colors.deepOrange, route: '/user-agent', category: 'Utilities'),
  _ToolItem(icon: Icons.schedule, title: 'Cron Parser', subtitle: 'Parse cron expressions', color: Color(0xFF00897B), route: '/cron', category: 'Utilities'),
  _ToolItem(icon: Icons.tag, title: 'Hash Generator', subtitle: 'MD5, SHA hashing', color: Color(0xFF6D4C41), route: '/hash', category: 'Encoding'),
  _ToolItem(icon: Icons.code, title: 'Base64 / URL', subtitle: 'Encode & decode', color: Color(0xFF455A64), route: '/base64', category: 'Encoding'),
];

// --- Tools Grid Screen ---
class ToolsGridScreen extends ConsumerStatefulWidget {
  const ToolsGridScreen({super.key});

  @override
  ConsumerState<ToolsGridScreen> createState() => _ToolsGridScreenState();
}

class _ToolsGridScreenState extends ConsumerState<ToolsGridScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ToolItem> get _filteredTools {
    if (_query.isEmpty) return _allTools;
    final q = _query.toLowerCase();
    return _allTools.where((t) =>
      t.title.toLowerCase().contains(q) ||
      t.subtitle.toLowerCase().contains(q) ||
      t.category.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: _isSearching ? _buildSearchView(theme, isDark) : _buildNormalView(theme, isDark),
      ),
    );
  }

  // ── Search results view ──
  Widget _buildSearchView(ThemeData theme, bool isDark) {
    final results = _filteredTools;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search tools...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _query = '';
                    _searchController.clear();
                  });
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        if (results.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: theme.colorScheme.onSurface.withAlpha(80)),
                  const SizedBox(height: 12),
                  Text('No tools found', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withAlpha(120))),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final tool = results[index];
                return _SearchResultTile(tool: tool, isDark: isDark, onTap: () => Navigator.pushNamed(context, tool.route));
              },
            ),
          ),
      ],
    );
  }

  // ── Normal categorized view ──
  Widget _buildNormalView(ThemeData theme, bool isDark) {
    return ListView(
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
              onPressed: () => setState(() => _isSearching = true),
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

        // ── REMOTE MANAGEMENT ──
        const SectionHeader(title: 'REMOTE MANAGEMENT'),
        const SizedBox(height: 12),
        _RemoteManagementCard(
          icon: Icons.terminal,
          title: 'SSH Client',
          subtitle: 'Secure shell access',
          color: Colors.blue,
          isDark: isDark,
          onTap: () => Navigator.pushNamed(context, '/ssh'),
        ),
        const SizedBox(height: 12),
        _RemoteManagementCard(
          icon: Icons.folder,
          title: 'SFTP Client',
          subtitle: 'File transfer protocol',
          color: Colors.purple,
          isDark: isDark,
          onTap: () => Navigator.pushNamed(context, '/ftp'),
        ),
        const SizedBox(height: 24),

        // ── NETWORK UTILITIES ──
        const SectionHeader(title: 'NETWORK UTILITIES'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: _LargeToolCard(
                icon: Icons.wifi_tethering,
                title: 'Ping',
                subtitle: 'Latency check',
                color: const Color(0xFF00C853),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/ping'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  _SmallToolCard(
                    icon: Icons.dns,
                    title: 'DNS Lookup',
                    color: Colors.orange,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/dns'),
                  ),
                  const SizedBox(height: 12),
                  _SmallToolCard(
                    icon: Icons.timeline,
                    title: 'Traceroute',
                    color: Colors.teal,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/traceroute'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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

        // ── SCANNING & SECURITY ──
        const SectionHeader(title: 'SCANNING & SECURITY'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _LargeToolCard(
                icon: Icons.radar,
                title: 'Nmap Scanner',
                subtitle: 'Advanced port & host scan',
                color: const Color(0xFFE91E63),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/nmap'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _SmallToolCard(
                    icon: Icons.lan,
                    title: 'Port Checker',
                    color: Colors.indigo,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/port-checker'),
                  ),
                  const SizedBox(height: 12),
                  _SmallToolCard(
                    icon: Icons.security,
                    title: 'SSL Inspector',
                    color: Colors.red,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/ssl'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallToolCard(
                icon: Icons.search,
                title: 'WHOIS Lookup',
                color: const Color(0xFF795548),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/whois'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallToolCard(
                icon: Icons.wifi_find,
                title: 'Network Scanner',
                color: Colors.cyan,
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/network-scanner'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── PERFORMANCE ──
        const SectionHeader(title: 'PERFORMANCE'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _LargeToolCard(
                icon: Icons.speed,
                title: 'Ookla Speedtest',
                subtitle: 'Accurate speed test',
                color: const Color(0xFF00B4D8),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/ookla-speedtest'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _SmallToolCard(
                    icon: Icons.speed,
                    title: 'Quick Speedtest',
                    color: Colors.blueAccent,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/speedtest'),
                  ),
                  const SizedBox(height: 12),
                  _SmallToolCard(
                    icon: Icons.bar_chart,
                    title: 'Bandwidth',
                    color: Colors.green,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/bandwidth'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── WIRELESS ──
        const SectionHeader(title: 'WIRELESS'),
        const SizedBox(height: 12),
        _RemoteManagementCard(
          icon: Icons.wifi,
          title: 'WiFi Analyzer',
          subtitle: 'Signal strength & channel analysis',
          color: Colors.teal,
          isDark: isDark,
          onTap: () => Navigator.pushNamed(context, '/wifi'),
        ),
        const SizedBox(height: 24),

        // ── UTILITIES ──
        const SectionHeader(title: 'UTILITIES'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _LargeToolCard(
                icon: Icons.calculate,
                title: 'Subnet Calc',
                subtitle: 'CIDR & IP subnetting',
                color: const Color(0xFF7C4DFF),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/subnet'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _SmallToolCard(
                    icon: Icons.http,
                    title: 'HTTP Headers',
                    color: Colors.blue,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/http-headers'),
                  ),
                  const SizedBox(height: 12),
                  _SmallToolCard(
                    icon: Icons.public,
                    title: 'IP Geolocation',
                    color: Colors.red,
                    isDark: isDark,
                    onTap: () => Navigator.pushNamed(context, '/ip-geo'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallToolCard(
                icon: Icons.person_search,
                title: 'UA Parser',
                color: Colors.deepOrange,
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/user-agent'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallToolCard(
                icon: Icons.schedule,
                title: 'Cron Parser',
                color: const Color(0xFF00897B),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/cron'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── ENCODING & HASHING ──
        const SectionHeader(title: 'ENCODING & HASHING'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallToolCard(
                icon: Icons.tag,
                title: 'Hash Generator',
                color: const Color(0xFF6D4C41),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/hash'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallToolCard(
                icon: Icons.code,
                title: 'Base64 / URL',
                color: const Color(0xFF455A64),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/base64'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── QUICK ACTIONS ──
        const SectionHeader(title: 'QUICK ACTIONS'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _QuickActionItem(icon: Icons.speed, label: 'Speedtest', isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ookla-speedtest'))),
            const SizedBox(width: 12),
            Expanded(child: _QuickActionItem(icon: Icons.radar, label: 'Nmap', isDark: isDark, onTap: () => Navigator.pushNamed(context, '/nmap'))),
            const SizedBox(width: 12),
            Expanded(child: _QuickActionItem(icon: Icons.lan, label: 'Port Scan', isDark: isDark, onTap: () => Navigator.pushNamed(context, '/port-checker'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _QuickActionItem(icon: Icons.dns, label: 'DNS', isDark: isDark, onTap: () => Navigator.pushNamed(context, '/dns'))),
            const SizedBox(width: 12),
            Expanded(child: _QuickActionItem(icon: Icons.calculate, label: 'Subnet', isDark: isDark, onTap: () => Navigator.pushNamed(context, '/subnet'))),
            const SizedBox(width: 12),
            Expanded(child: _QuickActionItem(icon: Icons.security, label: 'SSL', isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ssl'))),
          ],
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

// ── Search Result Tile ──
class _SearchResultTile extends StatelessWidget {
  final _ToolItem tool;
  final bool isDark;
  final VoidCallback onTap;

  const _SearchResultTile({required this.tool, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C2128) : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tool.color.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(tool.icon, color: tool.color, size: 22),
        ),
        title: Text(tool.title, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(tool.subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey[500])),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tool.color.withAlpha(15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(tool.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tool.color)),
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
  final bool isDark;
  final VoidCallback onTap;

  const _RemoteManagementCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1C2128) : Colors.white,
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
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[500])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: isDark ? Colors.white24 : Colors.grey[300]),
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
  final bool isDark;
  final VoidCallback onTap;

  const _LargeToolCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
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
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[500])),
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
  final bool isDark;
  final VoidCallback onTap;

  const _SmallToolCard({required this.icon, required this.title, required this.color, required this.onTap, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
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
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 14, fontWeight: FontWeight.w600)),
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
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionItem({required this.icon, required this.label, required this.onTap, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2128) : Colors.white,
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
                  color: isDark ? Colors.white10 : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isDark ? Colors.white70 : Colors.grey[700], size: 24),
              ),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}

