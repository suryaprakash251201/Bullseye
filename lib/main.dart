import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/themes/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'config/main_shell.dart';

// Feature screens
import 'features/ssh/presentation/screens/ssh_client_screen.dart';
import 'features/ftp/presentation/screens/ftp_client_screen.dart';
import 'features/wifi_analyzer/presentation/screens/wifi_analyzer_screen.dart';
import 'features/ping_traceroute/presentation/screens/ping_traceroute_screen.dart';
import 'features/dns_tools/presentation/screens/dns_lookup_screen.dart';
import 'features/port_checker/presentation/screens/port_checker_screen.dart';
import 'features/port_checker/presentation/screens/nmap_scanner_screen.dart';
import 'features/network_scanner/presentation/screens/network_scanner_screen.dart';
import 'features/ssl_inspector/presentation/screens/ssl_inspector_screen.dart';
import 'features/whois_lookup/presentation/screens/whois_lookup_screen.dart';
import 'features/bandwidth_monitor/presentation/screens/bandwidth_monitor_screen.dart';
import 'features/speedtest/presentation/screens/speedtest_screen.dart';
import 'features/speedtest/presentation/screens/ookla_speedtest_screen.dart';
import 'features/dns_tools/presentation/screens/subnet_calculator_screen.dart';
import 'features/dns_tools/presentation/screens/http_headers_screen.dart';
import 'features/dns_tools/presentation/screens/ip_geolocation_screen.dart';
import 'features/dns_tools/presentation/screens/hash_generator_screen.dart';
import 'features/dns_tools/presentation/screens/base64_tool_screen.dart';
import 'features/dns_tools/presentation/screens/user_agent_parser_screen.dart';
import 'features/dns_tools/presentation/screens/cron_parser_screen.dart';
import 'features/website_monitor/presentation/screens/add_monitor_screen.dart';
import 'features/connections/presentation/screens/add_connection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('connections');
  await Hive.openBox('monitors');
  await Hive.openBox('history');
  await Hive.openBox('settings');
  await Hive.openBox('snippets');

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E21),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: BullseyeApp()));
}

class BullseyeApp extends ConsumerWidget {
  const BullseyeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Bullseye',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainShell(),
      routes: {
        '/ssh': (context) => const SSHClientScreen(),
        '/ftp': (context) => const FTPClientScreen(),
        '/wifi': (context) => const WiFiAnalyzerScreen(),
        '/ping': (context) => const PingTracerouteScreen(),
        '/dns': (context) => const DNSLookupScreen(),
        '/port-checker': (context) => const PortCheckerScreen(),
        '/nmap': (context) => const NmapScannerScreen(),
        '/network-scanner': (context) => const NetworkScannerScreen(),
        '/ssl': (context) => const SSLInspectorScreen(),
        '/whois': (context) => const WhoisLookupScreen(),
        '/bandwidth': (context) => const BandwidthMonitorScreen(),
        '/speedtest': (context) => const SpeedTestScreen(),
        '/ookla-speedtest': (context) => const OoklaSpeedtestScreen(),
        '/subnet': (context) => const SubnetCalculatorScreen(),
        '/http-headers': (context) => const HttpHeadersScreen(),
        '/ip-geo': (context) => const IpGeolocationScreen(),
        '/hash': (context) => const HashGeneratorScreen(),
        '/base64': (context) => const Base64ToolScreen(),
        '/user-agent': (context) => const UserAgentParserScreen(),
        '/cron': (context) => const CronParserScreen(),
        '/add-monitor': (context) => const AddMonitorScreen(),
        '/add-connection': (context) => const AddConnectionScreen(),
      },
    );
  }
}
