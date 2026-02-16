import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../../core/themes/app_theme.dart';

class IpGeolocationScreen extends StatefulWidget {
  const IpGeolocationScreen({super.key});

  @override
  State<IpGeolocationScreen> createState() => _IpGeolocationScreenState();
}

class _IpGeolocationScreenState extends State<IpGeolocationScreen> {
  final _ipController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String _error = '';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  void initState() {
    super.initState();
    // Fetch own IP on init
    _lookup('');
  }

  Future<void> _lookup(String ip) async {
    setState(() {
      _isLoading = true;
      _error = '';
      _result = null;
    });

    try {
      final target = ip.trim().isEmpty ? '' : '/$ip';
      final response = await _dio.get('http://ip-api.com/json$target?fields=status,message,continent,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,query,mobile,proxy,hosting');

      if (response.data['status'] == 'fail') {
        setState(() => _error = response.data['message'] ?? 'Lookup failed');
      } else {
        setState(() => _result = response.data);
      }
    } on DioException catch (e) {
      setState(() => _error = e.message ?? 'Network error');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
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
      appBar: AppBar(title: const Text('IP Geolocation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    hintText: 'IP or leave blank for your IP',
                    prefixIcon: const Icon(Icons.public),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onSubmitted: (v) => _lookup(v),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _isLoading ? null : () => _lookup(_ipController.text),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),

          if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error, style: const TextStyle(color: AppTheme.error)),
            ),

          if (_result != null) ...[
            // IP header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withAlpha(15),
                    theme.colorScheme.primary.withAlpha(5),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withAlpha(30)),
              ),
              child: Column(
                children: [
                  Icon(Icons.public, size: 40, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    _result!['query'] ?? '',
                    style: GoogleFonts.jetBrainsMono(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_result!['city']}, ${_result!['regionName']}, ${_result!['country']}',
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Location info
            _SectionCard(
              title: 'Location',
              icon: Icons.location_on,
              color: Colors.red,
              isDark: isDark,
              rows: [
                _Row('Country', '${_result!['country']} (${_result!['countryCode']})'),
                _Row('Region', _result!['regionName'] ?? ''),
                _Row('City', _result!['city'] ?? ''),
                _Row('ZIP', _result!['zip'] ?? ''),
                _Row('Continent', _result!['continent'] ?? ''),
                _Row('Timezone', _result!['timezone'] ?? ''),
                _Row('Coordinates', '${_result!['lat']}, ${_result!['lon']}'),
              ],
            ),
            const SizedBox(height: 12),

            // Network info
            _SectionCard(
              title: 'Network',
              icon: Icons.router,
              color: Colors.blue,
              isDark: isDark,
              rows: [
                _Row('ISP', _result!['isp'] ?? ''),
                _Row('Organization', _result!['org'] ?? ''),
                _Row('AS', _result!['as'] ?? ''),
                _Row('AS Name', _result!['asname'] ?? ''),
              ],
            ),
            const SizedBox(height: 12),

            // Flags
            _SectionCard(
              title: 'Flags',
              icon: Icons.flag,
              color: Colors.orange,
              isDark: isDark,
              rows: [
                _Row('Mobile', _result!['mobile'] == true ? 'Yes' : 'No'),
                _Row('Proxy/VPN', _result!['proxy'] == true ? 'Yes' : 'No'),
                _Row('Hosting/DC', _result!['hosting'] == true ? 'Yes' : 'No'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  _Row(this.label, this.value);
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;
  final List<_Row> rows;

  const _SectionCard({required this.title, required this.icon, required this.color, required this.isDark, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(r.label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey[500], fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: r.value));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: ${r.value}'), duration: const Duration(seconds: 1)));
                        },
                        child: Text(r.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
