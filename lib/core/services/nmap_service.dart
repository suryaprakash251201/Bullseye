import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nmapServiceProvider = Provider<NmapService>((ref) {
  return NmapService();
});

/// Represents a single host result from an Nmap scan
class NmapHostResult {
  final String address;
  final String? hostname;
  final String state; // up / down
  final List<NmapPortResult> ports;
  final String? osGuess;
  final Duration? latency;

  NmapHostResult({
    required this.address,
    this.hostname,
    required this.state,
    this.ports = const [],
    this.osGuess,
    this.latency,
  });
}

/// Represents a single port result from Nmap
class NmapPortResult {
  final int port;
  final String protocol; // tcp / udp
  final String state; // open / closed / filtered
  final String serviceName;
  final String? serviceVersion;
  final String? extraInfo;

  NmapPortResult({
    required this.port,
    required this.protocol,
    required this.state,
    required this.serviceName,
    this.serviceVersion,
    this.extraInfo,
  });

  bool get isOpen => state == 'open';
  bool get isFiltered => state == 'filtered';
  bool get isClosed => state == 'closed';
}

/// Nmap scan type presets
enum NmapScanType {
  quick,        // -T4 -F
  regular,      // -sV
  intense,      // -T4 -A -v
  intensePlus,  // -T4 -A -v --version-all
  ping,         // -sn
  quickTraceroute, // -sn --traceroute
  comprehensive,   // -sS -sU -T4 -A -v -PE -PP
  vulnScan,        // --script vuln
}

extension NmapScanTypeExtension on NmapScanType {
  String get label {
    switch (this) {
      case NmapScanType.quick:
        return 'Quick Scan';
      case NmapScanType.regular:
        return 'Regular Scan';
      case NmapScanType.intense:
        return 'Intense Scan';
      case NmapScanType.intensePlus:
        return 'Intense + All Versions';
      case NmapScanType.ping:
        return 'Ping Scan';
      case NmapScanType.quickTraceroute:
        return 'Quick Traceroute';
      case NmapScanType.comprehensive:
        return 'Comprehensive';
      case NmapScanType.vulnScan:
        return 'Vulnerability Scan';
    }
  }

  String get description {
    switch (this) {
      case NmapScanType.quick:
        return 'Fast scan of common ports';
      case NmapScanType.regular:
        return 'Service version detection';
      case NmapScanType.intense:
        return 'OS detection, version, scripts, traceroute';
      case NmapScanType.intensePlus:
        return 'Intense with extended version probing';
      case NmapScanType.ping:
        return 'Host discovery only, no port scan';
      case NmapScanType.quickTraceroute:
        return 'Ping + traceroute to target';
      case NmapScanType.comprehensive:
        return 'Full TCP/UDP scan with deep analysis';
      case NmapScanType.vulnScan:
        return 'Run vulnerability detection scripts';
    }
  }

  IconString get icon {
    switch (this) {
      case NmapScanType.quick:
        return IconString.bolt;
      case NmapScanType.regular:
        return IconString.search;
      case NmapScanType.intense:
        return IconString.radar;
      case NmapScanType.intensePlus:
        return IconString.security;
      case NmapScanType.ping:
        return IconString.wifi;
      case NmapScanType.quickTraceroute:
        return IconString.route;
      case NmapScanType.comprehensive:
        return IconString.shield;
      case NmapScanType.vulnScan:
        return IconString.bug;
    }
  }

  List<String> toArgs(String target) {
    switch (this) {
      case NmapScanType.quick:
        return ['-T4', '-F', '-oX', '-', target];
      case NmapScanType.regular:
        return ['-sV', '-oX', '-', target];
      case NmapScanType.intense:
        return ['-T4', '-A', '-v', '-oX', '-', target];
      case NmapScanType.intensePlus:
        return ['-T4', '-A', '-v', '--version-all', '-oX', '-', target];
      case NmapScanType.ping:
        return ['-sn', '-oX', '-', target];
      case NmapScanType.quickTraceroute:
        return ['-sn', '--traceroute', '-oX', '-', target];
      case NmapScanType.comprehensive:
        return ['-sS', '-sU', '-T4', '-A', '-v', '-oX', '-', target];
      case NmapScanType.vulnScan:
        return ['--script', 'vuln', '-oX', '-', target];
    }
  }
}

/// Just a helper enum for icon selection (mapped in the UI)
enum IconString { bolt, search, radar, security, wifi, route, shield, bug }

/// Full result of an nmap scan
class NmapScanResult {
  final List<NmapHostResult> hosts;
  final Duration scanDuration;
  final String rawOutput;
  final String? error;
  final String scanCommand;
  final DateTime timestamp;

