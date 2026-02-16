import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/themes/semantic_theme.dart';
import '../../../../shared/models/website_monitor.dart';

class MonitorDetailsScreen extends StatelessWidget {
  final WebsiteMonitor monitor;

  const MonitorDetailsScreen({super.key, required this.monitor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticThemeColors>() ?? SemanticThemeColors.light;
    final isUp = monitor.currentStatus == MonitorStatus.up;
    final statusColor = isUp ? semantic.success : semantic.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(monitor.name),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withAlpha(50)),
            ),
            child: Row(
              children: [
                Icon(isUp ? Icons.check_circle : Icons.error, size: 16, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  isUp ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // URL Card
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.link, color: theme.colorScheme.primary),
              ),
              title: Text(monitor.url, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Checked every ${monitor.checkIntervalSeconds}s'),
            ),
          ),
          const SizedBox(height: 16),

          // Response Time Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Response Time', style: theme.textTheme.titleMedium),
                      Text(
                        '${monitor.averageResponseTime?.inMilliseconds ?? '--'}ms avg',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: theme.dividerColor.withAlpha(20),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _generateSpots(),
                            isCurved: true,
                            color: theme.colorScheme.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: theme.colorScheme.primary.withAlpha(30),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _StatTile(
                label: 'Last Check',
                value: DateFormat.Hm().format(DateTime.now()), // Placeholder
                icon: Icons.access_time,
                color: Colors.orange,
              ),
              _StatTile(
                label: 'Uptime',
                value: '99.9%',
                icon: Icons.thumb_up,
                color: Colors.green,
              ),
              _StatTile(
                label: 'Cert Expiry',
                value: '220 days',
                icon: Icons.security,
                color: Colors.blue,
              ),
              _StatTile(
                label: 'Port',
                value: '${monitor.port ?? 443}',
                icon: Icons.settings_input_component,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateSpots() {
    // Placeholder data
    return const [
      FlSpot(0, 30), FlSpot(1, 45), FlSpot(2, 20), FlSpot(3, 35), 
      FlSpot(4, 60), FlSpot(5, 25), FlSpot(6, 40),
    ];
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
        ],
      ),
    );
  }
}
