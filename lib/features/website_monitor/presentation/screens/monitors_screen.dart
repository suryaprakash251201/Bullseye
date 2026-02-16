import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/themes/semantic_theme.dart';
import '../providers/monitor_provider.dart';
import '../providers/monitor_filter_provider.dart';
import '../../../../shared/models/website_monitor.dart';
import '../screens/add_monitor_screen.dart';

class MonitorsScreen extends ConsumerWidget {
  const MonitorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitors = ref.watch(monitorsProvider);

    return Scaffold(
      body: SafeArea(
        child: _buildBody(context, ref, monitors),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, List<WebsiteMonitor> monitors) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;
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
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddMonitorScreen()));
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Website & service monitoring',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(150),
          ),
        ),
        const SizedBox(height: 20),

        // Summary Cards — tappable to filter
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Total', value: '${monitors.length}', icon: Icons.monitor_heart, color: theme.colorScheme.primary, isActive: filter == MonitorFilter.all, onTap: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.all))),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Up', value: '$up', icon: Icons.arrow_upward, color: semantic.success, isActive: filter == MonitorFilter.up, onTap: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.up))),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(label: 'Down', value: '$down', icon: Icons.arrow_downward, color: semantic.error, isActive: filter == MonitorFilter.down, onTap: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.down))),
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
                    color: (filter == MonitorFilter.up ? semantic.success : semantic.error).withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (filter == MonitorFilter.up ? semantic.success : semantic.error).withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        filter == MonitorFilter.up ? Icons.arrow_circle_up : Icons.arrow_circle_down,
                        size: 16,
                        color: filter == MonitorFilter.up ? semantic.success : semantic.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Showing: $filterLabel (${filteredMonitors.length})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: filter == MonitorFilter.up ? semantic.success : semantic.error,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => ref.read(monitorFilterProvider.notifier).set(MonitorFilter.all),
                  icon: const Icon(Icons.close, size: 16),
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(28, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

        // Monitor list
        if (filteredMonitors.isEmpty)
          _EmptyState(filter: filter),
        for (final monitor in filteredMonitors) ...[
          _EndpointCard(monitor: monitor, onDelete: () {
            ref.read(monitorsProvider.notifier).removeMonitor(monitor.id);
          }),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 100),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final MonitorFilter filter;
  const _EmptyState({this.filter = MonitorFilter.all});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;
    
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
            color: filter == MonitorFilter.down ? semantic.success.withAlpha(128) : theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
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
  final bool isActive;
  final VoidCallback? onTap;

  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color, this.isActive = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? color.withAlpha(30) : (theme.cardTheme.color ?? theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color.withAlpha(150) : (theme.cardTheme.shape as RoundedRectangleBorder?)?.side.color ?? Colors.transparent,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
          ],
        ),
      ),
    );
  }
}

class _EndpointCard extends StatelessWidget {
  final WebsiteMonitor monitor;
  final VoidCallback onDelete;

  const _EndpointCard({required this.monitor, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;
    final isUp = monitor.currentStatus == MonitorStatus.up;
    final statusColor = isUp ? semantic.success : semantic.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
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
                  boxShadow: [BoxShadow(color: statusColor.withAlpha(100), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  monitor.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUp ? 'UP' : 'DOWN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline, color: theme.colorScheme.onSurface.withAlpha(100), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            monitor.url,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Response time',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                    ),
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
                        color: theme.colorScheme.primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withAlpha(30)),
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
