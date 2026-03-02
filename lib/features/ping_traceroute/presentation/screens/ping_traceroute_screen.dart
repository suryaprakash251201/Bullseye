import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
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

  bool _isPinging = false;
  final List<PingResult> _pingResults = [];
  int _pingCount = 10;

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

    setState(() { _isPinging = true; _pingResults.clear(); });

    final networkService = ref.read(networkServiceProvider);
    for (int i = 0; i < _pingCount && _isPinging; i++) {
      final result = await networkService.ping(host);
      if (mounted) setState(() => _pingResults.add(result));
      if (i < _pingCount - 1) await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) setState(() => _isPinging = false);
  }

  void _stopPing() => setState(() => _isPinging = false);

  Future<void> _startTraceroute() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() { _isTracing = true; _hops.clear(); });
    try {
      final networkService = ref.read(networkServiceProvider);
      final hops = await networkService.traceroute(host);
      if (!mounted) return;
      setState(() { _hops..clear()..addAll(hops); });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Traceroute failed: $e')));
    } finally {
      if (mounted) setState(() => _isTracing = false);
    }
  }

  void _copyResults() {
    final buffer = StringBuffer();
    if (_tabController.index == 0) {
      buffer.writeln('Ping Results for ${_hostController.text}');
      buffer.writeln('─' * 40);
      for (int i = 0; i < _pingResults.length; i++) {
        final r = _pingResults[i];
        if (r.isReachable) {
          buffer.writeln('#${i + 1}: Reply from ${r.host} time=${r.responseTime!.inMilliseconds}ms');
        } else {
          buffer.writeln('#${i + 1}: Request timed out');
        }
      }
    } else {
      buffer.writeln('Traceroute to ${_hostController.text}');
      buffer.writeln('─' * 40);
      for (final hop in _hops) {
        if (hop.timedOut) {
          buffer.writeln('${hop.hopNumber}: * * * Request timed out');
        } else {
          buffer.writeln('${hop.hopNumber}: ${hop.address} ${hop.responseTime?.inMilliseconds ?? "?"}ms');
        }
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: AppTheme.success, size: 18), const SizedBox(width: 8), const Text('Results copied to clipboard')]),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ping & Traceroute', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          if (_pingResults.isNotEmpty || _hops.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_all, size: 22),
              tooltip: 'Copy results',
              onPressed: _copyResults,
            ),
        ],
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
              ),
              child: TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: 'Host / IP Address',
                  hintText: 'google.com or 8.8.8.8',
                  prefixIcon: const Icon(Icons.dns),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.transparent,
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
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPingTab(theme, isDark),
                _buildTracerouteTab(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPingTab(ThemeData theme, bool isDark) {
    return Column(
      children: [
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
        if (_pingResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PingStatsRow(results: _pingResults, isDark: isDark),
          ),
          const SizedBox(height: 8),
        ],
        if (_pingResults.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
              ),
              padding: const EdgeInsets.all(12),
              child: _PingChart(results: _pingResults),
            ),
          ),
        if (_pingResults.length > 1) const SizedBox(height: 8),
        Expanded(
          child: _pingResults.isEmpty
              ? Center(child: Text('Enter a host and press Start', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _pingResults.length,
                  itemBuilder: (context, index) {
                    final r = _pingResults[index];
                    return _AnimatedPingResult(
                      index: index,
                      result: r,
                      isDark: isDark,
                      onLongPress: () {
                        final text = r.isReachable
                            ? 'Reply from ${r.host}: time=${r.responseTime!.inMilliseconds}ms'
                            : 'Request timed out';
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $text'), behavior: SnackBarBehavior.floating));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTracerouteTab(ThemeData theme, bool isDark) {
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
              ? Center(child: Text('Enter a host and press Trace Route', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _hops.length,
                  itemBuilder: (context, index) {
                    final hop = _hops[index];
                    return _TracerouteHopTile(hop: hop, isLast: index == _hops.length - 1, isDark: isDark);
                  },
                ),
        ),
      ],
    );
  }
}

// ── Animated Ping Result ──
class _AnimatedPingResult extends StatefulWidget {
  final int index;
  final PingResult result;
  final bool isDark;
  final VoidCallback onLongPress;

  const _AnimatedPingResult({required this.index, required this.result, required this.isDark, required this.onLongPress});

  @override
  State<_AnimatedPingResult> createState() => _AnimatedPingResultState();
}

class _AnimatedPingResultState extends State<_AnimatedPingResult> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
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
              trailing: Text('#${widget.index + 1}', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(80), fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ping Stats Row ──
class _PingStatsRow extends StatelessWidget {
  final List<PingResult> results;
  final bool isDark;
  const _PingStatsRow({required this.results, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final successful = results.where((r) => r.isReachable).toList();
    final failed = results.where((r) => !r.isReachable).length;
    final times = successful.map((r) => r.responseTime!.inMilliseconds).toList();
    final minTime = times.isEmpty ? 0 : times.reduce((a, b) => a < b ? a : b);
    final maxTime = times.isEmpty ? 0 : times.reduce((a, b) => a > b ? a : b);
    final avgTime = times.isEmpty ? 0 : (times.reduce((a, b) => a + b) / times.length).round();
    final lossPercent = results.isEmpty ? 0.0 : (failed / results.length * 100);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _MiniStat(label: 'Min', value: '${minTime}ms', color: AppTheme.success),
          _MiniStat(label: 'Avg', value: '${avgTime}ms', color: AppTheme.info),
          _MiniStat(label: 'Max', value: '${maxTime}ms', color: AppTheme.warning),
          _MiniStat(label: 'Loss', value: '${lossPercent.toStringAsFixed(1)}%', color: lossPercent > 0 ? AppTheme.error : AppTheme.success),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label; final String value; final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withAlpha(120))),
      ],
    );
  }
}

// ── Ping Chart (with gradient fill) ──
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
            gradient: AppTheme.accentGradient,
            barWidth: 2.5,
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
              gradient: LinearGradient(
                colors: [AppTheme.primaryLight.withAlpha(40), AppTheme.primaryLight.withAlpha(5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Traceroute Hop Tile ──
class _TracerouteHopTile extends StatefulWidget {
  final TracerouteHop hop;
  final bool isLast;
  final bool isDark;
  const _TracerouteHopTile({required this.hop, required this.isLast, required this.isDark});

  @override
  State<_TracerouteHopTile> createState() => _TracerouteHopTileState();
}

class _TracerouteHopTileState extends State<_TracerouteHopTile> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hop = widget.hop;
    final hopColor = hop.timedOut ? AppTheme.warning : AppTheme.success;

    return FadeTransition(
      opacity: _fade,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [hopColor.withAlpha(40), hopColor.withAlpha(15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: hopColor.withAlpha(80), width: 2),
                  boxShadow: [BoxShadow(color: hopColor.withAlpha(20), blurRadius: 6)],
                ),
                child: Center(
                  child: Text(
                    '${hop.hopNumber}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: hopColor),
                  ),
                ),
              ),
              if (!widget.isLast)
                Container(width: 2, height: 30, color: theme.colorScheme.onSurface.withAlpha(20)),
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
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: hop.timedOut ? AppTheme.warning : null),
                  ),
                  if (hop.responseTime != null)
                    Text('${hop.responseTime!.inMilliseconds}ms', style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120))),
                  SizedBox(height: widget.isLast ? 0 : 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
