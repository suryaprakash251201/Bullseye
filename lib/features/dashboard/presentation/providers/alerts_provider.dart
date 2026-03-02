import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/website_monitor.dart';
import '../../../website_monitor/presentation/providers/monitor_provider.dart';

/// Types of alerts the dashboard can show
enum AlertType { monitorDown, highLatency, lowUptime, unchecked }

/// A single alert entry generated from monitor data
class MonitorAlert {
  final AlertType type;
  final String title;
  final String subtitle;
  final String monitorId;
  final DateTime timestamp;

  MonitorAlert({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.monitorId,
    required this.timestamp,
  });
}

/// Provider that generates alerts from actual monitor state
final alertsProvider = Provider<List<MonitorAlert>>((ref) {
  final monitors = ref.watch(monitorsProvider);
  final alerts = <MonitorAlert>[];

  for (final monitor in monitors) {
    if (!monitor.isActive) continue;

    // Alert: Monitor is DOWN
    if (monitor.currentStatus == MonitorStatus.down) {
      final lastCheck = monitor.lastCheck;
      final errorMsg = lastCheck?.error ?? 'Connection failed';
      alerts.add(MonitorAlert(
        type: AlertType.monitorDown,
        title: '${monitor.name} is DOWN',
        subtitle: errorMsg.length > 60 ? '${errorMsg.substring(0, 60)}...' : errorMsg,
        monitorId: monitor.id,
        timestamp: lastCheck?.timestamp ?? DateTime.now(),
      ));
    }

    // Alert: High latency (>2000ms)
    if (monitor.currentStatus == MonitorStatus.up) {
      final avgResponse = monitor.averageResponseTime;
      if (avgResponse != null && avgResponse.inMilliseconds > 2000) {
        alerts.add(MonitorAlert(
          type: AlertType.highLatency,
          title: '${monitor.name}: High Latency',
          subtitle: 'Avg response: ${avgResponse.inMilliseconds}ms',
          monitorId: monitor.id,
          timestamp: monitor.lastCheck?.timestamp ?? DateTime.now(),
        ));
      }
    }

    // Alert: Low uptime (<95%)
    if (monitor.history.length >= 10) {
      final uptime = monitor.uptimePercentage;
      if (uptime < 0.95) {
        alerts.add(MonitorAlert(
          type: AlertType.lowUptime,
          title: '${monitor.name}: Low Uptime',
          subtitle: 'Uptime: ${(uptime * 100).toStringAsFixed(1)}%',
          monitorId: monitor.id,
          timestamp: DateTime.now(),
        ));
      }
    }

    // Alert: Never checked
    if (monitor.history.isEmpty && monitor.isActive) {
      alerts.add(MonitorAlert(
        type: AlertType.unchecked,
        title: '${monitor.name}: Not Checked Yet',
        subtitle: 'Monitor has not been checked since creation',
        monitorId: monitor.id,
        timestamp: monitor.createdAt,
      ));
    }
  }

  // Sort by severity: down first, then high latency, low uptime, unchecked
  alerts.sort((a, b) => a.type.index.compareTo(b.type.index));

  return alerts;
});
