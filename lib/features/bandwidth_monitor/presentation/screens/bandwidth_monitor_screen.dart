import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/formatters.dart';

class BandwidthMonitorScreen extends ConsumerStatefulWidget {
  const BandwidthMonitorScreen({super.key});

  @override
  ConsumerState<BandwidthMonitorScreen> createState() => _BandwidthMonitorScreenState();
}

class _BandwidthMonitorScreenState extends ConsumerState<BandwidthMonitorScreen> {
  bool _isMonitoring = false;
  Timer? _timer;
  final List<_BandwidthSample> _samples = [];
  int _totalDownloadBytes = 0;
  int _totalUploadBytes = 0;
  String? _monitorError;
  _NetCounters? _lastCounters;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    final initialCounters = await _readRealtimeCounters();
    if (initialCounters == null) {
      if (!mounted) return;
      setState(() {
        _monitorError = 'Unable to read network counters on this platform.';
        _isMonitoring = false;
      });
      return;
    }

    setState(() {
      _isMonitoring = true;
      _monitorError = null;
      _samples.clear();
      _totalDownloadBytes = 0;
      _totalUploadBytes = 0;
      _lastCounters = initialCounters;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final currentCounters = await _readRealtimeCounters();
      if (currentCounters == null || _lastCounters == null) {
        return;
      }

      final downloadDelta = currentCounters.rxBytes - _lastCounters!.rxBytes;
      final uploadDelta = currentCounters.txBytes - _lastCounters!.txBytes;
      final download = downloadDelta > 0 ? downloadDelta.toDouble() : 0.0;
      final upload = uploadDelta > 0 ? uploadDelta.toDouble() : 0.0;
      _lastCounters = currentCounters;

      setState(() {
        _samples.add(_BandwidthSample(
          timestamp: DateTime.now(),
          downloadBytesPerSec: download,
          uploadBytesPerSec: upload,
        ));

        _totalDownloadBytes += download.toInt();
        _totalUploadBytes += upload.toInt();

        // Keep last 60 samples
        if (_samples.length > 60) {
          _samples.removeAt(0);
        }
      });
    });
  }

  void _stopMonitoring() {
    _timer?.cancel();
    setState(() => _isMonitoring = false);
  }

  Future<_NetCounters?> _readRealtimeCounters() async {
    if (Platform.isWindows) {
      final result = await Process.run('netstat', const ['-e'], runInShell: true);
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();
      final match = RegExp(r'Bytes\s+(\d+)\s+(\d+)', caseSensitive: false)
          .firstMatch(output.replaceAll(',', ''));
      if (match == null) return null;

      final rx = int.tryParse(match.group(1) ?? '');
      final tx = int.tryParse(match.group(2) ?? '');
      if (rx == null || tx == null) return null;
      return _NetCounters(rxBytes: rx, txBytes: tx);
    }

    if (Platform.isLinux || Platform.isAndroid) {
      final file = File('/proc/net/dev');
      if (!await file.exists()) return null;

      final lines = await file.readAsLines();
      int totalRx = 0;
      int totalTx = 0;

      for (final line in lines.skip(2)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final split = trimmed.split(':');
        if (split.length != 2) continue;

        final iface = split.first.trim();
        if (iface == 'lo') continue;

        final values = split.last
            .trim()
            .split(RegExp(r'\s+'))
            .where((v) => v.isNotEmpty)
            .toList();
        if (values.length < 16) continue;

        final rx = int.tryParse(values[0]) ?? 0;
        final tx = int.tryParse(values[8]) ?? 0;
        totalRx += rx;
        totalTx += tx;
      }

      return _NetCounters(rxBytes: totalRx, txBytes: totalTx);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final currentDown = _samples.isNotEmpty ? _samples.last.downloadBytesPerSec : 0.0;
    final currentUp = _samples.isNotEmpty ? _samples.last.uploadBytesPerSec : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandwidth Monitor'),
        actions: [
          TextButton.icon(
            onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
            icon: Icon(
              _isMonitoring ? Icons.stop : Icons.play_arrow,
              color: _isMonitoring ? AppTheme.error : AppTheme.success,
              size: 20,
            ),
            label: Text(
              _isMonitoring ? 'Stop' : 'Start',
              style: TextStyle(color: _isMonitoring ? AppTheme.error : AppTheme.success),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_monitorError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: AppTheme.error.withAlpha(20),
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: AppTheme.error),
                  title: Text(_monitorError!),
                ),
              ),
            ),

          // Current Speed Cards
          Row(
            children: [
              Expanded(
                child: _SpeedCard(
                  icon: Icons.arrow_downward,
                  label: 'Download',
                  speed: '${Formatters.formatBytes(currentDown.toInt())}/s',
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SpeedCard(
                  icon: Icons.arrow_upward,
                  label: 'Upload',
                  speed: '${Formatters.formatBytes(currentUp.toInt())}/s',
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SpeedCard(
                  icon: Icons.download,
                  label: 'Total Down',
                  speed: Formatters.formatBytes(_totalDownloadBytes),
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SpeedCard(
                  icon: Icons.upload,
                  label: 'Total Up',
                  speed: Formatters.formatBytes(_totalUploadBytes),
                  color: AppTheme.teal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Chart
          if (_samples.length > 2) ...[
            Text('Real-time Bandwidth', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 50000,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.onSurface.withAlpha(15),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 55,
                        getTitlesWidget: (value, meta) => Text(
                          Formatters.formatBytes(value.toInt()),
                          style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurface.withAlpha(100)),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _samples.asMap().entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.downloadBytesPerSec))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.info,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppTheme.info.withAlpha(30)),
                    ),
                    LineChartBarData(
                      spots: _samples.asMap().entries
                          .map((e) => FlSpot(e.key.toDouble(), e.value.uploadBytesPerSec))
                          .toList(),
                      isCurved: true,
                      color: AppTheme.success,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppTheme.success.withAlpha(20)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppTheme.info, label: 'Download'),
                const SizedBox(width: 20),
                _LegendDot(color: AppTheme.success, label: 'Upload'),
              ],
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.speed, size: 48, color: theme.colorScheme.onSurface.withAlpha(50)),
                    const SizedBox(height: 12),
                    Text(
                      _isMonitoring ? 'Collecting data...' : 'Press Start to monitor bandwidth',
                      style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BandwidthSample {
  final DateTime timestamp;
  final double downloadBytesPerSec;
  final double uploadBytesPerSec;

  _BandwidthSample({
    required this.timestamp,
    required this.downloadBytesPerSec,
    required this.uploadBytesPerSec,
  });
}

class _NetCounters {
  final int rxBytes;
  final int txBytes;

  _NetCounters({required this.rxBytes, required this.txBytes});
}

class _SpeedCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String speed;
  final Color color;

  const _SpeedCard({
    required this.icon,
    required this.label,
    required this.speed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            speed,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(140))),
      ],
    );
  }
}
