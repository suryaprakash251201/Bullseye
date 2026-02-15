import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/wifi_service.dart';

class WiFiAnalyzerScreen extends ConsumerStatefulWidget {
  const WiFiAnalyzerScreen({super.key});

  @override
  ConsumerState<WiFiAnalyzerScreen> createState() => _WiFiAnalyzerScreenState();
}

class _WiFiAnalyzerScreenState extends ConsumerState<WiFiAnalyzerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<WiFiNetworkInfo> _networks = [];
  CurrentWiFiInfo? _currentConnection;
  bool _isScanning = false;
  bool _autoRefresh = false;
  Timer? _autoRefreshTimer;
  String? _errorMessage;
  WiFiScanPermissionStatus? _permissionStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initAndScan();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initAndScan() async {
    final wifiService = ref.read(wifiServiceProvider);

    // Check permissions first
    final status = await wifiService.checkPermissions();
    setState(() {
      _permissionStatus = status;
    });

    if (status == WiFiScanPermissionStatus.granted) {
      await _scanNetworks();
    }
  }

  Future<void> _scanNetworks() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final wifiService = ref.read(wifiServiceProvider);

      // Get current connection info
      final currentInfo = await wifiService.getCurrentConnection();

      // Scan for nearby networks
      final networks = await wifiService.scanNetworks();

      // Sort by signal strength (strongest first)
      networks.sort(
          (a, b) => b.signalStrength.compareTo(a.signalStrength));

      if (!mounted) return;
      setState(() {
        _networks = networks;
        _currentConnection = currentInfo;
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });
    if (_autoRefresh) {
      _autoRefreshTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _scanNetworks(),
      );
    } else {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Analyzer'),
        actions: [
          // Auto-refresh toggle
          IconButton(
            icon: Icon(
              _autoRefresh ? Icons.sync : Icons.sync_disabled,
              color: _autoRefresh ? AppTheme.success : null,
            ),
            onPressed: _toggleAutoRefresh,
            tooltip: _autoRefresh ? 'Stop auto-refresh' : 'Auto-refresh (5s)',
          ),
          // Manual refresh
          IconButton(
            icon: _isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanNetworks,
            tooltip: 'Scan now',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Networks', icon: Icon(Icons.wifi, size: 18)),
            Tab(text: 'Channels', icon: Icon(Icons.bar_chart, size: 18)),
            Tab(text: 'Signal', icon: Icon(Icons.signal_cellular_alt, size: 18)),
          ],
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Handle permission issues
    if (_permissionStatus != null &&
        _permissionStatus != WiFiScanPermissionStatus.granted) {
      return _buildPermissionView(theme);
    }

    // Handle errors
    if (_errorMessage != null && _networks.isEmpty) {
      return _buildErrorView(theme);
    }

    // Handle empty state
    if (_networks.isEmpty && !_isScanning) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_find, size: 64, color: theme.colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text('No networks found', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _scanNetworks,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildNetworksList(theme),
        _buildChannelChart(theme),
        _buildSignalView(theme),
      ],
    );
  }

  Widget _buildPermissionView(ThemeData theme) {
    String title;
    String description;
    IconData icon;

    switch (_permissionStatus!) {
      case WiFiScanPermissionStatus.denied:
        title = 'Permission Required';
        description =
            'WiFi scanning requires location permission. Please grant access in app settings.';
        icon = Icons.lock;
        break;
      case WiFiScanPermissionStatus.notSupported:
        title = 'Not Supported';
        description =
            'WiFi scanning is not supported on this device.';
        icon = Icons.error_outline;
        break;
      case WiFiScanPermissionStatus.locationRequired:
        title = 'Location Permission Needed';
        description =
            'Android requires location permission to scan WiFi networks. Please grant access.';
        icon = Icons.location_off;
        break;
      case WiFiScanPermissionStatus.locationDisabled:
        title = 'Location Services Disabled';
        description =
            'Please enable location services to scan WiFi networks.';
        icon = Icons.location_disabled;
        break;
      case WiFiScanPermissionStatus.granted:
        return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppTheme.warning),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(140)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _initAndScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('Scan Error', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(140)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _scanNetworks,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Networks list tab ────────────────────

  Widget _buildNetworksList(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _scanNetworks,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _networks.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Text(
                    '${_networks.length} network${_networks.length != 1 ? 's' : ''} found',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                    ),
                  ),
                  const Spacer(),
                  if (_isScanning)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('Scanning...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            )),
                      ],
                    ),
                ],
              ),
            );
          }

          final network = _networks[index - 1];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: _SignalIcon(
                  strength: network.signalStrength,
                  isConnected: network.isConnected),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      network.ssid,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: network.isConnected ? AppTheme.success : null,
                      ),
                    ),
                  ),
                  if (network.isConnected) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Connected',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.success)),
                    ),
                  ],
                ],
              ),
              subtitle: Row(
                children: [
                  _InfoChip(label: 'Ch ${network.channel}'),
                  const SizedBox(width: 4),
                  _InfoChip(label: '${network.frequency} MHz'),
                  const SizedBox(width: 4),
                  _InfoChip(
                    label: network.security,
                    color: network.security == 'Open'
                        ? AppTheme.warning
                        : AppTheme.success,
                  ),
                  if (network.standard != null) ...[
                    const SizedBox(width: 4),
                    _InfoChip(label: network.standard!),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${network.signalStrength} dBm',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _signalColor(network.signalStrength),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _signalQuality(network.signalStrength),
                    style: TextStyle(
                      fontSize: 11,
                      color: _signalColor(network.signalStrength),
                    ),
                  ),
                ],
              ),
              onTap: () => _showNetworkDetails(network),
            ),
          );
        },
      ),
    );
  }

  void _showNetworkDetails(WiFiNetworkInfo network) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SignalIcon(
                    strength: network.signalStrength,
                    isConnected: network.isConnected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(network.ssid,
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(network.bssid,
                          style: TextStyle(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .onSurface
                                  .withAlpha(100),
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            _DetailRow(label: 'Signal', value: '${network.signalStrength} dBm (${_signalQuality(network.signalStrength)})'),
            _DetailRow(label: 'Channel', value: '${network.channel}'),
            _DetailRow(label: 'Frequency', value: '${network.frequency} MHz'),
            _DetailRow(
                label: 'Band',
                value: network.frequency >= 5000 ? '5 GHz' : '2.4 GHz'),
            _DetailRow(label: 'Security', value: network.security),
            if (network.standard != null)
              _DetailRow(label: 'Standard', value: network.standard!),
            if (network.channelWidth != null)
              _DetailRow(
                  label: 'Channel Width',
                  value: '${network.channelWidth} MHz'),
            _DetailRow(label: 'BSSID', value: network.bssid),
            if (network.isConnected && _currentConnection != null) ...[
              const Divider(),
              if (_currentConnection!.ipv4 != null)
                _DetailRow(label: 'IPv4', value: _currentConnection!.ipv4!),
              if (_currentConnection!.ipv6 != null)
                _DetailRow(label: 'IPv6', value: _currentConnection!.ipv6!),
              if (_currentConnection!.gateway != null)
                _DetailRow(
                    label: 'Gateway', value: _currentConnection!.gateway!),
              if (_currentConnection!.submask != null)
                _DetailRow(
                    label: 'Subnet Mask', value: _currentConnection!.submask!),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ──────────────────── Channel chart tab ────────────────────

  Widget _buildChannelChart(ThemeData theme) {
    final channels2g = <int, List<WiFiNetworkInfo>>{};
    final channels5g = <int, List<WiFiNetworkInfo>>{};

    for (final network in _networks) {
      if (network.frequency < 5000) {
        channels2g.putIfAbsent(network.channel, () => []).add(network);
      } else {
        channels5g.putIfAbsent(network.channel, () => []).add(network);
      }
    }

    return RefreshIndicator(
      onRefresh: _scanNetworks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 2.4 GHz band
          Text('2.4 GHz Band',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${channels2g.values.fold<int>(0, (sum, list) => sum + list.length)} networks',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (channels2g.values.fold<int>(
                            0,
                            (max, list) =>
                                list.length > max ? list.length : max) +
                        1)
                    .toDouble(),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        'Ch ${value.toInt()}',
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withAlpha(120)),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(13, (i) {
                  final ch = i + 1;
                  final count = channels2g[ch]?.length ?? 0;
                  final hasConnected =
                      channels2g[ch]?.any((n) => n.isConnected) ?? false;
                  return BarChartGroupData(
                    x: ch,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: hasConnected
                            ? AppTheme.success
                            : AppTheme.primaryLight,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb,
                      color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getChannelRecommendation(channels2g),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 5 GHz band
          Text('5 GHz Band',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            '${channels5g.values.fold<int>(0, (sum, list) => sum + list.length)} networks',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ),
          const SizedBox(height: 8),
          if (channels5g.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No 5 GHz networks detected',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(100))),
              ),
            )
          else
            ...channels5g.entries.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.wifi,
                        color: AppTheme.primaryLight, size: 20),
                    title: Text('Channel ${e.key}'),
                    subtitle: Text(e.value
                        .map((n) => n.ssid)
                        .join(', ')),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${e.value.length} network${e.value.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 12)),
                        Text(
                            '${e.value.first.signalStrength} dBm',
                            style: TextStyle(
                                fontSize: 11,
                                color: _signalColor(
                                    e.value.first.signalStrength))),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  // ──────────────────── Signal view tab ────────────────────

  Widget _buildSignalView(ThemeData theme) {
    // Find the connected network, or fallback to strongest
    final connected = _networks.cast<WiFiNetworkInfo?>().firstWhere(
          (n) => n!.isConnected,
          orElse: () => _networks.isNotEmpty ? _networks.first : null,
        );

    if (connected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64,
                color: theme.colorScheme.onSurface.withAlpha(60)),
            const SizedBox(height: 16),
            Text('No WiFi connection',
                style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    final qualityPercent = _signalToPercent(connected.signalStrength);

    return RefreshIndicator(
      onRefresh: _scanNetworks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Signal gauge
          Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: qualityPercent / 100,
                        strokeWidth: 12,
                        backgroundColor:
                            theme.colorScheme.onSurface.withAlpha(20),
                        color: _signalColor(connected.signalStrength),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${qualityPercent.toInt()}%',
                          style: theme.textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _signalQuality(connected.signalStrength),
                          style: TextStyle(
                              color: _signalColor(
                                  connected.signalStrength)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  connected.ssid,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${connected.signalStrength} dBm',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(140)),
                ),
                if (connected.isConnected)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Currently Connected',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.success)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Connection details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Network Details',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Divider(),
                  _DetailRow(label: 'SSID', value: connected.ssid),
                  _DetailRow(label: 'BSSID', value: connected.bssid),
                  _DetailRow(
                      label: 'Channel',
                      value: '${connected.channel}'),
                  _DetailRow(
                      label: 'Frequency',
                      value: '${connected.frequency} MHz'),
                  _DetailRow(label: 'Security', value: connected.security),
                  _DetailRow(
                      label: 'Band',
                      value: connected.frequency >= 5000
                          ? '5 GHz'
                          : '2.4 GHz'),
                  if (connected.standard != null)
                    _DetailRow(label: 'Standard', value: connected.standard!),
                  if (connected.channelWidth != null)
                    _DetailRow(
                        label: 'Channel Width',
                        value: '${connected.channelWidth} MHz'),
                ],
              ),
            ),
          ),

          // IP info card (if connected)
          if (_currentConnection != null &&
              _currentConnection!.isConnected) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connection Info',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Divider(),
                    if (_currentConnection!.ipv4 != null)
                      _DetailRow(
                          label: 'IPv4',
                          value: _currentConnection!.ipv4!),
                    if (_currentConnection!.ipv6 != null)
                      _DetailRow(
                          label: 'IPv6',
                          value: _currentConnection!.ipv6!),
                    if (_currentConnection!.gateway != null)
                      _DetailRow(
                          label: 'Gateway',
                          value: _currentConnection!.gateway!),
                    if (_currentConnection!.submask != null)
                      _DetailRow(
                          label: 'Subnet Mask',
                          value: _currentConnection!.submask!),
                    if (_currentConnection!.broadcast != null)
                      _DetailRow(
                          label: 'Broadcast',
                          value: _currentConnection!.broadcast!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────── Helpers ────────────────────

  String _getChannelRecommendation(
      Map<int, List<WiFiNetworkInfo>> channels) {
    final preferred = [1, 6, 11];
    int bestChannel = 1;
    int minNetworks = 999;

    for (final ch in preferred) {
      final count = channels[ch]?.length ?? 0;
      if (count < minNetworks) {
        minNetworks = count;
        bestChannel = ch;
      }
    }

    if (minNetworks == 0) {
      return 'Recommended: Channel $bestChannel (no congestion detected)';
    }
    return 'Recommended: Channel $bestChannel ($minNetworks network${minNetworks > 1 ? 's' : ''}, least congested of 1/6/11)';
  }

  Color _signalColor(int strength) {
    if (strength >= -50) return AppTheme.success;
    if (strength >= -60) return Colors.lightGreen;
    if (strength >= -70) return AppTheme.warning;
    if (strength >= -80) return Colors.orange;
    return AppTheme.error;
  }

  String _signalQuality(int strength) {
    if (strength >= -50) return 'Excellent';
    if (strength >= -60) return 'Good';
    if (strength >= -70) return 'Fair';
    if (strength >= -80) return 'Weak';
    return 'Very Weak';
  }

  double _signalToPercent(int strength) {
    return ((100 + strength) * 2).clamp(0, 100).toDouble();
  }
}

// ──────────────────── Shared widgets ────────────────────

class _SignalIcon extends StatelessWidget {
  final int strength;
  final bool isConnected;

  const _SignalIcon({required this.strength, this.isConnected = false});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    if (strength >= -50) {
      icon = Icons.signal_wifi_4_bar;
      color = AppTheme.success;
    } else if (strength >= -60) {
      icon = Icons.network_wifi_3_bar;
      color = Colors.lightGreen;
    } else if (strength >= -70) {
      icon = Icons.network_wifi_2_bar;
      color = AppTheme.warning;
    } else if (strength >= -80) {
      icon = Icons.network_wifi_1_bar;
      color = Colors.orange;
    } else {
      icon = Icons.signal_wifi_0_bar;
      color = AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _InfoChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (color ?? Theme.of(context).colorScheme.primary).withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color ??
              Theme.of(context).colorScheme.onSurface.withAlpha(140),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(120))),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
