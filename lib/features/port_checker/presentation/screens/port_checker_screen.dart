import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/constants/app_constants.dart';

class PortCheckerScreen extends ConsumerStatefulWidget {
  const PortCheckerScreen({super.key});

  @override
  ConsumerState<PortCheckerScreen> createState() => _PortCheckerScreenState();
}

class _PortCheckerScreenState extends ConsumerState<PortCheckerScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  bool _isScanning = false;
  bool _useCommonPorts = true;
  List<PortScanResult> _results = [];
  double _progress = 0;
  int _openCount = 0;

  Future<void> _scan() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    List<int> ports;
    if (_useCommonPorts) {
      ports = AppConstants.commonPorts;
    } else {
      final portText = _portController.text.trim();
      if (portText.isEmpty) return;
      ports = _parsePorts(portText);
    }
    if (ports.isEmpty) return;

    setState(() { _isScanning = true; _results = []; _progress = 0; _openCount = 0; });

    final networkService = ref.read(networkServiceProvider);
    final totalPorts = ports.length;

    for (int i = 0; i < totalPorts && _isScanning; i += 10) {
      final batch = ports.skip(i).take(10).toList();
      final batchResults = await Future.wait(
        batch.map((port) => networkService.scanPort(host, port, timeout: const Duration(seconds: 2))),
      );
      if (mounted) {
        setState(() {
          _results.addAll(batchResults);
          _openCount = _results.where((r) => r.isOpen).length;
          _progress = (i + batch.length) / totalPorts;
        });
      }
    }

    if (mounted) {
      setState(() {
        _results.sort((a, b) {
          if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
          return a.port.compareTo(b.port);
        });
        _isScanning = false;
        _progress = 1;
      });
    }
  }

  List<int> _parsePorts(String text) {
    final ports = <int>{};
    for (final part in text.split(',')) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null && start <= end && start >= 1 && end <= 65535) {
            for (int i = start; i <= end; i++) {
              ports.add(i);
            }
          }
        }
      } else {
        final port = int.tryParse(trimmed);
        if (port != null && port >= 1 && port <= 65535) ports.add(port);
      }
    }
    return ports.toList()..sort();
  }

  void _copyResults() {
    final buffer = StringBuffer();
    buffer.writeln('Port Scan: ${_hostController.text}');
    buffer.writeln('─' * 40);
    buffer.writeln('Open: $_openCount / ${_results.length}');
    buffer.writeln('');
    for (final r in _results) {
      final serviceName = AppConstants.portServiceNames[r.port] ?? '';
      buffer.writeln('Port ${r.port}${serviceName.isNotEmpty ? " ($serviceName)" : ""}: ${r.isOpen ? "OPEN" : "CLOSED"} (${r.responseTime.inMilliseconds}ms)');
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
  void dispose() { _hostController.dispose(); _portController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Port Scanner', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          if (_results.isNotEmpty)
            IconButton(icon: const Icon(Icons.copy_all, size: 22), tooltip: 'Copy results', onPressed: _copyResults),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
                  ),
                  child: TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: 'Host / IP',
                      hintText: 'example.com or 192.168.1.1',
                      prefixIcon: const Icon(Icons.dns),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        value: _useCommonPorts,
                        onChanged: (v) => setState(() => _useCommonPorts = v ?? true),
                        title: Text('Common ports', style: GoogleFonts.inter(fontSize: 14)),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (!_useCommonPorts)
                  Container(
                    decoration: BoxDecoration(
                      gradient: isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
                    ),
                    child: TextField(
                      controller: _portController,
                      decoration: InputDecoration(
                        labelText: 'Ports',
                        hintText: '80, 443, 1000-2000',
                        prefixIcon: const Icon(Icons.settings_input_component),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Summary + scan/stop
                Row(
                  children: [
                    if (_results.isNotEmpty)
                      Text(
                        '$_openCount open / ${_results.length} scanned',
                        style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withAlpha(120), fontSize: 13),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isScanning ? () => setState(() => _isScanning = false) : _scan,
                      icon: Icon(_isScanning ? Icons.stop : Icons.radar, size: 20),
                      label: Text(_isScanning ? 'Stop' : 'Scan'),
                    ),
                  ],
                ),
                if (_isScanning) ...[
                  const SizedBox(height: 12),
                  _AnimatedProgress(progress: _progress, isDark: isDark),
                ],
              ],
            ),
          ),
          // Summary stats
          if (_results.isNotEmpty && !_isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SummaryRow(open: _openCount, closed: _results.length - _openCount, total: _results.length, isDark: isDark),
            ),
          if (_results.isNotEmpty && !_isScanning) const SizedBox(height: 12),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radar, size: 48, color: theme.colorScheme.onSurface.withAlpha(50)),
                        const SizedBox(height: 12),
                        Text('Enter a host to scan ports', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return _AnimatedPortResult(index: index, result: r, isDark: isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Row ──
class _SummaryRow extends StatelessWidget {
  final int open; final int closed; final int total; final bool isDark;
  const _SummaryRow({required this.open, required this.closed, required this.total, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryItem(label: 'Open', value: '$open', color: AppTheme.success, isDark: isDark)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryItem(label: 'Closed', value: '$closed', color: AppTheme.error, isDark: isDark)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryItem(label: 'Total', value: '$total', color: AppTheme.cyan, isDark: isDark)),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label; final String value; final Color color; final bool isDark;
  const _SummaryItem({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withAlpha(isDark ? 20 : 12), color.withAlpha(isDark ? 8 : 4)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : const Color(0xFF718096), letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ── Animated Progress ──
class _AnimatedProgress extends StatelessWidget {
  final double progress; final bool isDark;
  const _AnimatedProgress({required this.progress, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: isDark ? Colors.white.withAlpha(10) : const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation(AppTheme.cyan),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.cyan, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Animated Port Result ──
class _AnimatedPortResult extends StatefulWidget {
  final int index;
  final PortScanResult result;
  final bool isDark;
  const _AnimatedPortResult({required this.index, required this.result, required this.isDark});

  @override
  State<_AnimatedPortResult> createState() => _AnimatedPortResultState();
}

class _AnimatedPortResultState extends State<_AnimatedPortResult> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: (widget.index * 30).clamp(0, 300)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.result;
    final serviceName = AppConstants.portServiceNames[r.port] ?? '';
    final statusColor = r.isOpen ? AppTheme.success : AppTheme.error;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            gradient: widget.isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
            borderRadius: BorderRadius.circular(14),
            boxShadow: widget.isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
          ),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [statusColor.withAlpha(30), statusColor.withAlpha(10)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                r.isOpen ? Icons.lock_open : Icons.lock,
                color: statusColor,
                size: 18,
              ),
            ),
            title: Text(
              'Port ${r.port}${serviceName.isNotEmpty ? ' ($serviceName)' : ''}',
              style: GoogleFonts.inter(fontWeight: r.isOpen ? FontWeight.w600 : FontWeight.normal, fontSize: 14),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${r.responseTime.inMilliseconds}ms', style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(100))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [statusColor.withAlpha(25), statusColor.withAlpha(10)]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withAlpha(40)),
                  ),
                  child: Text(
                    r.isOpen ? 'OPEN' : 'CLOSED',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            onLongPress: () {
              final text = 'Port ${r.port}: ${r.isOpen ? "OPEN" : "CLOSED"} (${r.responseTime.inMilliseconds}ms)';
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $text'), behavior: SnackBarBehavior.floating));
            },
          ),
        ),
      ),
    );
  }
}