  NmapScanResult({
    this.hosts = const [],
    this.scanDuration = Duration.zero,
    this.rawOutput = '',
    this.error,
    this.scanCommand = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  int get totalOpenPorts =>
      hosts.fold(0, (sum, h) => sum + h.ports.where((p) => p.isOpen).length);
  int get totalHosts => hosts.length;
  int get hostsUp => hosts.where((h) => h.state == 'up').length;
}

/// Service for running Nmap scans via CLI
class NmapService {
  String _nmapPath = 'nmap';
  bool _isAvailable = false;
  String _version = '';

  bool get isAvailable => _isAvailable;
  String get version => _version;

  /// Check if nmap is installed and get its version
  Future<bool> checkAvailability() async {
    try {
      final result = await Process.run(_nmapPath, ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        _isAvailable = true;
        final output = result.stdout.toString();
        final versionMatch = RegExp(r'Nmap version (\S+)').firstMatch(output);
        _version = versionMatch?.group(1) ?? 'Unknown';
        return true;
      }
    } catch (_) {}

    // Try common installation paths
    final paths = Platform.isWindows
        ? [
            r'C:\Program Files (x86)\Nmap\nmap.exe',
            r'C:\Program Files\Nmap\nmap.exe',
          ]
        : ['/usr/bin/nmap', '/usr/local/bin/nmap'];

    for (final path in paths) {
      if (await File(path).exists()) {
        _nmapPath = path;
        try {
          final result = await Process.run(_nmapPath, ['--version'], runInShell: true);
          if (result.exitCode == 0) {
            _isAvailable = true;
            final output = result.stdout.toString();
            final versionMatch = RegExp(r'Nmap version (\S+)').firstMatch(output);
            _version = versionMatch?.group(1) ?? 'Unknown';
            return true;
          }
        } catch (_) {}
      }
    }

    _isAvailable = false;
    return false;
  }

  /// Run an nmap scan with a preset scan type
  Future<NmapScanResult> scan({
    required String target,
    required NmapScanType scanType,
    String? customPorts,
    void Function(String line)? onOutput,
  }) async {
    if (!_isAvailable) {
      await checkAvailability();
      if (!_isAvailable) {
        return NmapScanResult(
          error: 'Nmap is not installed. Please install Nmap to use this feature.',
          scanCommand: 'nmap ${scanType.toArgs(target).join(' ')}',
        );
      }
    }

    final args = scanType.toArgs(target);

    // Insert custom port specification if provided
    if (customPorts != null && customPorts.isNotEmpty) {
      final insertIndex = args.indexOf('-oX');
      args.insertAll(insertIndex, ['-p', customPorts]);
    }

    final commandStr = 'nmap ${args.join(' ')}';
    final stopwatch = Stopwatch()..start();
    final outputBuffer = StringBuffer();

    try {
      final process = await Process.start(
        _nmapPath,
        args,
        runInShell: true,
      );

      // Capture stdout
      process.stdout.transform(utf8.decoder).listen((data) {
        outputBuffer.write(data);
        if (onOutput != null) {
          for (final line in const LineSplitter().convert(data)) {
            onOutput(line);
          }
        }
      });

      // Capture stderr
      final stderrBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
      });

      final exitCode = await process.exitCode;
      stopwatch.stop();

      final rawOutput = outputBuffer.toString();
      final stderrOutput = stderrBuffer.toString();

      if (exitCode != 0 && rawOutput.isEmpty) {
        return NmapScanResult(
          error: stderrOutput.isNotEmpty ? stderrOutput : 'Nmap exited with code $exitCode',
          rawOutput: rawOutput,
          scanDuration: stopwatch.elapsed,
          scanCommand: commandStr,
        );
      }

      // Parse XML output
      final hosts = _parseNmapXml(rawOutput);

      return NmapScanResult(
        hosts: hosts,
        scanDuration: stopwatch.elapsed,
        rawOutput: rawOutput,
        scanCommand: commandStr,
      );
    } catch (e) {
      stopwatch.stop();
      return NmapScanResult(
        error: 'Failed to run Nmap: $e',
        scanDuration: stopwatch.elapsed,
        scanCommand: commandStr,
      );
    }
  }

