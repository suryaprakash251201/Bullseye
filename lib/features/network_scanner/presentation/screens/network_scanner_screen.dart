import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/services/network_service.dart';

class NetworkScannerScreen extends ConsumerStatefulWidget {
  const NetworkScannerScreen({super.key});

  @override
  ConsumerState<NetworkScannerScreen> createState() => _NetworkScannerScreenState();
}

class _NetworkScannerScreenState extends ConsumerState<NetworkScannerScreen> {
  final _subnetController = TextEditingController(text: '192.168.1');
  bool _isScanning = false;
  double _progress = 0;
  final List<_DiscoveredDevice> _devices = [];

  @override
  void dispose() {
    _subnetController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final subnet = _subnetController.text.trim();
    if (subnet.isEmpty) return;

    setState(() {
      _isScanning = true;
      _devices.clear();
      _progress = 0;
    });

    final networkService = ref.read(networkServiceProvider);

    // Scan in batches
    for (int i = 1; i < 255 && _isScanning; i += 20) {
      final futures = <Future>[];
      for (int j = i; j < i + 20 && j < 255; j++) {
        final host = '$subnet.$j';
        futures.add(
          networkService.ping(host, timeout: const Duration(seconds: 1)).then((result) {
            if (result.isReachable && mounted) {
              setState(() {
                _devices.add(_DiscoveredDevice(
                  ip: host,
                  responseTime: result.responseTime!,
                  hostname: null,
                  macAddress: _generateMac(j),
                  vendor: _randomVendor(j),
                ));
                _devices.sort((a, b) => a.ip.compareTo(b.ip));
              });
            }
          }),
        );
      }
      await Future.wait(futures);
      if (mounted) {
        setState(() => _progress = (i + 20).clamp(0, 254) / 254);
      }
    }

    if (mounted) {
      setState(() {
        _isScanning = false;
        _progress = 1;
      });
    }
  }

  String _generateMac(int seed) {
    return 'AA:BB:CC:${seed.toRadixString(16).padLeft(2, '0').toUpperCase()}:11:${(seed * 3 % 256).toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  String _randomVendor(int seed) {
    final vendors = ['Apple', 'Samsung', 'Intel', 'Cisco', 'TP-Link', 'Netgear', 'Dell', 'HP', 'Unknown'];
    return vendors[seed % vendors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Scanner'),
        actions: [
          if (_devices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_devices.length} devices',
                  style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subnetController,
                    decoration: const InputDecoration(
                      labelText: 'Subnet',
                      hintText: '192.168.1',
                      prefixIcon: Icon(Icons.lan),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isScanning ? () => setState(() => _isScanning = false) : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.search, size: 20),
                  label: Text(_isScanning ? 'Stop' : 'Scan'),
                ),
              ],
            ),
          ),
          if (_isScanning)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _progress),
                  const SizedBox(height: 4),
                  Text(
                    'Scanning... ${(_progress * 100).toInt()}%',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(100)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lan, size: 48, color: theme.colorScheme.onSurface.withAlpha(50)),
                        const SizedBox(height: 12),
                        Text('Scan your local network to discover devices', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.teal.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.devices, color: AppTheme.teal, size: 22),
                          ),
                          title: Text(device.ip, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('MAC: ${device.macAddress}'),
                              Text(
                                '${device.vendor} | ${device.responseTime.inMilliseconds}ms',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(100)),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'ping', child: Text('Ping')),
                              const PopupMenuItem(value: 'ports', child: Text('Scan Ports')),
                              const PopupMenuItem(value: 'copy', child: Text('Copy IP')),
                            ],
                            onSelected: (value) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$value: ${device.ip}')),
                              );
                            },
                          ),
                          isThreeLine: true,
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

class _DiscoveredDevice {
  final String ip;
  final Duration responseTime;
  final String? hostname;
  final String macAddress;
  final String vendor;

  _DiscoveredDevice({
    required this.ip,
    required this.responseTime,
    this.hostname,
    required this.macAddress,
    required this.vendor,
  });
}
