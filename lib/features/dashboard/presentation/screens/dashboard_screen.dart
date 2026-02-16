import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/semantic_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../website_monitor/presentation/providers/monitor_provider.dart';
import '../../../../shared/models/website_monitor.dart';
import '../../../../config/main_shell.dart';
import '../../../website_monitor/presentation/providers/monitor_filter_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final monitors = ref.watch(monitorsProvider);
    final up = monitors.where((m) => m.currentStatus == MonitorStatus.up).length;
    final down = monitors.where((m) => m.currentStatus == MonitorStatus.down).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            _buildHeader(context),
            const SizedBox(height: 20),
            _SystemStatusCard(upCount: up, totalCount: monitors.length),
            const SizedBox(height: 20),
            
            // Monitor Stats
            const SectionHeader(title: 'Monitor Overview'),
            _MonitorStatsRow(
              total: monitors.length,
              up: up,
              down: down,
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
            const SectionHeader(title: 'Quick Actions'),
            _QuickActionsRow(onMonitorTap: () {
              ref.read(currentTabProvider.notifier).set(2);
            }),
            const SizedBox(height: 20),

            // Alerts

            const SizedBox(height: 20),

            // Recent Monitors
            SectionHeader(
              title: 'Monitors',

            ),
            _MonitorsList(monitors: monitors.take(3).toList()),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bullseye',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'System overview & quick actions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => _showNotifications(context),
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      scrollControlDisabledMaxHeightRatio: 0.9,
      builder: (context) {
        final theme = Theme.of(context);
        final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomCard(
                  title: 'High CPU Usage',
                  subtitle: 'Server-01: CPU at 89% for 5 min',
                  icon: Icons.warning_amber,
                  iconColor: semantic.warning,
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomCard(
                  title: 'SSL Expiring Soon',
                  subtitle: 'example.com: expires in 7 days',
                  icon: Icons.error_outline,
                  iconColor: semantic.error,
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );

  }
}

// --- System Status Card ---
class _SystemStatusCard extends StatelessWidget {
  final int upCount;
  final int totalCount;

  const _SystemStatusCard({required this.upCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;
    
    final allUp = totalCount > 0 && upCount == totalCount;
    final statusColor = allUp ? semantic.success : semantic.warning;
    final statusText = allUp ? 'All Systems Operational' : '$upCount / $totalCount Services Up';
    final subtitle = allUp ? 'All monitors reporting healthy' : 'Some services need attention';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(50),
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('View Logs'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E293B),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Monitor Stats Row ---
class _MonitorStatsRow extends StatelessWidget {
  final int total;
  final int up;
  final int down;
  final VoidCallback onTotalTap;
  final VoidCallback onUpTap;
  final VoidCallback onDownTap;

  const _MonitorStatsRow({
    required this.total,
    required this.up,
    required this.down,
    required this.onTotalTap,
    required this.onUpTap,
    required this.onDownTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'TOTAL', value: '$total', icon: Icons.monitor_heart_outlined, color: theme.colorScheme.primary, onTap: onTotalTap)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'UP', value: '$up', icon: Icons.arrow_circle_up_outlined, color: semantic.success, onTap: onUpTap)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'DOWN', value: '$down', icon: Icons.arrow_circle_down_outlined, color: semantic.error, onTap: onDownTap)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Quick Actions Row ---
class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onMonitorTap;

  const _QuickActionsRow({required this.onMonitorTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [

          _QuickAction(icon: Icons.folder_copy, label: 'SFTP', color: Colors.purple, onTap: () => Navigator.pushNamed(context, '/ftp')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.monitor_heart, label: 'Monitors', color: semantic.success, onTap: onMonitorTap),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.cell_tower, label: 'Ping', color: Colors.blue, onTap: () => Navigator.pushNamed(context, '/ping')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.dns, label: 'DNS', color: Colors.teal, onTap: () => Navigator.pushNamed(context, '/dns')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.lan, label: 'Net Scan', color: Colors.indigo, onTap: () => Navigator.pushNamed(context, '/network-scanner')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.wifi, label: 'WiFi', color: Colors.lightBlue, onTap: () => Navigator.pushNamed(context, '/wifi')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.security, label: 'SSL', color: semantic.error, onTap: () => Navigator.pushNamed(context, '/ssl')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Monitors List ---
class _MonitorsList extends StatelessWidget {
  final List monitors;

  const _MonitorsList({required this.monitors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (monitors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.monitor_heart_outlined, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'No monitors yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (int i = 0; i < monitors.length; i++) ...[
            _MonitorTile(monitor: monitors[i]),
            if (i < monitors.length - 1)
              const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _MonitorTile extends StatelessWidget {
  final dynamic monitor;

  const _MonitorTile({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;
    final isUp = monitor.currentStatus == MonitorStatus.up;
    final statusColor = isUp ? semantic.success : semantic.error;

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: statusColor.withAlpha(100), blurRadius: 4),
          ],
        ),
      ),
      title: Text(
        monitor.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        monitor.url,
        style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withAlpha(30),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isUp ? 'UP' : 'DOWN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ),
    );
  }
}
