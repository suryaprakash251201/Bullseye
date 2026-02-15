import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../website_monitor/presentation/providers/monitor_provider.dart';
import '../../../../shared/models/website_monitor.dart';
import '../../../connections/presentation/providers/connections_provider.dart';
import '../../../../config/main_shell.dart';
import '../../../website_monitor/presentation/providers/monitor_filter_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monitors = ref.watch(monitorsProvider);
    final up = monitors.where((m) => m.currentStatus == MonitorStatus.up).length;
    final down = monitors.where((m) => m.currentStatus == MonitorStatus.down).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            _buildHeader(context, isDark),
            const SizedBox(height: 20),
            _SystemStatusCard(isDark: isDark, upCount: up, totalCount: monitors.length),
            const SizedBox(height: 20),
            // Monitor Stats
            _SectionHeader(title: 'Monitor Overview', isDark: isDark),
            const SizedBox(height: 12),
            _MonitorStatsRow(
              total: monitors.length,
              up: up,
              down: down,
              isDark: isDark,
              onTotalTap: () {
                ref.read(monitorFilterProvider.notifier).set(MonitorFilter.all);
                ref.read(currentTabProvider.notifier).set(2);
              },
              onUpTap: () {
                ref.read(monitorFilterProvider.notifier).set(MonitorFilter.up);
                ref.read(currentTabProvider.notifier).set(2);
              },
              onDownTap: () {
                ref.read(monitorFilterProvider.notifier).set(MonitorFilter.down);
                ref.read(currentTabProvider.notifier).set(2);
              },
            ),
            const SizedBox(height: 20),
            // Quick Actions
            _SectionHeader(title: 'Quick Actions', isDark: isDark),
            const SizedBox(height: 12),
            _QuickActionsRow(isDark: isDark, onMonitorTap: () {
              ref.read(currentTabProvider.notifier).set(2);
            }),
            const SizedBox(height: 20),
            // Alerts
            _SectionHeader(title: 'Alerts', isDark: isDark),
            const SizedBox(height: 12),
            _AlertCard(
              icon: Icons.warning_amber,
              title: 'High CPU Usage',
              subtitle: 'Server-01: CPU at 89% for 5 min',
              color: AppTheme.warning,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _AlertCard(
              icon: Icons.error_outline,
              title: 'SSL Expiring Soon',
              subtitle: 'example.com: expires in 7 days',
              color: AppTheme.error,
              isDark: isDark,
            ),
            const SizedBox(height: 20),
            // Recent Monitors
            _SectionHeader(title: 'Monitors', isDark: isDark),
            const SizedBox(height: 12),
            _MonitorsCard(monitors: monitors, isDark: isDark, onViewAll: () {
              ref.read(currentTabProvider.notifier).set(2);
            }),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bullseye',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'System overview & quick actions',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : const Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark ? null : [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: isDark ? Colors.white70 : const Color(0xFF4A5568),
            size: 20,
          ),
        ),
      ],
    );
  }
}

// --- System Status Card ---
class _SystemStatusCard extends StatelessWidget {
  final bool isDark;
  final int upCount;
  final int totalCount;

  const _SystemStatusCard({required this.isDark, required this.upCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final allUp = totalCount > 0 && upCount == totalCount;
    final statusColor = allUp ? AppTheme.cyan : AppTheme.warning;
    final statusText = allUp ? 'All Systems Operational' : '$upCount / $totalCount Services Up';
    final subtitle = allUp ? 'All monitors reporting healthy' : 'Some services need attention';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(isDark ? 0.15 : 0.08), statusColor.withOpacity(isDark ? 0.05 : 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              allUp ? Icons.check_circle : Icons.warning_rounded,
              color: statusColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Section Header ---
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.cyan,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }
}

// --- Monitor Stats Row ---
class _MonitorStatsRow extends StatelessWidget {
  final int total;
  final int up;
  final int down;
  final bool isDark;
  final VoidCallback onTotalTap;
  final VoidCallback onUpTap;
  final VoidCallback onDownTap;

  const _MonitorStatsRow({required this.total, required this.up, required this.down, required this.isDark, required this.onTotalTap, required this.onUpTap, required this.onDownTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'TOTAL', value: '$total', icon: Icons.monitor_heart_outlined, color: AppTheme.cyan, isDark: isDark, onTap: onTotalTap)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'UP', value: '$up', icon: Icons.arrow_circle_up_outlined, color: AppTheme.success, isDark: isDark, onTap: onUpTap)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'DOWN', value: '$down', icon: Icons.arrow_circle_down_outlined, color: AppTheme.error, isDark: isDark, onTap: onDownTap)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : const Color(0xFF718096),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// --- Quick Actions Row ---
class _QuickActionsRow extends StatelessWidget {
  final bool isDark;
  final VoidCallback onMonitorTap;

  const _QuickActionsRow({required this.isDark, required this.onMonitorTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickAction(icon: Icons.terminal, label: 'SSH', color: AppTheme.cyan, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ssh')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.folder_copy, label: 'SFTP', color: Colors.purple, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ftp')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.monitor_heart, label: 'Monitors', color: AppTheme.success, isDark: isDark, onTap: onMonitorTap),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.cell_tower, label: 'Ping', color: Colors.blue, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ping')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.dns, label: 'DNS', color: Colors.teal, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/dns')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.security, label: 'SSL', color: Colors.red, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ssl')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Alert Card ---
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _AlertCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          Icon(Icons.chevron_right, color: isDark ? Colors.white38 : const Color(0xFFA0AEC0), size: 20),
        ],
      ),
    );
  }
}

// --- Monitors Card ---
class _MonitorsCard extends StatelessWidget {
  final List monitors;
  final bool isDark;
  final VoidCallback onViewAll;

  const _MonitorsCard({required this.monitors, required this.isDark, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final topMonitors = monitors.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
        boxShadow: isDark ? null : [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          if (topMonitors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.monitor_heart_outlined, size: 40, color: isDark ? Colors.white24 : const Color(0xFFA0AEC0)),
                  const SizedBox(height: 8),
                  Text(
                    'No monitors yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : const Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
          for (int i = 0; i < topMonitors.length; i++) ...[
            _MonitorTile(monitor: topMonitors[i], isDark: isDark),
            if (i < topMonitors.length - 1)
              Divider(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0), height: 20),
          ],
          if (monitors.length > 3) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all ${monitors.length} monitors',
                style: GoogleFonts.inter(color: AppTheme.cyan, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonitorTile extends StatelessWidget {
  final dynamic monitor;
  final bool isDark;

  const _MonitorTile({required this.monitor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUp = monitor.currentStatus == MonitorStatus.up;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isUp ? AppTheme.success : AppTheme.error,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: (isUp ? AppTheme.success : AppTheme.error).withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monitor.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF1A202C),
                ),
              ),
              Text(
                monitor.url,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF718096),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isUp ? AppTheme.success : AppTheme.error).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isUp ? 'UP' : 'DOWN',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isUp ? AppTheme.success : AppTheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
