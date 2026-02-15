import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_theme.dart';

class WhoisLookupScreen extends ConsumerStatefulWidget {
  const WhoisLookupScreen({super.key});

  @override
  ConsumerState<WhoisLookupScreen> createState() => _WhoisLookupScreenState();
}

class _WhoisLookupScreenState extends ConsumerState<WhoisLookupScreen> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, String>? _info;
  String? _error;

  Future<void> _lookup() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _info = null;
      _error = null;
    });

    try {
      final server = await _resolveWhoisServer(query);
      final raw = await _queryWhois(server, query);
      final parsed = _parseWhois(raw);

      setState(() {
        _info = parsed.isEmpty ? {'Raw Data': raw} : parsed;
      });
    } catch (e) {
      setState(() => _error = 'WHOIS lookup failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _resolveWhoisServer(String query) async {
    final isIp = InternetAddress.tryParse(query) != null;
    if (isIp) return 'whois.arin.net';

    final tld = query.toLowerCase().split('.').last;
    final ianaReply = await _queryWhois('whois.iana.org', tld);

    for (final line in const LineSplitter().convert(ianaReply)) {
      if (line.toLowerCase().startsWith('whois:')) {
        final server = line.split(':').skip(1).join(':').trim();
        if (server.isNotEmpty) return server;
      }
    }

    return 'whois.verisign-grs.com';
  }

  Future<String> _queryWhois(String server, String query) async {
    final socket = await Socket.connect(
      server,
      43,
      timeout: const Duration(seconds: 10),
    );

    final completer = Completer<String>();
    final buffer = StringBuffer();

    socket.write('$query\r\n');
    await socket.flush();

    socket.listen(
      (data) => buffer.write(utf8.decode(data, allowMalformed: true)),
      onDone: () {
        socket.destroy();
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
      onError: (error) {
        socket.destroy();
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      cancelOnError: true,
    );

    return completer.future.timeout(const Duration(seconds: 15));
  }

  Map<String, String> _parseWhois(String raw) {
    final result = <String, String>{};
    final lines = const LineSplitter().convert(raw);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('%') || trimmed.startsWith('#')) {
        continue;
      }

      final separatorIndex = trimmed.indexOf(':');
      if (separatorIndex <= 0) continue;

      final key = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;

      if (!result.containsKey(key)) {
        result[key] = value;
      }

      if (result.length >= 40) break;
    }

    return result;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Whois Lookup')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Domain or IP',
                      hintText: 'example.com',
                      prefixIcon: Icon(Icons.info_outline),
                    ),
                    onSubmitted: (_) => _lookup(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isLoading ? null : _lookup,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Lookup'),
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
                  title: Text(_error!),
                ),
              ),
            ),
          Expanded(
            child: _info == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: theme.colorScheme.onSurface.withAlpha(50)),
                        const SizedBox(height: 12),
                        Text('Enter a domain or IP address', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _info!.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                entry.value,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
