import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../../core/themes/app_theme.dart';

class HttpHeadersScreen extends ConsumerStatefulWidget {
  const HttpHeadersScreen({super.key});

  @override
  ConsumerState<HttpHeadersScreen> createState() => _HttpHeadersScreenState();
}

class _HttpHeadersScreenState extends ConsumerState<HttpHeadersScreen> {
  final _urlController = TextEditingController(text: 'https://');
  bool _isLoading = false;
  String _method = 'GET';
  int? _statusCode;
  String _statusMessage = '';
  Duration _responseTime = Duration.zero;
  Map<String, String> _requestHeaders = {};
  Map<String, String> _responseHeaders = {};
  String _error = '';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    followRedirects: false,
    validateStatus: (s) => true,
  ));

  Future<void> _fetch() async {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _statusCode = null;
      _responseHeaders = {};
      _requestHeaders = {};
    });

    final stopwatch = Stopwatch()..start();
    try {
      final Response response;
      switch (_method) {
        case 'HEAD':
          response = await _dio.head(url);
          break;
        case 'POST':
          response = await _dio.post(url);
          break;
        case 'OPTIONS':
          response = await _dio.request(url, options: Options(method: 'OPTIONS'));
          break;
        default:
          response = await _dio.get(url);
      }
      stopwatch.stop();

      final respHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        respHeaders[name] = values.join(', ');
      });

      // Build request headers
      final reqHeaders = <String, String>{};
      reqHeaders['Method'] = _method;
      reqHeaders['URL'] = url;
      response.requestOptions.headers.forEach((key, value) {
        reqHeaders[key] = value.toString();
      });

      setState(() {
        _statusCode = response.statusCode;
        _statusMessage = response.statusMessage ?? '';
        _responseTime = stopwatch.elapsed;
        _responseHeaders = respHeaders;
        _requestHeaders = reqHeaders;
      });
    } on DioException catch (e) {
      stopwatch.stop();
      setState(() {
        _error = e.message ?? 'Connection failed';
        _responseTime = stopwatch.elapsed;
      });
    } catch (e) {
      stopwatch.stop();
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('HTTP Headers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // URL + Method
          Row(
            children: [
              // Method selector
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withAlpha(80)),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _method,
                    items: ['GET', 'HEAD', 'POST', 'OPTIONS']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))))
                        .toList(),
                    onChanged: (v) => setState(() => _method = v!),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'https://example.com',
                    prefixIcon: const Icon(Icons.link, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  onSubmitted: (_) => _fetch(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isLoading ? null : _fetch,
            icon: Icon(_isLoading ? Icons.hourglass_top : Icons.send, size: 18),
            label: Text(_isLoading ? 'Loading…' : 'Send Request'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),

          // Error
          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withAlpha(40)),
              ),
              child: Text(_error, style: const TextStyle(color: AppTheme.error, fontSize: 13)),
            ),

          // Status
          if (_statusCode != null) ...[
            _StatusBanner(statusCode: _statusCode!, message: _statusMessage, responseTime: _responseTime, isDark: isDark),
            const SizedBox(height: 16),
          ],

          // Response headers
          if (_responseHeaders.isNotEmpty) ...[
            _HeaderSection(title: 'Response Headers', headers: _responseHeaders, isDark: isDark, color: Colors.blue),
            const SizedBox(height: 12),
          ],

          // Request headers
          if (_requestHeaders.isNotEmpty) ...[
            _HeaderSection(title: 'Request Headers', headers: _requestHeaders, isDark: isDark, color: Colors.teal),
          ],

          // Security headers check
          if (_responseHeaders.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SecurityHeadersCheck(headers: _responseHeaders, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final int statusCode;
  final String message;
  final Duration responseTime;
  final bool isDark;

  const _StatusBanner({required this.statusCode, required this.message, required this.responseTime, required this.isDark});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (statusCode < 300) {
      color = AppTheme.success;
    } else if (statusCode < 400) {
      color = Colors.orange;
    } else {
      color = AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$statusCode',
              style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                Text('${responseTime.inMilliseconds}ms', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String title;
  final Map<String, String> headers;
  final bool isDark;
  final Color color;

  const _HeaderSection({required this.title, required this.headers, required this.isDark, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy all',
              onPressed: () {
                final text = headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Headers copied'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: headers.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${e.key}: ',
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                      TextSpan(
                        text: e.value,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SecurityHeadersCheck extends StatelessWidget {
  final Map<String, String> headers;
  final bool isDark;

  const _SecurityHeadersCheck({required this.headers, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lowerHeaders = headers.map((k, v) => MapEntry(k.toLowerCase(), v));

    final checks = <_SecurityCheck>[
      _SecurityCheck('Strict-Transport-Security', lowerHeaders.containsKey('strict-transport-security'), 'HSTS missing'),
      _SecurityCheck('Content-Security-Policy', lowerHeaders.containsKey('content-security-policy'), 'CSP missing'),
      _SecurityCheck('X-Frame-Options', lowerHeaders.containsKey('x-frame-options'), 'Clickjacking risk'),
      _SecurityCheck('X-Content-Type-Options', lowerHeaders.containsKey('x-content-type-options'), 'MIME sniffing risk'),
      _SecurityCheck('X-XSS-Protection', lowerHeaders.containsKey('x-xss-protection'), 'XSS protection missing'),
      _SecurityCheck('Referrer-Policy', lowerHeaders.containsKey('referrer-policy'), 'Referrer leaking'),
      _SecurityCheck('Permissions-Policy', lowerHeaders.containsKey('permissions-policy'), 'Feature policy missing'),
    ];

    final score = checks.where((c) => c.present).length;
    final total = checks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Security Headers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (score >= 5 ? AppTheme.success : score >= 3 ? Colors.orange : AppTheme.error).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$score / $total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: score >= 5 ? AppTheme.success : score >= 3 ? Colors.orange : AppTheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...checks.map((c) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                c.present ? Icons.check_circle : Icons.cancel,
                color: c.present ? AppTheme.success : AppTheme.error,
                size: 20,
              ),
              title: Text(c.header, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: c.present ? null : Text(c.risk, style: TextStyle(fontSize: 11, color: AppTheme.error.withAlpha(180))),
            )),
      ],
    );
  }
}

class _SecurityCheck {
  final String header;
  final bool present;
  final String risk;
  _SecurityCheck(this.header, this.present, this.risk);
}
