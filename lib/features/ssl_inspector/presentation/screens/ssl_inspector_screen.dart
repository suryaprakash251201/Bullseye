import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/formatters.dart';

class SSLInspectorScreen extends ConsumerStatefulWidget {
  const SSLInspectorScreen({super.key});

  @override
  ConsumerState<SSLInspectorScreen> createState() => _SSLInspectorScreenState();
}

class _SSLInspectorScreenState extends ConsumerState<SSLInspectorScreen> {
  final _hostController = TextEditingController();
  bool _isLoading = false;
  _SSLCertInfo? _certInfo;
  String? _error;

  Future<void> _inspect() async {
    final host = _hostController.text.trim().replaceAll('https://', '').replaceAll('http://', '').split('/').first;
    if (host.isEmpty) return;

    setState(() {
      _isLoading = true;
      _certInfo = null;
      _error = null;
    });

    try {
      final socket = await SecureSocket.connect(
        host,
        443,
        timeout: const Duration(seconds: 10),
        onBadCertificate: (cert) => true,
      );

      final cert = socket.peerCertificate;
      if (cert != null) {
        final now = DateTime.now();
        final daysLeft = cert.endValidity.difference(now).inDays;

        setState(() {
          _certInfo = _SSLCertInfo(
            subject: cert.subject.toString(),
            issuer: cert.issuer.toString(),
            validFrom: cert.startValidity,
            validTo: cert.endValidity,
            isValid: daysLeft > 0,
            daysUntilExpiry: daysLeft,
            sha1: cert.sha1.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':'),
          );
        });
      }

      socket.destroy();
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
      appBar: AppBar(title: const Text('SSL Inspector')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Domain',
                    hintText: 'example.com',
                    prefixIcon: Icon(Icons.security),
                  ),
                  onSubmitted: (_) => _inspect(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isLoading ? null : _inspect,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Inspect'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_error != null)
            Card(
              color: AppTheme.error.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error))),
                  ],
                ),
              ),
            ),

          if (_certInfo != null) ...[
            // Status Banner
            Card(
              color: _certInfo!.isValid ? AppTheme.success.withAlpha(20) : AppTheme.error.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      _certInfo!.isValid ? Icons.verified : Icons.warning,
                      color: _certInfo!.isValid ? AppTheme.success : AppTheme.error,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _certInfo!.isValid ? 'Certificate Valid' : 'Certificate Expired',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _certInfo!.isValid ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                          Text(
                            _certInfo!.daysUntilExpiry > 0
                                ? '${_certInfo!.daysUntilExpiry} days until expiry'
                                : 'Expired ${-_certInfo!.daysUntilExpiry} days ago',
                            style: TextStyle(
                              color: _certInfo!.daysUntilExpiry > 30 ? AppTheme.success : AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Certificate Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Certificate Details', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const Divider(),
                    _CertRow(label: 'Subject', value: _certInfo!.subject),
                    _CertRow(label: 'Issuer', value: _certInfo!.issuer),
                    _CertRow(label: 'Valid From', value: Formatters.formatDateTime(_certInfo!.validFrom)),
                    _CertRow(label: 'Valid To', value: Formatters.formatDateTime(_certInfo!.validTo)),
                    _CertRow(label: 'SHA-1 Fingerprint', value: _certInfo!.sha1),
                  ],
                ),
              ),
            ),

            // Expiry Warning
            if (_certInfo!.daysUntilExpiry <= 30 && _certInfo!.daysUntilExpiry > 0)
              Card(
                color: AppTheme.warning.withAlpha(20),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber, color: AppTheme.warning),
                  title: const Text('Expiring Soon'),
                  subtitle: Text('Certificate expires in ${_certInfo!.daysUntilExpiry} days'),
                ),
              ),
          ],

          if (!_isLoading && _certInfo == null && _error == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.security, size: 48, color: theme.colorScheme.onSurface.withAlpha(50)),
                    const SizedBox(height: 12),
                    Text('Enter a domain to inspect its SSL certificate', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SSLCertInfo {
  final String subject;
  final String issuer;
  final DateTime validFrom;
  final DateTime validTo;
  final bool isValid;
  final int daysUntilExpiry;
  final String sha1;

  _SSLCertInfo({
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validTo,
    required this.isValid,
    required this.daysUntilExpiry,
    required this.sha1,
  });
}

class _CertRow extends StatelessWidget {
  final String label;
  final String value;

  const _CertRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(120))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
