import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final networkServiceProvider = Provider<NetworkService>((ref) {
  return NetworkService();
});

class PingResult {
  final String host;
  final bool isReachable;
  final Duration? responseTime;
  final String? error;
  final DateTime timestamp;

  PingResult({
    required this.host,
    required this.isReachable,
    this.responseTime,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class PortScanResult {
  final String host;
  final int port;
  final bool isOpen;
  final String? serviceName;
  final Duration responseTime;

  PortScanResult({
    required this.host,
    required this.port,
    required this.isOpen,
    this.serviceName,
    required this.responseTime,
  });
}

class TracerouteHop {
  final int hopNumber;
  final String? address;
  final Duration? responseTime;
  final bool timedOut;

  TracerouteHop({
    required this.hopNumber,
    this.address,
    this.responseTime,
    this.timedOut = false,
  });
}

class HttpCheckResult {
  final String url;
  final int? statusCode;
  final Duration responseTime;
  final bool isSuccess;
  final String? error;
  final Map<String, String>? headers;
  final DateTime timestamp;

  HttpCheckResult({
    required this.url,
    this.statusCode,
    required this.responseTime,
    required this.isSuccess,
    this.error,
    this.headers,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NetworkService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    followRedirects: true,
    validateStatus: (status) => true,
  ));

  /// Ping a host using socket connection
  Future<PingResult> ping(String host, {int port = 80, Duration timeout = const Duration(seconds: 5)}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: timeout,
      );
      stopwatch.stop();
      socket.destroy();
      return PingResult(
        host: host,
        isReachable: true,
        responseTime: stopwatch.elapsed,
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return PingResult(
        host: host,
        isReachable: false,
        responseTime: stopwatch.elapsed,
        error: e.message,
      );
    } catch (e) {
      stopwatch.stop();
      return PingResult(
        host: host,
        isReachable: false,
        error: e.toString(),
      );
    }
  }

  /// Scan a specific port
  Future<PortScanResult> scanPort(String host, int port, {Duration timeout = const Duration(seconds: 3)}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      stopwatch.stop();
      socket.destroy();
      return PortScanResult(
        host: host,
        port: port,
        isOpen: true,
        responseTime: stopwatch.elapsed,
      );
    } catch (_) {
      stopwatch.stop();
      return PortScanResult(
        host: host,
        port: port,
        isOpen: false,
        responseTime: stopwatch.elapsed,
      );
    }
  }

  /// Scan multiple ports
  Future<List<PortScanResult>> scanPorts(String host, List<int> ports, {Duration timeout = const Duration(seconds: 2)}) async {
    final results = <PortScanResult>[];
    // Scan in batches of 20
    for (var i = 0; i < ports.length; i += 20) {
      final batch = ports.skip(i).take(20);
      final batchResults = await Future.wait(
        batch.map((port) => scanPort(host, port, timeout: timeout)),
      );
      results.addAll(batchResults);
    }
    return results;
  }

  /// Check HTTP endpoint 
  Future<HttpCheckResult> checkHttp(String url) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get(url);
      stopwatch.stop();
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name] = values.join(', ');
      });
      return HttpCheckResult(
        url: url,
        statusCode: response.statusCode,
        responseTime: stopwatch.elapsed,
        isSuccess: (response.statusCode ?? 500) < 400,
        headers: headers,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return HttpCheckResult(
        url: url,
        responseTime: stopwatch.elapsed,
        isSuccess: false,
        error: e.message ?? 'Connection failed',
      );
    } catch (e) {
      stopwatch.stop();
      return HttpCheckResult(
        url: url,
        responseTime: stopwatch.elapsed,
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// DNS lookup
  Future<List<InternetAddress>> dnsLookup(String host) async {
    try {
      return await InternetAddress.lookup(host);
    } catch (e) {
      return [];
    }
  }

  /// Traceroute using native OS command output parsing
  Future<List<TracerouteHop>> traceroute(
    String host, {
    int maxHops = 30,
    Duration timeoutPerHop = const Duration(seconds: 2),
  }) async {
    final isWindows = Platform.isWindows;
    final executable = isWindows ? 'tracert' : 'traceroute';
    final args = isWindows
        ? <String>[
            '-d',
            '-h',
            '$maxHops',
            '-w',
            '${timeoutPerHop.inMilliseconds}',
            host,
          ]
        : <String>[
            '-n',
            '-m',
            '$maxHops',
            '-w',
            '${timeoutPerHop.inSeconds.clamp(1, 10)}',
            host,
          ];

    final result = await Process.run(executable, args, runInShell: true);
    if (result.exitCode != 0 && (result.stdout?.toString().isEmpty ?? true)) {
      throw SocketException(result.stderr.toString().trim());
    }

    final hops = <TracerouteHop>[];
    final lines = const LineSplitter().convert(result.stdout.toString());

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final hopMatch = RegExp(r'^(\d+)\s+').firstMatch(line);
      if (hopMatch == null) continue;

      final hopNumber = int.tryParse(hopMatch.group(1) ?? '');
      if (hopNumber == null) continue;

      final timedOut = line.contains('*') ||
          line.toLowerCase().contains('timed out') ||
          line.toLowerCase().contains('request timeout');

      final ipMatch = RegExp(r'(\d{1,3}(?:\.\d{1,3}){3})').firstMatch(line);
      final address = ipMatch?.group(1);

      final msMatches = RegExp(r'<?\s*(\d+)\s*ms', caseSensitive: false)
          .allMatches(line)
          .map((m) => int.tryParse(m.group(1) ?? ''))
          .whereType<int>()
          .toList();

      Duration? responseTime;
      if (msMatches.isNotEmpty) {
        final avg = msMatches.reduce((a, b) => a + b) / msMatches.length;
        responseTime = Duration(milliseconds: avg.round());
      }

      hops.add(
        TracerouteHop(
          hopNumber: hopNumber,
          address: address,
          responseTime: responseTime,
          timedOut: timedOut && address == null,
        ),
      );
    }

    return hops;
  }

  /// Discover devices on local network
  Future<List<String>> discoverNetwork(String subnet, {Duration timeout = const Duration(seconds: 1)}) async {
    final activeHosts = <String>[];
    final futures = <Future>[];

    for (int i = 1; i < 255; i++) {
      final host = '$subnet.$i';
      futures.add(
        ping(host, timeout: timeout).then((result) {
          if (result.isReachable) {
            activeHosts.add(host);
          }
        }),
      );
    }

    await Future.wait(futures);
    return activeHosts..sort();
  }

  void dispose() {
    _dio.close();
  }
}
