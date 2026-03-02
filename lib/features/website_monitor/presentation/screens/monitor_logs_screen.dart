import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/themes/app_theme.dart';
import '../providers/monitor_provider.dart';

class MonitorLogsScreen extends ConsumerWidget {
  final String monitorId;
  const MonitorLogsScreen({super.key, required this.monitorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitors = ref.watch(monitorsProvider);
    final monitor = monitors.where((m) => m.id == monitorId).firstOrNull;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (monitor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monitor Logs')),
        body: const Center(child: Text('Monitor not found')),
      );
    }

    final history = monitor.history.reversed.toList();
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: Text(monitor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(monitorsProvider.notifier).checkMonitor(monitorId),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _SummaryItem(
                  label: 'Total Checks',
                  value: '${history.length}',
                  icon: Icons.checklist,
                  color: AppTheme.cyan,
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _SummaryItem(
                  label: 'Uptime',
                  value: '${(monitor.uptimePercentage * 100).toStringAsFixed(1)}%',
                  icon: Icons.trending_up,
                  color: AppTheme.success,
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _SummaryItem(
                  label: 'Avg Response',
                  value: '${monitor.averageResponseTime?.inMilliseconds ?? '--'}ms',
                  icon: Icons.speed,
                  color: Colors.orange,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          // Log title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Check History (${history.length})',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A202C),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Logs list
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history, size: 48, color: isDark ? Colors.white24 : const Color(0xFFA0AEC0)),
                        const SizedBox(height: 12),
                        Text(
                          'No check history yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: isDark ? Colors.white54 : const Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: history.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final isUp = entry.isUp;
                      final statusColor = isUp ? AppTheme.success : AppTheme.error;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 4),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isUp ? 'UP' : 'DOWN',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      if (entry.statusCode != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          'HTTP ${entry.statusCode}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isDark ? Colors.white54 : const Color(0xFF718096),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (entry.responseTime != null)
                                        Text(
                                          '${entry.responseTime!.inMilliseconds}ms',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(entry.timestamp),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: isDark ? Colors.white38 : const Color(0xFF718096),
                                    ),
                                  ),
                                  if (entry.error != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.error!,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppTheme.error,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? Colors.white38 : const Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }
}
