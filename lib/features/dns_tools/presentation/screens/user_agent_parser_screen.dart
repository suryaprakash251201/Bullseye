import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/themes/app_theme.dart';

class UserAgentParserScreen extends StatefulWidget {
  const UserAgentParserScreen({super.key});

  @override
  State<UserAgentParserScreen> createState() => _UserAgentParserScreenState();
}

class _UserAgentParserScreenState extends State<UserAgentParserScreen> {
  final _uaController = TextEditingController();
  Map<String, String> _parsed = {};
  bool _showParsed = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with a default user agent hint
    _uaController.text = '';
  }

  void _parse() {
    final ua = _uaController.text.trim();
    if (ua.isEmpty) return;

    final result = <String, String>{};
    result['Raw'] = ua;

    // Browser detection
    if (ua.contains('Firefox/')) {
      final v = RegExp(r'Firefox/([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['Browser'] = 'Firefox $v';
    } else if (ua.contains('Edg/')) {
      final v = RegExp(r'Edg/([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['Browser'] = 'Microsoft Edge $v';
    } else if (ua.contains('OPR/') || ua.contains('Opera')) {
      final v = RegExp(r'OPR/([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['Browser'] = 'Opera $v';
    } else if (ua.contains('Chrome/')) {
      final v = RegExp(r'Chrome/([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['Browser'] = 'Chrome $v';
    } else if (ua.contains('Safari/') && !ua.contains('Chrome')) {
      final v = RegExp(r'Version/([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['Browser'] = 'Safari $v';
    } else if (ua.contains('curl/')) {
      final v = RegExp(r'curl/([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['Browser'] = 'curl $v';
    } else {
      result['Browser'] = 'Unknown';
    }

    // Engine
    if (ua.contains('Gecko/')) {
      result['Engine'] = 'Gecko';
    } else if (ua.contains('AppleWebKit/')) {
      final v = RegExp(r'AppleWebKit/([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['Engine'] = 'WebKit $v';
    } else if (ua.contains('Trident/')) {
      result['Engine'] = 'Trident';
    }

    // OS detection
    if (ua.contains('Windows NT 10.0')) {
      result['OS'] = 'Windows 10/11';
    } else if (ua.contains('Windows NT 6.3')) {
      result['OS'] = 'Windows 8.1';
    } else if (ua.contains('Windows NT 6.1')) {
      result['OS'] = 'Windows 7';
    } else if (ua.contains('Mac OS X')) {
      final v = RegExp(r'Mac OS X ([\d_]+)').firstMatch(ua)?.group(1)?.replaceAll('_', '.') ?? '';
      result['OS'] = 'macOS $v';
    } else if (ua.contains('Android')) {
      final v = RegExp(r'Android ([\d.]+)').firstMatch(ua)?.group(1) ?? '';
      result['OS'] = 'Android $v';
    } else if (ua.contains('iPhone') || ua.contains('iPad')) {
      final v = RegExp(r'OS ([\d_]+)').firstMatch(ua)?.group(1)?.replaceAll('_', '.') ?? '';
      result['OS'] = 'iOS $v';
    } else if (ua.contains('Linux')) {
      result['OS'] = 'Linux';
    } else {
      result['OS'] = 'Unknown';
    }

    // Device type
    if (ua.contains('Mobile') || ua.contains('Android') || ua.contains('iPhone')) {
      result['Device'] = 'Mobile';
    } else if (ua.contains('iPad') || ua.contains('Tablet')) {
      result['Device'] = 'Tablet';
    } else if (ua.contains('Bot') || ua.contains('bot') || ua.contains('Crawler') || ua.contains('Spider')) {
      result['Device'] = 'Bot/Crawler';
    } else {
      result['Device'] = 'Desktop';
    }

    // Bot check
    final isBotPattern = RegExp(r'bot|crawl|spider|slurp|mediapartners|Googlebot|Bingbot|Baiduspider|YandexBot', caseSensitive: false);
    result['Is Bot'] = isBotPattern.hasMatch(ua) ? 'Yes' : 'No';

    setState(() {
      _parsed = result;
      _showParsed = true;
    });
  }

  @override
  void dispose() {
    _uaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('User-Agent Parser')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _uaController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'User-Agent String',
              hintText: 'Paste a user-agent string here...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste),
                tooltip: 'Paste from clipboard',
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _uaController.text = data!.text!;
                    _parse();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          FilledButton.icon(
            onPressed: _parse,
            icon: const Icon(Icons.analytics, size: 20),
            label: const Text('Parse'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 24),

          if (_showParsed && _parsed.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: _parsed.entries.where((e) => e.key != 'Raw').map((e) {
                  IconData icon;
                  Color color;
                  switch (e.key) {
                    case 'Browser':
                      icon = Icons.language;
                      color = Colors.blue;
                      break;
                    case 'Engine':
                      icon = Icons.settings;
                      color = Colors.purple;
                      break;
                    case 'OS':
                      icon = Icons.computer;
                      color = Colors.teal;
                      break;
                    case 'Device':
                      icon = Icons.devices;
                      color = Colors.orange;
                      break;
                    case 'Is Bot':
                      icon = Icons.smart_toy;
                      color = e.value == 'Yes' ? AppTheme.error : AppTheme.success;
                      break;
                    default:
                      icon = Icons.info;
                      color = Colors.grey;
                  }

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    title: Text(e.key, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.w500)),
                    subtitle: Text(e.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
