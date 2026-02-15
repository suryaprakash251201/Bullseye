import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

final wifiServiceProvider = Provider<WiFiService>((ref) {
  return WiFiService();
});

class WiFiNetworkInfo {
  final String ssid;
  final String bssid;
  final int signalStrength;
  final int frequency;
  final int channel;
  final String security;
  final bool isConnected;
  final int? channelWidth;
  final String? standard;

  WiFiNetworkInfo({
    required this.ssid,
    required this.bssid,
    required this.signalStrength,
    required this.frequency,
    required this.channel,
    required this.security,
    this.isConnected = false,
    this.channelWidth,
    this.standard,
  });
}

class CurrentWiFiInfo {
  final String? ssid;
  final String? bssid;
  final String? ipv4;
  final String? ipv6;
  final String? gateway;
  final String? submask;
  final String? broadcast;

  CurrentWiFiInfo({
    this.ssid,
    this.bssid,
    this.ipv4,
    this.ipv6,
    this.gateway,
    this.submask,
    this.broadcast,
  });

  bool get isConnected => ssid != null && ssid!.isNotEmpty;
}

enum WiFiScanPermissionStatus {
  granted,
  denied,
  notSupported,
  locationRequired,
  locationDisabled,
}

class WiFiServiceException implements Exception {
  final String message;
  WiFiServiceException(this.message);

  @override
  String toString() => 'WiFiServiceException: $message';
}

class WiFiService {
  final WiFiScan _wifiScan = WiFiScan.instance;
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<WiFiScanPermissionStatus> checkPermissions() async {
    if (Platform.isWindows) {
      return WiFiScanPermissionStatus.granted;
    }

    if (Platform.isAndroid) {
      final locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        return WiFiScanPermissionStatus.denied;
      }
    }