  /// Run nmap with completely custom arguments
  Future<NmapScanResult> customScan({
    required String target,
    required List<String> args,
    void Function(String line)? onOutput,
  }) async {
    if (!_isAvailable) {
      await checkAvailability();
      if (!_isAvailable) {
        return NmapScanResult(
          error: 'Nmap is not installed.',
          scanCommand: 'nmap ${args.join(' ')} $target',
        );
      }
    }

    // Ensure XML output to stdout for parsing
    final fullArgs = [...args];
    if (!fullArgs.contains('-oX')) {
      fullArgs.addAll(['-oX', '-']);
    }
    fullArgs.add(target);

    final commandStr = 'nmap ${fullArgs.join(' ')}';
    final stopwatch = Stopwatch()..start();
    final outputBuffer = StringBuffer();

    try {
      final process = await Process.start(_nmapPath, fullArgs, runInShell: true);

      process.stdout.transform(utf8.decoder).listen((data) {
        outputBuffer.write(data);
        if (onOutput != null) {
          for (final line in const LineSplitter().convert(data)) {
            onOutput(line);
          }
        }
      });

      final stderrBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
      });

      await process.exitCode;
      stopwatch.stop();

      final rawOutput = outputBuffer.toString();
      final hosts = _parseNmapXml(rawOutput);

      return NmapScanResult(
        hosts: hosts,
        scanDuration: stopwatch.elapsed,
        rawOutput: rawOutput,
        scanCommand: commandStr,
      );
    } catch (e) {
      stopwatch.stop();
      return NmapScanResult(
        error: 'Failed to run Nmap: $e',
        scanDuration: stopwatch.elapsed,
        scanCommand: commandStr,
      );
    }
  }

  /// Parse Nmap XML output into structured results
  List<NmapHostResult> _parseNmapXml(String xmlOutput) {
    final hosts = <NmapHostResult>[];

    try {
      // Simple XML-like parsing without a full XML library
      final hostBlocks = _extractBlocks(xmlOutput, 'host');

      for (final hostXml in hostBlocks) {
        // Parse address
        final addrMatch = RegExp(r'<address\s+addr="([^"]+)"[^/]*/?>').firstMatch(hostXml);
        final address = addrMatch?.group(1) ?? 'Unknown';

        // Parse hostname
        final hostnameMatch = RegExp(r'<hostname\s+name="([^"]+)"').firstMatch(hostXml);
        final hostname = hostnameMatch?.group(1);

        // Parse state
        final stateMatch = RegExp(r'<status\s+state="([^"]+)"').firstMatch(hostXml);
        final state = stateMatch?.group(1) ?? 'unknown';

        // Parse latency
        final latencyMatch = RegExp(r'srtt="(\d+)"').firstMatch(hostXml);
        Duration? latency;
        if (latencyMatch != null) {
          final microseconds = int.tryParse(latencyMatch.group(1) ?? '');
          if (microseconds != null) {
            latency = Duration(microseconds: microseconds);
          }
        }

        // Parse OS guess
        final osMatch = RegExp(r'<osmatch\s+name="([^"]+)"').firstMatch(hostXml);
        final osGuess = osMatch?.group(1);

        // Parse ports
        final ports = <NmapPortResult>[];
        final portMatches = RegExp(
          r'<port\s+protocol="([^"]+)"\s+portid="(\d+)"[^>]*>.*?</port>',
          dotAll: true,
        ).allMatches(hostXml);

        for (final portMatch in portMatches) {
          final protocol = portMatch.group(1) ?? 'tcp';
          final portId = int.tryParse(portMatch.group(2) ?? '') ?? 0;
          final portXml = portMatch.group(0) ?? '';

          final portStateMatch = RegExp(r'<state\s+state="([^"]+)"').firstMatch(portXml);
          final portState = portStateMatch?.group(1) ?? 'unknown';

          final serviceMatch = RegExp(r'<service\s+name="([^"]*)"').firstMatch(portXml);
          final serviceName = serviceMatch?.group(1) ?? '';

          final versionMatch = RegExp(r'version="([^"]*)"').firstMatch(portXml);
          final serviceVersion = versionMatch?.group(1);

          final extraInfoMatch = RegExp(r'extrainfo="([^"]*)"').firstMatch(portXml);
          final extraInfo = extraInfoMatch?.group(1);

          ports.add(NmapPortResult(
            port: portId,
            protocol: protocol,
            state: portState,
            serviceName: serviceName,
            serviceVersion: serviceVersion,
            extraInfo: extraInfo,
          ));
        }

        hosts.add(NmapHostResult(
          address: address,
          hostname: hostname,
          state: state,
          ports: ports,
          osGuess: osGuess,
          latency: latency,
        ));
      }
    } catch (_) {
      // If XML parsing fails, still return what we have
    }

    return hosts;
  }

  /// Extract all blocks of a given XML tag
  List<String> _extractBlocks(String xml, String tag) {
    final blocks = <String>[];
    final pattern = RegExp('<$tag[\\s>].*?</$tag>', dotAll: true);
    for (final match in pattern.allMatches(xml)) {
      blocks.add(match.group(0) ?? '');
    }
    return blocks;
  }
}
