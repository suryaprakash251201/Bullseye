import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/network_service.dart';

class PingTracerouteScreen extends ConsumerStatefulWidget {
  const PingTracerouteScreen({super.key});

  @override
  ConsumerState<PingTracerouteScreen> createState() => _PingTracerouteScreenState();
}

class _PingTracerouteScreenState extends ConsumerState<PingTracerouteScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _hostController = TextEditingController();

  // Ping state
  bool _isPinging = false;
  final List<PingResult> _pingResults = [];
  int _pingCount = 10;

  // Traceroute state
  bool _isTracing = false;
  final List<TracerouteHop> _hops = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _startPing() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _isPinging = true;
      _pingResults.clear();
    });

    final networkService = ref.read(networkServiceProvider);

    for (int i = 0; i < _pingCount && _isPinging; i++) {
      final result = await networkService.ping(host);
      if (mounted) {
        setState(() => _pingResults.add(result));
      }
      if (i < _pingCount - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (mounted) setState(() => _isPinging = false);
  }

  void _stopPing() {
    setState(() => _isPinging = false);
  }

  Future<void> _startTraceroute() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _isTracing = true;
      _hops.clear();
    });

    try {
      final networkService = ref.read(networkServiceProvider);
      final hops = await networkService.traceroute(host);
      if (!mounted) return;
      setState(() {
        _hops
          ..clear()
          ..addAll(hops);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Traceroute failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isTracing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ping & Traceroute'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ping', icon: Icon(Icons.cell_tower, size: 18)),
            Tab(text: 'Traceroute', icon: Icon(Icons.route, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Input
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText: 'Host / IP Address',
                hintText: 'google.com or 8.8.8.8',
                prefixIcon: const Icon(Icons.dns),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => _hostController.clear(),
                ),
              ),
              onSubmitted: (_) {
                if (_tabController.index == 0) {
                  _startPing();
                } else {
                  _startTraceroute();
                }
              },
            ),
          ),

          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPingTab(theme),
                _buildTracerouteTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPingTab(ThemeData theme) {
    return Column(
      children: [
        // Ping count selector + start button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('Count: ', style: theme.textTheme.bodyMedium),
              ...([5, 10, 25, 50].map((c) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text('$c'),
                  selected: _pingCount == c,
                  onSelected: _isPinging ? null : (_) => setState(() => _pingCount = c),
                  visualDensity: VisualDensity.compact,
                ),
              ))),
              const Spacer(),
              FilledButton.icon(
                onPressed: _isPinging ? _stopPing : _startPing,
                icon: Icon(_isPinging ? Icons.stop : Icons.play_arrow, size: 20),
                label: Text(_isPinging ? 'Stop' : 'Start'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Stats summary
        if (_pingResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PingStatsRow(results: _pingResults),
          ),
          const SizedBox(height: 8),
        ],

        // Chart
        if (_pingResults.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 120,
              child: _PingChart(results: _pingResults),
            ),
          ),

        // Results list
        Expanded(
          child: _pingResults.isEmpty
              ? Center(
                  child: Text(
                    'Enter a host and press Start',
                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _pingResults.length,
                  itemBuilder: (context, index) {
                    final r = _pingResults[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        r.isReachable ? Icons.check_circle : Icons.cancel,
                        color: r.isReachable ? AppTheme.success : AppTheme.error,
                        size: 20,
                      ),
                      title: Text(
                        r.isReachable
                            ? 'Reply from ${r.host}: time=${r.responseTime!.inMilliseconds}ms'
                            : 'Request timed out',
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Text(
                        '#${index + 1}',
                        style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(80), fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTracerouteTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: _isTracing ? null : _startTraceroute,
                icon: Icon(_isTracing ? Icons.hourglass_empty : Icons.play_arrow, size: 20),
                label: Text(_isTracing ? 'Tracing...' : 'Trace Route'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _hops.isEmpty
              ? Center(
                  child: Text(
                    'Enter a host and press Trace Route',
                    style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hops.length,
                  itemBuilder: (context, index) {
                    final hop = _hops[index];
                    return _TracerouteHopTile(hop: hop, isLast: index == _hops.length - 1);
                  },
                ),
        ),
      ],
    );
  }
}

class _PingStatsRow extends StatelessWidget {
  final List<PingResult> results;

  const _PingStatsRow({required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successful = results.where((r) => r.isReachable).toList();
    final failed = results.where((r) => !r.isReachable).length;
    final times = successful.map((r) => r.responseTime!.inMilliseconds).toList();
    final minTime = times.isEmpty ? 0 : times.reduce((a, b) => a < b ? a : b);
    final maxTime = times.isEmpty ? 0 : times.reduce((a, b) => a > b ? a : b);
    final avgTime = times.isEmpty ? 0 : (times.reduce((a, b) => a + b) / times.length).round();
    final lossPercent = results.isEmpty ? 0.0 : (failed / results.length * 100);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat(label: 'Min', value: '${minTime}ms', color: AppTheme.success),
          _MiniStat(label: 'Avg', value: '${avgTime}ms', color: AppTheme.info),
          _MiniStat(label: 'Max', value: '${maxTime}ms', color: AppTheme.warning),
          _MiniStat(
            label: 'Loss',
            value: '${lossPercent.toStringAsFixed(1)}%',
            color: lossPercent > 0 ? AppTheme.error : AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
      ],
    );
  }
}

class _PingChart extends StatelessWidget {
  final List<PingResult> results;

  const _PingChart({required this.results});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < results.length; i++) {
      final ms = results[i].responseTime?.inMilliseconds.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), ms));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppTheme.primaryLight,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: results[index].isReachable ? AppTheme.success : AppTheme.error,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryLight.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }
}

class _TracerouteHopTile extends StatelessWidget {
  final TracerouteHop hop;
  final bool isLast;

  const _TracerouteHopTile({required this.hop, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line indicator
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: hop.timedOut
                    ? AppTheme.warning.withAlpha(30)
                    : AppTheme.success.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hop.timedOut ? AppTheme.warning : AppTheme.success,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  '${hop.hopNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hop.timedOut ? AppTheme.warning : AppTheme.success,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: theme.colorScheme.onSurface.withAlpha(30),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hop.timedOut ? '* * * Request timed out' : (hop.address ?? 'Unknown'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hop.timedOut ? AppTheme.warning : null,
                  ),
                ),
                if (hop.responseTime != null)
                  Text(
                    '${hop.responseTime!.inMilliseconds}ms',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                SizedBox(height: isLast ? 0 : 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
