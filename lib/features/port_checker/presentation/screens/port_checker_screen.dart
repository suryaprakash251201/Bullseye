import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    setState(() {
      _isScanning = true;
      _results = [];
      _progress = 0;
      _openCount = 0;
    });

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
      // Sort: open ports first
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
        if (port != null && port >= 1 && port <= 65535) {
          ports.add(port);
        }
      }
    }
    return ports.toList()..sort();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Port Scanner'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host / IP',
                    hintText: 'example.com or 192.168.1.1',
                    prefixIcon: Icon(Icons.dns),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        value: _useCommonPorts,
                        onChanged: (v) => setState(() => _useCommonPorts = v ?? true),
                        title: const Text('Common ports', style: TextStyle(fontSize: 14)),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                if (!_useCommonPorts)
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Ports',
                      hintText: '80, 443, 1000-2000',
                      prefixIcon: Icon(Icons.settings_input_component),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_results.isNotEmpty)
                      Text(
                        '$_openCount open / ${_results.length} scanned',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(120),
                          fontSize: 13,
                        ),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _isScanning ? () => setState(() => _isScanning = false) : _scan,
                      icon: Icon(_isScanning ? Icons.stop : Icons.radar, size: 20),
                      label: Text(_isScanning ? 'Stop' : 'Scan'),
                    ),
                  ],
                ),
                if (_isScanning)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(value: _progress),
                  ),
              ],
            ),
          ),
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
                      final serviceName = AppConstants.portServiceNames[r.port] ?? '';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          r.isOpen ? Icons.lock_open : Icons.lock,
                          color: r.isOpen ? AppTheme.success : AppTheme.error.withAlpha(120),
                          size: 20,
                        ),
                        title: Text(
                          'Port ${r.port}${serviceName.isNotEmpty ? ' ($serviceName)' : ''}',
                          style: TextStyle(
                            fontWeight: r.isOpen ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${r.responseTime.inMilliseconds}ms',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(100)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (r.isOpen ? AppTheme.success : AppTheme.error).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                r.isOpen ? 'OPEN' : 'CLOSED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: r.isOpen ? AppTheme.success : AppTheme.error,
                                ),
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
