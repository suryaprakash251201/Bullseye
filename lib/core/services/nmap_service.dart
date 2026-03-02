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
        // Fallback to pure-Dart scanner
        return fallbackScan(
          target: target,
          scanType: scanType,
          customPorts: customPorts,
          onOutput: onOutput,
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

  /// Pure-Dart fallback scanner using Socket.connect()
  /// Used when Nmap CLI is not installed
  Future<NmapScanResult> fallbackScan({
    required String target,
    required NmapScanType scanType,
    String? customPorts,
    void Function(String line)? onOutput,
  }) async {
    final stopwatch = Stopwatch()..start();
    final commandStr = '[Dart Fallback] Port scan on $target';
    onOutput?.call('Nmap not found — using built-in Dart scanner...');

    // For ping-only scan types, just check host reachability
    if (scanType == NmapScanType.ping || scanType == NmapScanType.quickTraceroute) {
      try {
        onOutput?.call('Checking host reachability...');
        final sw = Stopwatch()..start();
        final addresses = await InternetAddress.lookup(target);
        sw.stop();
        if (addresses.isNotEmpty) {
          stopwatch.stop();
          onOutput?.call('Host $target is up (${sw.elapsedMilliseconds}ms)');
          return NmapScanResult(
            hosts: [
              NmapHostResult(
                address: addresses.first.address,
                hostname: target,
                state: 'up',
                latency: sw.elapsed,
              ),
            ],
            scanDuration: stopwatch.elapsed,
            rawOutput: 'Host $target is up. Latency: ${sw.elapsedMilliseconds}ms',
            scanCommand: commandStr,
          );
        }
      } catch (e) {
        stopwatch.stop();
        return NmapScanResult(
          hosts: [NmapHostResult(address: target, state: 'down')],
          scanDuration: stopwatch.elapsed,
          rawOutput: 'Host $target appears to be down: $e',
          scanCommand: commandStr,
        );
      }
    }

    // Port scan
    List<int> ports;
    if (customPorts != null && customPorts.isNotEmpty) {
      ports = _parsePortList(customPorts);
    } else {
      // Common ports
      ports = [21, 22, 23, 25, 53, 80, 110, 135, 139, 143, 443, 445, 993, 995, 1433, 1521, 3306, 3389, 5432, 5900, 8080, 8443, 8888];
    }

    final resultPorts = <NmapPortResult>[];
    final outputBuffer = StringBuffer();
    outputBuffer.writeln('Dart fallback scanner — scanning ${ports.length} ports on $target');
    onOutput?.call('Scanning ${ports.length} ports on $target...');

    // Resolve hostname first
    String resolvedAddress = target;
    try {
      final addresses = await InternetAddress.lookup(target);
      if (addresses.isNotEmpty) {
        resolvedAddress = addresses.first.address;
      }
    } catch (_) {}

    // Scan ports in batches of 20
    for (int i = 0; i < ports.length; i += 20) {
      final batch = ports.skip(i).take(20).toList();
      final futures = batch.map((port) async {
        try {
          final sw = Stopwatch()..start();
          final socket = await Socket.connect(target, port, timeout: const Duration(seconds: 2));
          sw.stop();
          socket.destroy();
          final service = _guessService(port);
          onOutput?.call('Port $port ($service): OPEN (${sw.elapsedMilliseconds}ms)');
          return NmapPortResult(
            port: port,
            protocol: 'tcp',
            state: 'open',
            serviceName: service,
          );
        } catch (_) {
          return NmapPortResult(
            port: port,
            protocol: 'tcp',
            state: 'closed',
            serviceName: _guessService(port),
          );
        }
      });

      final batchResults = await Future.wait(futures);
      resultPorts.addAll(batchResults);
      onOutput?.call('Scanned ${(i + batch.length).clamp(0, ports.length)}/${ports.length} ports...');
    }

    stopwatch.stop();
    final openPorts = resultPorts.where((p) => p.isOpen).length;
    outputBuffer.writeln('Scan complete: $openPorts open ports found in ${stopwatch.elapsed.inSeconds}s');
    onOutput?.call('Done: $openPorts open ports found');

    return NmapScanResult(
      hosts: [
        NmapHostResult(
          address: resolvedAddress,
          hostname: target != resolvedAddress ? target : null,
          state: 'up',
          ports: resultPorts,
        ),
      ],
      scanDuration: stopwatch.elapsed,
      rawOutput: outputBuffer.toString(),
      scanCommand: commandStr,
    );
  }

  List<int> _parsePortList(String text) {
    final ports = <int>{};
    for (final part in text.split(',')) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final range = trimmed.split('-');
        if (range.length == 2) {
          final start = int.tryParse(range[0].trim());
          final end = int.tryParse(range[1].trim());
          if (start != null && end != null && start <= end && start >= 1 && end <= 65535) {
            for (int p = start; p <= end; p++) {
              ports.add(p);
            }
          }
        }
      } else {
        final port = int.tryParse(trimmed);
        if (port != null && port >= 1 && port <= 65535) {
          ports.add(port);
        }
      }
    }
    return ports.toList()..sort();
  }

  String _guessService(int port) {
    const services = {
      21: 'ftp', 22: 'ssh', 23: 'telnet', 25: 'smtp', 53: 'dns',
      80: 'http', 110: 'pop3', 135: 'msrpc', 139: 'netbios-ssn',
      143: 'imap', 443: 'https', 445: 'microsoft-ds', 993: 'imaps',
      995: 'pop3s', 1433: 'ms-sql-s', 1521: 'oracle', 3306: 'mysql',
      3389: 'ms-wbt-server', 5432: 'postgresql', 5900: 'vnc',
      8080: 'http-proxy', 8443: 'https-alt', 8888: 'sun-answerbook',
    };
    return services[port] ?? 'unknown';
  }
}