    final canScan = await _wifiScan.canStartScan();
    switch (canScan) {
      case CanStartScan.yes:
        return WiFiScanPermissionStatus.granted;
      case CanStartScan.notSupported:
        return WiFiScanPermissionStatus.notSupported;
      case CanStartScan.noLocationPermissionRequired:
      case CanStartScan.noLocationPermissionDenied:
      case CanStartScan.noLocationPermissionUpgradeAccuracy:
        return WiFiScanPermissionStatus.locationRequired;
      case CanStartScan.noLocationServiceDisabled:
        return WiFiScanPermissionStatus.locationDisabled;
      default:
        return WiFiScanPermissionStatus.denied;
    }
  }

  Future<List<WiFiNetworkInfo>> scanNetworks() async {
    if (Platform.isWindows) {
      return _scanWindowsNetworks();
    }

    final canScan = await _wifiScan.canStartScan();
    if (canScan == CanStartScan.yes) {
      await _wifiScan.startScan();
    }

    final canGetResults = await _wifiScan.canGetScannedResults();
    if (canGetResults != CanGetScannedResults.yes) {
      throw WiFiServiceException('Cannot get scan results: $canGetResults');
    }

    final accessPoints = await _wifiScan.getScannedResults();
    final currentInfo = await getCurrentConnection();
    final currentBssid = currentInfo.bssid?.toLowerCase();

    return accessPoints.map((ap) {
      final channel = _frequencyToChannel(ap.frequency);
      return WiFiNetworkInfo(
        ssid: ap.ssid.isNotEmpty ? ap.ssid : '<Hidden Network>',
        bssid: ap.bssid,
        signalStrength: ap.level,
        frequency: ap.frequency,
        channel: channel,
        security: _parseCapabilities(ap.capabilities),
        isConnected:
            currentBssid != null && ap.bssid.toLowerCase() == currentBssid,
        channelWidth: _channelWidthToMHz(ap.channelWidth),
        standard: _standardToString(ap.standard),
      );
    }).toList()
      ..sort((a, b) => b.signalStrength.compareTo(a.signalStrength));
  }

  Stream<List<WiFiAccessPoint>> get onScannedResultsAvailable {
    if (Platform.isWindows) {
      return const Stream<List<WiFiAccessPoint>>.empty();
    }
    return _wifiScan.onScannedResultsAvailable;
  }

  Future<CurrentWiFiInfo> getCurrentConnection() async {
    if (Platform.isWindows) {
      return _getWindowsCurrentConnection();
    }

    try {
      final wifiName = await _networkInfo.getWifiName();
      final wifiBSSID = await _networkInfo.getWifiBSSID();
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiIPv6 = await _networkInfo.getWifiIPv6();
      final wifiGatewayIP = await _networkInfo.getWifiGatewayIP();
      final wifiSubmask = await _networkInfo.getWifiSubmask();
      final wifiBroadcast = await _networkInfo.getWifiBroadcast();

      return CurrentWiFiInfo(
        ssid: wifiName?.replaceAll('"', ''),
        bssid: wifiBSSID,
        ipv4: wifiIP,
        ipv6: wifiIPv6,
        gateway: wifiGatewayIP,
        submask: wifiSubmask,
        broadcast: wifiBroadcast,
      );
    } catch (_) {
      return CurrentWiFiInfo();
    }
  }

  Future<List<WiFiNetworkInfo>> _scanWindowsNetworks() async {
    final current = await _getWindowsCurrentConnection();

    final result = await Process.run(
      'netsh',
      const ['wlan', 'show', 'networks', 'mode=Bssid'],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw WiFiServiceException(
        'Failed to scan WiFi networks on Windows: ${result.stderr}',
      );
    }

    final lines = const LineSplitter().convert(result.stdout.toString());
    final networks = <WiFiNetworkInfo>[];

    String currentSsid = '';
    String currentAuth = 'Unknown';
    String? bssid;
    int? signalPercent;
    int? channel;

    void flushBssid() {
      if (bssid == null || signalPercent == null || channel == null) return;
      final level = _percentToDbm(signalPercent!);
      final normalizedBssid = bssid!.toLowerCase();
      final connectedBssid = current.bssid?.toLowerCase();
      final isConnected =
          connectedBssid != null && normalizedBssid == connectedBssid;

      networks.add(
        WiFiNetworkInfo(
          ssid: currentSsid.isEmpty ? '<Hidden Network>' : currentSsid,
          bssid: bssid!,
          signalStrength: level,
          frequency: _channelToFrequency(channel!),
          channel: channel!,
          security: _normalizeWindowsAuth(currentAuth),
          isConnected: isConnected,
        ),
      );

      bssid = null;
      signalPercent = null;
      channel = null;
    }

    final ssidRegex = RegExp(r'^\s*SSID\s+\d+\s*:\s*(.+)$');
    final authRegex = RegExp(r'^\s*Authentication\s*:\s*(.+)$');
    final bssidRegex = RegExp(r'^\s*BSSID\s+\d+\s*:\s*(.+)$');
    final signalRegex = RegExp(r'^\s*Signal\s*:\s*(\d+)%\s*$');
    final channelRegex = RegExp(r'^\s*Channel\s*:\s*(\d+)\s*$');

    for (final rawLine in lines) {
      final line = rawLine.trimRight();

      final ssidMatch = ssidRegex.firstMatch(line);
      if (ssidMatch != null) {
        flushBssid();
        currentSsid = ssidMatch.group(1)?.trim() ?? '';
        currentAuth = 'Unknown';
        continue;
      }

      final authMatch = authRegex.firstMatch(line);
      if (authMatch != null) {
        currentAuth = authMatch.group(1)?.trim() ?? 'Unknown';
        continue;
      }

      final bssidMatch = bssidRegex.firstMatch(line);
      if (bssidMatch != null) {
        flushBssid();
        bssid = bssidMatch.group(1)?.trim();
        continue;
      }

      final signalMatch = signalRegex.firstMatch(line);
      if (signalMatch != null) {
        signalPercent = int.tryParse(signalMatch.group(1) ?? '');
        continue;
      }

      final channelMatch = channelRegex.firstMatch(line);
      if (channelMatch != null) {
        channel = int.tryParse(channelMatch.group(1) ?? '');
        flushBssid();
      }
    }

    flushBssid();
    networks.sort((a, b) => b.signalStrength.compareTo(a.signalStrength));
    return networks;
  }

  Future<CurrentWiFiInfo> _getWindowsCurrentConnection() async {
    final result = await Process.run(
      'netsh',
      const ['wlan', 'show', 'interfaces'],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      return CurrentWiFiInfo();
    }

    final output = result.stdout.toString();
    final lines = const LineSplitter().convert(output);

    String? ssid;
    String? bssid;

    bool connected = false;
    final stateRegex = RegExp(r'^\s*State\s*:\s*(.+)$', caseSensitive: false);
    final ssidRegex = RegExp(r'^\s*SSID\s*:\s*(.+)$');
    final bssidRegex = RegExp(r'^\s*BSSID\s*:\s*(.+)$');

    for (final line in lines) {
      final stateMatch = stateRegex.firstMatch(line);
      if (stateMatch != null) {
        final stateValue = (stateMatch.group(1) ?? '').trim().toLowerCase();
        connected = stateValue.contains('connected') &&
            !stateValue.contains('disconnected');
        continue;
      }

      final ssidMatch = ssidRegex.firstMatch(line);
      if (ssidMatch != null && !line.trimLeft().startsWith('BSSID')) {
        ssid = ssidMatch.group(1)?.trim();
        continue;
      }

      final bssidMatch = bssidRegex.firstMatch(line);
      if (bssidMatch != null) {
        bssid = bssidMatch.group(1)?.trim();
      }
    }

    if (!connected) {
      return CurrentWiFiInfo();
    }

    final mobileInfo = await _safeGetCurrentConnectionViaPlugin();
    final windowsIp = await _getWindowsIpInfo();

    return CurrentWiFiInfo(
      ssid: (ssid == null || ssid.isEmpty || ssid == '<unknown ssid>')
          ? mobileInfo.ssid
          : ssid,
      bssid: bssid ?? mobileInfo.bssid,
      ipv4: mobileInfo.ipv4 ?? windowsIp.ipv4,
      ipv6: mobileInfo.ipv6,
      gateway: mobileInfo.gateway ?? windowsIp.gateway,
      submask: mobileInfo.submask ?? windowsIp.submask,
      broadcast: mobileInfo.broadcast,
    );
  }

  Future<CurrentWiFiInfo> _safeGetCurrentConnectionViaPlugin() async {
    try {
      final wifiName = await _networkInfo.getWifiName();
      final wifiBSSID = await _networkInfo.getWifiBSSID();
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiIPv6 = await _networkInfo.getWifiIPv6();
      final wifiGatewayIP = await _networkInfo.getWifiGatewayIP();
      final wifiSubmask = await _networkInfo.getWifiSubmask();
      final wifiBroadcast = await _networkInfo.getWifiBroadcast();

      return CurrentWiFiInfo(
        ssid: wifiName?.replaceAll('"', ''),
        bssid: wifiBSSID,
        ipv4: wifiIP,
        ipv6: wifiIPv6,
        gateway: wifiGatewayIP,
        submask: wifiSubmask,
        broadcast: wifiBroadcast,
      );
    } catch (_) {
      return CurrentWiFiInfo();
    }
  }

  Future<_WindowsIpInfo> _getWindowsIpInfo() async {
    final result = await Process.run('ipconfig', const [], runInShell: true);
    if (result.exitCode != 0) {
      return const _WindowsIpInfo();
    }

    final text = result.stdout.toString();
    final blockRegex = RegExp(
      r'Wireless LAN adapter[\s\S]*?(?=\r?\n\r?\n|\$)',
      caseSensitive: false,
    );

    final match = blockRegex.firstMatch(text);
    if (match == null) {
      return const _WindowsIpInfo();
    }

    final block = match.group(0) ?? '';
    if (block.toLowerCase().contains('media disconnected')) {
      return const _WindowsIpInfo();
    }

    final ipv4 = _extractValue(block, RegExp(r'IPv4[^:]*:\s*([0-9\.]+)'));
    final submask =
        _extractValue(block, RegExp(r'Subnet Mask[^:]*:\s*([0-9\.]+)'));
    final gateway =
        _extractValue(block, RegExp(r'Default Gateway[^:]*:\s*([0-9\.]+)'));

    return _WindowsIpInfo(ipv4: ipv4, submask: submask, gateway: gateway);
  }

  String? _extractValue(String text, RegExp regex) {
    final match = regex.firstMatch(text);
    return match?.group(1)?.trim();
  }

  int _percentToDbm(int percent) {
    final clamped = percent.clamp(0, 100);
    return (clamped / 2 - 100).round();
  }

  int _channelToFrequency(int channel) {
    if (channel == 14) return 2484;
    if (channel >= 1 && channel <= 13) return 2407 + channel * 5;
    if (channel >= 32 && channel <= 177) return 5000 + channel * 5;
    return 0;
  }

  int _frequencyToChannel(int frequency) {
    if (frequency >= 2412 && frequency <= 2484) {
      if (frequency == 2484) return 14;
      return ((frequency - 2412) ~/ 5) + 1;
    }
    if (frequency >= 5170 && frequency <= 7115) {
      return ((frequency - 5000) ~/ 5);
    }
    return 0;
  }

  String _parseCapabilities(String capabilities) {
    final upper = capabilities.toUpperCase();
    if (upper.contains('WPA3')) return 'WPA3';
    if (upper.contains('WPA2') && upper.contains('WPA-')) return 'WPA/WPA2';
    if (upper.contains('WPA2')) return 'WPA2';
    if (upper.contains('WPA')) return 'WPA';
    if (upper.contains('WEP')) return 'WEP';
    if (upper.contains('ESS') && !upper.contains('WPA') && !upper.contains('WEP')) {
      return 'Open';
    }
    return 'Unknown';
  }

  String _normalizeWindowsAuth(String auth) {
    final value = auth.toLowerCase();
    if (value.contains('wpa3')) return 'WPA3';
    if (value.contains('wpa2')) return 'WPA2';
    if (value.contains('wpa')) return 'WPA';
    if (value.contains('wep')) return 'WEP';
    if (value.contains('open')) return 'Open';
    return auth;
  }

  int? _channelWidthToMHz(WiFiChannelWidth? width) {
    if (width == null) return null;
    switch (width) {
      case WiFiChannelWidth.mhz20:
        return 20;
      case WiFiChannelWidth.mhz40:
        return 40;
      case WiFiChannelWidth.mhz80:
        return 80;
      case WiFiChannelWidth.mhz160:
        return 160;
      case WiFiChannelWidth.mhz80Plus80:
        return 160;
      default:
        return null;
    }
  }

  String? _standardToString(WiFiStandards standard) {
    switch (standard) {
      case WiFiStandards.legacy:
        return '802.11a/b/g';
      case WiFiStandards.n:
        return '802.11n';
      case WiFiStandards.ac:
        return '802.11ac';
      case WiFiStandards.ax:
        return '802.11ax';
      case WiFiStandards.ad:
        return '802.11ad';
      default:
        return null;
    }
  }
}

class _WindowsIpInfo {
  final String? ipv4;
  final String? submask;
  final String? gateway;

  const _WindowsIpInfo({this.ipv4, this.submask, this.gateway});
}
