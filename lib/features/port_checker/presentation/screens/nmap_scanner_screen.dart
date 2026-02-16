import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/services/nmap_service.dart';
import '../../../../core/themes/app_theme.dart';

final _nmapAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(nmapServiceProvider);
  return service.checkAvailability();
});

class NmapScannerScreen extends ConsumerStatefulWidget {
  const NmapScannerScreen({super.key});

  @override
  ConsumerState<NmapScannerScreen> createState() => _NmapScannerScreenState();
}

class _NmapScannerScreenState extends ConsumerState<NmapScannerScreen>
    with SingleTickerProviderStateMixin {
  final _targetController = TextEditingController();
  final _customPortsController = TextEditingController();
  NmapScanType _selectedScanType = NmapScanType.quick;
  bool _useCustomPorts = false;
  bool _isScanning = false;
  NmapScanResult? _result;
  final List<String> _liveOutput = [];
  final _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _targetController.dispose();
    _customPortsController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runScan() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isScanning = true;
      _result = null;
      _liveOutput.clear();
    });

    final service = ref.read(nmapServiceProvider);
    final result = await service.scan(
      target: target,
      scanType: _selectedScanType,
      customPorts: _useCustomPorts ? _customPortsController.text.trim() : null,
      onOutput: (line) {
        if (mounted) {
          setState(() {
            _liveOutput.add(line);
          });
          // Auto-scroll
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _result = result;
        _isScanning = false;
      });
      // Switch to results tab
      if (result.error == null) {
        _tabController.animateTo(1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final nmapAvailable = ref.watch(_nmapAvailableProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 22),
            const SizedBox(width: 8),
            const Text('Nmap Scanner'),
          ],
        ),
        actions: [
          nmapAvailable.when(
            data: (available) {
              final nmapService = ref.read(nmapServiceProvider);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  avatar: Icon(
                    available ? Icons.check_circle : Icons.error,
                    size: 16,
                    color: available ? AppTheme.success : AppTheme.error,
                  ),
                  label: Text(
                    available ? 'Nmap ${nmapService.version}' : 'Not found',
                    style: TextStyle(fontSize: 11, color: available ? AppTheme.success : AppTheme.error),
                  ),
                  backgroundColor: (available ? AppTheme.success : AppTheme.error).withAlpha(20),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, st) => const SizedBox(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scan', icon: Icon(Icons.search, size: 18)),
            Tab(text: 'Results', icon: Icon(Icons.list_alt, size: 18)),
            Tab(text: 'Raw', icon: Icon(Icons.code, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScanTab(theme, isDark),
          _buildResultsTab(theme, isDark),
          _buildRawTab(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildScanTab(ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Target input
        TextField(
          controller: _targetController,
          decoration: InputDecoration(
            labelText: 'Target',
            hintText: 'IP, hostname, or CIDR (e.g. 192.168.1.0/24)',
            prefixIcon: const Icon(Icons.gps_fixed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onSubmitted: (_) => _runScan(),
        ),
        const SizedBox(height: 20),

        // Scan type selector
        Text('Scan Profile', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...NmapScanType.values.map((type) => _ScanTypeOption(
          scanType: type,
          isSelected: _selectedScanType == type,
          isDark: isDark,
          onTap: () => setState(() => _selectedScanType = type),
        )),

        const SizedBox(height: 16),

        // Custom ports toggle
        SwitchListTile(
          title: const Text('Custom Ports'),
          subtitle: const Text('Specify port range manually'),
          value: _useCustomPorts,
          onChanged: (v) => setState(() => _useCustomPorts = v),
          contentPadding: EdgeInsets.zero,
        ),
        if (_useCustomPorts) ...[
          TextField(
            controller: _customPortsController,
            decoration: InputDecoration(
              labelText: 'Ports',
              hintText: '22,80,443 or 1-1024 or T:80,U:53',
              prefixIcon: const Icon(Icons.settings_input_component),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 16),

        // Scan button
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isScanning ? null : _runScan,
            icon: Icon(_isScanning ? Icons.hourglass_top : Icons.play_arrow),
            label: Text(_isScanning ? 'Scanning...' : 'Start Scan'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),

        if (_isScanning) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            'Scan in progress...',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            textAlign: TextAlign.center,
          ),
        ],

        if (_result?.error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.error.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.error.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _result!.error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultsTab(ThemeData theme, bool isDark) {
    if (_result == null || _result!.hosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar, size: 56, color: theme.colorScheme.onSurface.withAlpha(40)),
            const SizedBox(height: 12),
            Text(
              _isScanning ? 'Scan in progress...' : 'No results yet',
              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100)),
            ),
            if (_isScanning) ...[
              const SizedBox(height: 16),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      );
    }

    final result = _result!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Scan Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SummaryChip(label: 'Hosts', value: '${result.totalHosts}', color: Colors.blue),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Up', value: '${result.hostsUp}', color: AppTheme.success),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'Open Ports', value: '${result.totalOpenPorts}', color: Colors.orange),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Duration: ${result.scanDuration.inSeconds}s  •  ${result.scanCommand}',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(100)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Host results
        for (final host in result.hosts) ...[
          _HostResultCard(host: host, isDark: isDark, theme: theme),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildRawTab(ThemeData theme, bool isDark) {
    final content = _isScanning ? _liveOutput.join('\n') : (_result?.rawOutput ?? '');

    if (content.isEmpty) {
      return Center(
        child: Text('No output yet', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('Raw Output', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy to clipboard',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                content,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: isDark ? Colors.green[300] : Colors.black87,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ScanTypeOption extends StatelessWidget {
  final NmapScanType scanType;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ScanTypeOption({
    required this.scanType,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (scanType.icon) {
      case IconString.bolt:
        return Icons.bolt;
      case IconString.search:
        return Icons.search;
      case IconString.radar:
        return Icons.radar;
      case IconString.security:
        return Icons.security;
      case IconString.wifi:
        return Icons.wifi_tethering;
      case IconString.route:
        return Icons.route;
      case IconString.shield:
        return Icons.shield;
      case IconString.bug:
        return Icons.bug_report;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(100);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withAlpha(15)
            : isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary.withAlpha(80) : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(_getIcon(), size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scanType.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                      Text(scanType.description, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(100))),
                    ],
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _HostResultCard extends StatelessWidget {
  final NmapHostResult host;
  final bool isDark;
  final ThemeData theme;

  const _HostResultCard({required this.host, required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    final openPorts = host.ports.where((p) => p.isOpen).toList();
    final filteredPorts = host.ports.where((p) => p.isFiltered).toList();
    final closedPorts = host.ports.where((p) => p.isClosed).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Host header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (host.state == 'up' ? AppTheme.success : AppTheme.error).withAlpha(10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: host.state == 'up' ? AppTheme.success : AppTheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        host.address,
                        style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (host.hostname != null)
                        Text(host.hostname!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (host.state == 'up' ? AppTheme.success : AppTheme.error).withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    host.state.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: host.state == 'up' ? AppTheme.success : AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // OS & Latency
          if (host.osGuess != null || host.latency != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (host.osGuess != null) ...[
                    Icon(Icons.computer, size: 14, color: theme.colorScheme.onSurface.withAlpha(100)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(host.osGuess!, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120)))),
                  ],
                  if (host.latency != null) ...[
                    Icon(Icons.timer, size: 14, color: theme.colorScheme.onSurface.withAlpha(100)),
                    const SizedBox(width: 4),
                    Text('${host.latency!.inMilliseconds}ms', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120))),
                  ],
                ],
              ),
            ),

          // Port counts summary
          if (host.ports.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  if (openPorts.isNotEmpty)
                    _PortCountBadge(count: openPorts.length, label: 'open', color: AppTheme.success),
                  if (filteredPorts.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _PortCountBadge(count: filteredPorts.length, label: 'filtered', color: Colors.orange),
                  ],
                  if (closedPorts.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _PortCountBadge(count: closedPorts.length, label: 'closed', color: AppTheme.error),
                  ],
                ],
              ),
            ),

          // Open ports list
          if (openPorts.isNotEmpty) ...[
            const Divider(height: 1),
            ...openPorts.map((port) => ListTile(
              dense: true,
              leading: Icon(Icons.lock_open, size: 18, color: AppTheme.success),
              title: Text(
                '${port.port}/${port.protocol}  ${port.serviceName}',
                style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              subtitle: port.serviceVersion != null
                  ? Text(
                      '${port.serviceVersion}${port.extraInfo != null ? ' (${port.extraInfo})' : ''}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(100)),
                    )
                  : null,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('OPEN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.success)),
              ),
            )),
          ],

          // Filtered ports list (show only a few)
          if (filteredPorts.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${filteredPorts.length} filtered port(s): ${filteredPorts.take(10).map((p) => p.port).join(', ')}${filteredPorts.length > 10 ? '...' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PortCountBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _PortCountBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
