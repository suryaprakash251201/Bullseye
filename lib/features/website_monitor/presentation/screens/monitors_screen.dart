import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/themes/app_theme.dart';
import '../providers/monitor_provider.dart';
import '../providers/monitor_filter_provider.dart';
import '../../../../shared/models/website_monitor.dart';
import '../screens/add_monitor_screen.dart';

class MonitorsScreen extends ConsumerWidget {
  const MonitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monitors = ref.watch(monitorsProvider);

    return Scaffold(
      body: SafeArea(
        child: _buildBody(context, ref, monitors, isDark),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, List<WebsiteMonitor> monitors, bool isDark) {
    final filter = ref.watch(monitorFilterProvider);
    final up = monitors.where((m) => m.currentStatus == MonitorStatus.up).length;
    final down = monitors.where((m) => m.currentStatus == MonitorStatus.down).length;

    // Apply filter
    final filteredMonitors = switch (filter) {
      MonitorFilter.all => monitors,
      MonitorFilter.up => monitors.where((m) => m.currentStatus == MonitorStatus.up).toList(),
      MonitorFilter.down => monitors.where((m) => m.currentStatus == MonitorStatus.down).toList(),
    };

    final filterLabel = switch (filter) {
      MonitorFilter.all => 'All Monitors',
      MonitorFilter.up => 'Up Monitors',
      MonitorFilter.down => 'Down Monitors',
    };

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Monitors',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1A202C),
                ),
              ),
            ),
            _buildAddButton(context, isDark),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Website & service monitoring',
          style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white54 : const Color(0xFF718096)),
        ),
        const SizedBox(height: 20),

        // Summary Cards — tappable to filter
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Total', value: '${monitors.length}', icon: Icons.monitor_heart, color: AppTheme.cyan, isDark: isDark, isActive: filter == MonitorFilter.all, onTap: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.all))),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Up', value: '$up', icon: Icons.arrow_upward, color: AppTheme.success, isDark: isDark, isActive: filter == MonitorFilter.up, onTap: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.up))),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Down', value: '$down', icon: Icons.arrow_downward, color: AppTheme.error, isDark: isDark, isActive: filter == MonitorFilter.down, onTap: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.down))),
          ],
        ),
        const SizedBox(height: 16),

        // Active filter indicator
        if (filter != MonitorFilter.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (filter == MonitorFilter.up ? AppTheme.success : AppTheme.error).withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (filter == MonitorFilter.up ? AppTheme.success : AppTheme.error).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter == MonitorFilter.up ? Icons.arrow_circle_up : Icons.arrow_circle_down,
                        size: 16,
                        color: filter == MonitorFilter.up ? AppTheme.success : AppTheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Showing: $filterLabel (${filteredMonitors.length})',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: filter == MonitorFilter.up ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.all),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkElevated : const Color(0xFFF0F2F5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 14, color: isDark ? Colors.white54 : const Color(0xFF718096)),
                  ),
                ),
              ],
            ),
          ),

        // Monitor list
        if (filteredMonitors.isEmpty)
          _EmptyState(isDark: isDark, filter: filter),
        for (final monitor in filteredMonitors) ...[
          _EndpointCard(monitor: monitor, isDark: isDark, onDelete: () {
            ref.read(monitorsProvider.notifier).removeMonitor(monitor.id);
          }),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context, bool isDark) {
    return Material(
      color: AppTheme.cyan.withOpacity(isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMonitorScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: AppTheme.cyan, size: 18),
              const SizedBox(width: 6),
              Text('Add', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.cyan)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final MonitorFilter filter;
  const _EmptyState({required this.isDark, this.filter = MonitorFilter.all});

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      MonitorFilter.all => 'No monitors yet',
      MonitorFilter.up => 'No monitors are currently up',
      MonitorFilter.down => 'No monitors are currently down',
    };
    final subtitle = switch (filter) {
      MonitorFilter.all => 'Add your first monitor to start tracking',
      MonitorFilter.up => 'All monitors may be down or none added yet',
      MonitorFilter.down => 'All monitors are running fine!',
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            filter == MonitorFilter.down ? Icons.check_circle_outline : Icons.monitor_heart_outlined,
            size: 56,
            color: filter == MonitorFilter.down ? AppTheme.success.withOpacity(0.5) : (isDark ? Colors.white24 : const Color(0xFFA0AEC0)),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : const Color(0xFF4A5568)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : const Color(0xFF718096)),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool isActive;
  final VoidCallback? onTap;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color, required this.isDark, this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(isDark ? 0.15 : 0.08) : (isDark ? AppTheme.darkCard : AppTheme.lightCard),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color.withOpacity(0.6) : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1A202C)),
            ),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF718096))),
          ],
        ),
      ),
    );
  }
}

class _EndpointCard extends StatelessWidget {
  final WebsiteMonitor monitor;
  final VoidCallback onDelete;
  final bool isDark;

  const _EndpointCard({required this.monitor, required this.onDelete, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUp = monitor.currentStatus == MonitorStatus.up;
    final statusColor = isUp ? AppTheme.success : AppTheme.error;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  monitor.name,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1A202C)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUp ? 'UP' : 'DOWN',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline, color: isDark ? Colors.white38 : const Color(0xFFA0AEC0), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            monitor.url,
            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white38 : const Color(0xFF718096)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${monitor.averageResponseTime?.inMilliseconds ?? '--'}ms',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1A202C)),
                  ),
                  Text(
                    'Response time',
                    style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white38 : const Color(0xFF718096)),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 120,
                height: 40,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _generateSpots(),
                        isCurved: true,
                        color: AppTheme.cyan,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: AppTheme.cyan.withOpacity(0.1)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    return const [
      FlSpot(0, 3), FlSpot(1, 1.5), FlSpot(2, 4), FlSpot(3, 2), FlSpot(4, 3.5), FlSpot(5, 1), FlSpot(6, 4),
    ];
  }
}
