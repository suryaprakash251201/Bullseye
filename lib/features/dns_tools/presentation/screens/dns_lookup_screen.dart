import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

class DNSLookupScreen extends ConsumerStatefulWidget {
  const DNSLookupScreen({super.key});

  @override
  ConsumerState<DNSLookupScreen> createState() => _DNSLookupScreenState();
}

class _DNSLookupScreenState extends ConsumerState<DNSLookupScreen> {
  final _hostController = TextEditingController();
  String _selectedType = 'A';
  bool _isLoading = false;
  List<_DNSRecord> _results = [];
  String? _error;

  Future<void> _lookup() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results = [];
      _error = null;
    });

    try {
      final typeCode = _dnsTypeToCode(_selectedType);
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));

      final response = await dio.get(
        'https://dns.google/resolve',
        queryParameters: {
          'name': host,
          'type': typeCode,
        },
      );

      final data = response.data;
      final records = <_DNSRecord>[];
      if (data is Map && data['Answer'] is List) {
        final answers = data['Answer'] as List;
        for (final item in answers) {
          if (item is! Map) continue;
          final type = _dnsCodeToType(item['type']);
          final value = (item['data'] ?? '').toString();
          final ttl = (item['TTL'] is int) ? item['TTL'] as int : 0;
          if (type == null || value.isEmpty) continue;

          records.add(_DNSRecord(
            type: type,
            name: (item['name'] ?? host).toString(),
            value: value,
            ttl: ttl,
            priority: _extractPriority(type, value),
          ));
        }
      }

      if (records.isEmpty && (_selectedType == 'A' || _selectedType == 'AAAA')) {
        final addresses = await InternetAddress.lookup(host);
        for (final addr in addresses) {
          final type = addr.type == InternetAddressType.IPv4 ? 'A' : 'AAAA';
          if (_selectedType != type) continue;
          records.add(_DNSRecord(type: type, name: host, value: addr.address, ttl: 0));
        }
      }

      setState(() => _results = records);

      if (records.isEmpty) {
        setState(() {
          _error = 'No $_selectedType records found for $host';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DNS Lookup'),
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
                    labelText: 'Domain Name',
                    hintText: 'example.com',
                    prefixIcon: Icon(Icons.dns),
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: AppConstants.dnsRecordTypes.map((type) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(type),
                                selected: _selectedType == type,
                                onSelected: (_) => setState(() => _selectedType = type),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isLoading ? null : _lookup,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Lookup'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: AppTheme.error.withAlpha(20),
                child: ListTile(
                  leading: const Icon(Icons.error, color: AppTheme.error),
                  title: Text(_error!, style: const TextStyle(color: AppTheme.error)),
                ),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.dns, size: 48, color: theme.colorScheme.onSurface.withAlpha(50)),
                        const SizedBox(height: 12),
                        Text(
                          'Enter a domain and select record type',
                          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final record = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _typeColor(record.type).withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              record.type,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _typeColor(record.type),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(record.value, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            'TTL: ${record.ttl}s${record.priority != null ? ' | Priority: ${record.priority}' : ''}',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(100)),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied: ${record.value}')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'A': return Colors.blue;
      case 'AAAA': return Colors.indigo;
      case 'MX': return Colors.orange;
      case 'NS': return Colors.green;
      case 'TXT': return Colors.purple;
      case 'CNAME': return Colors.teal;
      case 'SOA': return Colors.brown;
      default: return Colors.grey;
    }
  }

  int _dnsTypeToCode(String type) {
    switch (type) {
      case 'A':
        return 1;
      case 'NS':
        return 2;
      case 'CNAME':
        return 5;
      case 'SOA':
        return 6;
      case 'PTR':
        return 12;
      case 'MX':
        return 15;
      case 'TXT':
        return 16;
      case 'AAAA':
        return 28;
      case 'SRV':
        return 33;
      default:
        return 1;
    }
  }

  String? _dnsCodeToType(dynamic code) {
    final value = code is int ? code : int.tryParse(code.toString());
    switch (value) {
      case 1:
        return 'A';
      case 2:
        return 'NS';
      case 5:
        return 'CNAME';
      case 6:
        return 'SOA';
      case 12:
        return 'PTR';
      case 15:
        return 'MX';
      case 16:
        return 'TXT';
      case 28:
        return 'AAAA';
      case 33:
        return 'SRV';
      default:
        return null;
    }
  }

  int? _extractPriority(String type, String value) {
    if (type != 'MX' && type != 'SRV') return null;
    final tokens = value.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;
    return int.tryParse(tokens.first);
  }
}

class _DNSRecord {
  final String type;
  final String name;
  final String value;
  final int ttl;
  final int? priority;

  _DNSRecord({
    required this.type,
    required this.name,
    required this.value,
    required this.ttl,
    this.priority,
  });
}
