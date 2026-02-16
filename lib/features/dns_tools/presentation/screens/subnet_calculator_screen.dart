import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SubnetCalculatorScreen extends StatefulWidget {
  const SubnetCalculatorScreen({super.key});

  @override
  State<SubnetCalculatorScreen> createState() => _SubnetCalculatorScreenState();
}

class _SubnetCalculatorScreenState extends State<SubnetCalculatorScreen> {
  final _ipController = TextEditingController(text: '192.168.1.0');
  int _cidr = 24;
  _SubnetInfo? _result;

  void _calculate() {
    final ip = _ipController.text.trim();
    if (!_isValidIp(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid IPv4 address')),
      );
      return;
    }
    setState(() => _result = _SubnetInfo.calculate(ip, _cidr));
  }

  bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Subnet Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // IP Input
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'IP Address',
              hintText: '192.168.1.0',
              prefixIcon: const Icon(Icons.computer),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _calculate(),
          ),
          const SizedBox(height: 16),

          // CIDR slider
          Row(
            children: [
              Text('CIDR: ', style: theme.textTheme.titleSmall),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '/$_cidr',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _cidr.toDouble(),
            min: 1,
            max: 32,
            divisions: 31,
            label: '/$_cidr',
            onChanged: (v) {
              setState(() => _cidr = v.round());
              _calculate();
            },
          ),
          const SizedBox(height: 8),

          // Calculate button
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate, size: 20),
            label: const Text('Calculate'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),

          // Results
          if (_result != null) ...[
            _InfoCard(
              isDark: isDark,
              children: [
                _InfoRow(label: 'Network Address', value: _result!.networkAddress, isDark: isDark, mono: true),
                _InfoRow(label: 'Broadcast Address', value: _result!.broadcastAddress, isDark: isDark, mono: true),
                _InfoRow(label: 'Subnet Mask', value: _result!.subnetMask, isDark: isDark, mono: true),
                _InfoRow(label: 'Wildcard Mask', value: _result!.wildcardMask, isDark: isDark, mono: true),
                _InfoRow(label: 'Host Range', value: '${_result!.firstHost} - ${_result!.lastHost}', isDark: isDark, mono: true),
                _InfoRow(label: 'Total Hosts', value: _result!.totalHosts.toString(), isDark: isDark),
                _InfoRow(label: 'Usable Hosts', value: _result!.usableHosts.toString(), isDark: isDark),
                _InfoRow(label: 'IP Class', value: _result!.ipClass, isDark: isDark),
                _InfoRow(label: 'Is Private', value: _result!.isPrivate ? 'Yes' : 'No', isDark: isDark),
                _InfoRow(label: 'Binary Mask', value: _result!.binaryMask, isDark: isDark, mono: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SubnetInfo {
  final String networkAddress;
  final String broadcastAddress;
  final String subnetMask;
  final String wildcardMask;
  final String firstHost;
  final String lastHost;
  final int totalHosts;
  final int usableHosts;
  final String ipClass;
  final bool isPrivate;
  final String binaryMask;

  _SubnetInfo({
    required this.networkAddress,
    required this.broadcastAddress,
    required this.subnetMask,
    required this.wildcardMask,
    required this.firstHost,
    required this.lastHost,
    required this.totalHosts,
    required this.usableHosts,
    required this.ipClass,
    required this.isPrivate,
    required this.binaryMask,
  });

  static _SubnetInfo calculate(String ip, int cidr) {
    final ipInt = _ipToInt(ip);
    final maskInt = cidr == 0 ? 0 : (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    final networkInt = ipInt & maskInt;
    final broadcastInt = networkInt | (~maskInt & 0xFFFFFFFF);
    final wildcardInt = ~maskInt & 0xFFFFFFFF;

    final totalHosts = pow(2, 32 - cidr).toInt();
    final usableHosts = cidr >= 31 ? totalHosts : totalHosts - 2;

    final firstHostInt = cidr >= 31 ? networkInt : networkInt + 1;
    final lastHostInt = cidr >= 31 ? broadcastInt : broadcastInt - 1;

    final firstOctet = (ipInt >> 24) & 0xFF;
    String ipClass;
    if (firstOctet < 128) {
      ipClass = 'A';
    } else if (firstOctet < 192) {
      ipClass = 'B';
    } else if (firstOctet < 224) {
      ipClass = 'C';
    } else if (firstOctet < 240) {
      ipClass = 'D (Multicast)';
    } else {
      ipClass = 'E (Reserved)';
    }

    bool isPrivate = false;
    if (firstOctet == 10) {
      isPrivate = true;
    } else if (firstOctet == 172 && ((ipInt >> 16) & 0xFF) >= 16 && ((ipInt >> 16) & 0xFF) <= 31) {
      isPrivate = true;
    } else if (firstOctet == 192 && ((ipInt >> 16) & 0xFF) == 168) {
      isPrivate = true;
    }

    final binaryMask = maskInt.toRadixString(2).padLeft(32, '0');
    final formattedBinary = '${binaryMask.substring(0, 8)}.${binaryMask.substring(8, 16)}.${binaryMask.substring(16, 24)}.${binaryMask.substring(24, 32)}';

    return _SubnetInfo(
      networkAddress: _intToIp(networkInt),
      broadcastAddress: _intToIp(broadcastInt),
      subnetMask: _intToIp(maskInt),
      wildcardMask: _intToIp(wildcardInt),
      firstHost: _intToIp(firstHostInt),
      lastHost: _intToIp(lastHostInt),
      totalHosts: totalHosts,
      usableHosts: usableHosts,
      ipClass: ipClass,
      isPrivate: isPrivate,
      binaryMask: formattedBinary,
    );
  }

  static int _ipToInt(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
  }

  static String _intToIp(int ip) {
    return '${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}';
  }
}

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _InfoCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final bool mono;

  const _InfoRow({required this.label, required this.value, required this.isDark, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Copied "$value"'), duration: const Duration(seconds: 1)),
                );
              },
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: mono ? GoogleFonts.jetBrainsMono().fontFamily : null,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
