import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ooklaSpeedtestServiceProvider = Provider<OoklaSpeedtestService>((ref) {
  return OoklaSpeedtestService();
});

/// Result from Ookla Speedtest CLI
class OoklaSpeedtestResult {
  final double downloadMbps;
  final double uploadMbps;
  final double pingMs;
  final double jitterMs;
  final int packetLoss;
  final String serverName;
  final String serverLocation;
  final String serverHost;
  final int serverId;
  final String isp;
  final String externalIp;
  final String resultUrl;
  final DateTime timestamp;
  final String? error;

  OoklaSpeedtestResult({
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.pingMs = 0,
    this.jitterMs = 0,
    this.packetLoss = 0,
    this.serverName = '',
    this.serverLocation = '',
    this.serverHost = '',
    this.serverId = 0,
    this.isp = '',
    this.externalIp = '',
    this.resultUrl = '',
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasError => error != null && error!.isNotEmpty;
}

/// Server info from Ookla Speedtest
class SpeedtestServer {
  final int id;
  final String name;
  final String location;
  final String country;
  final String host;
  final int port;

  SpeedtestServer({
    required this.id,
    required this.name,
    required this.location,
    required this.country,
    required this.host,
    required this.port,
  });
}

enum SpeedtestStage {
  idle,
  checkingCli,
  selectingServer,
  testingLatency,
  testingDownload,
  testingUpload,
  complete,
  error,
}

/// Service that wraps Ookla Speedtest CLI for accurate speed measurements
class OoklaSpeedtestService {
  String _cliPath = 'speedtest';
  bool _isAvailable = false;
  String _version = '';

  bool get isAvailable => _isAvailable;
  String get version => _version;

  /// Check if Ookla Speedtest CLI is installed
  Future<bool> checkAvailability() async {
    // Try default path first
    if (await _tryPath('speedtest')) return true;

    // Try common installation paths
    final paths = Platform.isWindows
        ? [
            r'C:\Program Files\Ookla\Speedtest\speedtest.exe',
            r'C:\Program Files (x86)\Ookla\Speedtest\speedtest.exe',
            r'C:\Users\' + Platform.environment['USERNAME']! + r'\AppData\Local\Microsoft\WinGet\Links\speedtest.exe',
          ]
        : [
            '/usr/bin/speedtest',
            '/usr/local/bin/speedtest',
            '/opt/homebrew/bin/speedtest',
          ];

    for (final path in paths) {
      if (await _tryPath(path)) return true;
    }

    _isAvailable = false;
    return false;
  }

  Future<bool> _tryPath(String path) async {
    try {
      final result = await Process.run(path, ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        _cliPath = path;
        _isAvailable = true;
        final output = result.stdout.toString().trim();
        _version = output.split('\n').first;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Run the speedtest with progress callback
  Future<OoklaSpeedtestResult> runTest({
    int? serverId,
    void Function(SpeedtestStage stage, String message, double? progress)? onProgress,
  }) async {
    if (!_isAvailable) {
      await checkAvailability();
      if (!_isAvailable) {
        return OoklaSpeedtestResult(
          error: 'Ookla Speedtest CLI is not installed.\n\n'
              'Install it from: https://www.speedtest.net/apps/cli\n\n'
              'Windows: winget install Ookla.Speedtest.CLI\n'
              'macOS: brew install speedtest-cli\n'
              'Linux: See https://www.speedtest.net/apps/cli',
        );
      }
    }

    onProgress?.call(SpeedtestStage.selectingServer, 'Selecting best server...', null);

    final args = <String>[
      '--format=json-pretty',
      '--accept-license',
      '--accept-gdpr',
      '--progress=yes',
    ];

    if (serverId != null) {
      args.addAll(['--server-id', serverId.toString()]);
    }

    try {
      final process = await Process.start(_cliPath, args, runInShell: true);

      final outputBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      SpeedtestStage currentStage = SpeedtestStage.selectingServer;

      process.stdout.transform(utf8.decoder).listen((data) {
        outputBuffer.write(data);

        // Parse progress lines
        for (final line in const LineSplitter().convert(data)) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;

          // Progress updates come as JSON objects on individual lines
          if (trimmed.contains('"type":"download"') || trimmed.contains('Download')) {
            if (currentStage != SpeedtestStage.testingDownload) {
              currentStage = SpeedtestStage.testingDownload;
              onProgress?.call(SpeedtestStage.testingDownload, 'Testing download speed...', null);
            }
          } else if (trimmed.contains('"type":"upload"') || trimmed.contains('Upload')) {
            if (currentStage != SpeedtestStage.testingUpload) {
              currentStage = SpeedtestStage.testingUpload;
              onProgress?.call(SpeedtestStage.testingUpload, 'Testing upload speed...', null);
            }
          } else if (trimmed.contains('"type":"ping"') || trimmed.contains('Latency') || trimmed.contains('Idle Latency')) {
            if (currentStage != SpeedtestStage.testingLatency) {
              currentStage = SpeedtestStage.testingLatency;
              onProgress?.call(SpeedtestStage.testingLatency, 'Testing latency...', null);
            }
          }
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
      });

      final exitCode = await process.exitCode;
      final rawOutput = outputBuffer.toString();
      final stderrOutput = stderrBuffer.toString();

      if (exitCode != 0 && rawOutput.isEmpty) {
        return OoklaSpeedtestResult(
          error: stderrOutput.isNotEmpty ? stderrOutput : 'Speedtest exited with code $exitCode',
        );
      }

      // Parse the final JSON result
      return _parseResult(rawOutput);
    } catch (e) {
      return OoklaSpeedtestResult(error: 'Failed to run speedtest: $e');
    }
  }

  /// List available servers
  Future<List<SpeedtestServer>> listServers() async {
    if (!_isAvailable) {
      await checkAvailability();
      if (!_isAvailable) return [];
    }

    try {
      final result = await Process.run(
        _cliPath,
        ['--servers', '--format=json-pretty', '--accept-license', '--accept-gdpr'],
        runInShell: true,
      );

      if (result.exitCode != 0) return [];

      final json = jsonDecode(result.stdout.toString());
      final servers = <SpeedtestServer>[];

      if (json is Map && json.containsKey('servers')) {
        for (final s in json['servers']) {
          servers.add(SpeedtestServer(
            id: s['id'] ?? 0,
            name: s['name'] ?? '',
            location: s['location'] ?? '',
            country: s['country'] ?? '',
            host: s['host'] ?? '',
            port: s['port'] ?? 8080,
          ));
        }
      }

      return servers;
    } catch (_) {
      return [];
    }
  }

  /// Parse the JSON output from speedtest CLI
  OoklaSpeedtestResult _parseResult(String rawOutput) {
    try {
      // The output might contain progress lines before the final JSON
      // Find the last valid JSON object
      String jsonStr = rawOutput.trim();

      // Try to find the main result JSON (it's the largest JSON block)
      final jsonBlocks = <String>[];
      int braceCount = 0;
      int startIdx = -1;

      for (int i = 0; i < jsonStr.length; i++) {
        if (jsonStr[i] == '{') {
          if (braceCount == 0) startIdx = i;
          braceCount++;
        } else if (jsonStr[i] == '}') {
          braceCount--;
          if (braceCount == 0 && startIdx >= 0) {
            jsonBlocks.add(jsonStr.substring(startIdx, i + 1));
            startIdx = -1;
          }
        }
      }

      // Use the last (and usually largest) JSON block as the result
      if (jsonBlocks.isEmpty) {
        return OoklaSpeedtestResult(error: 'No valid JSON output from speedtest');
      }

      // Try each block from last to first to find the result
      for (int i = jsonBlocks.length - 1; i >= 0; i--) {
        try {
          final json = jsonDecode(jsonBlocks[i]);
          if (json is Map && json.containsKey('download') && json.containsKey('upload')) {
            return _parseJson(Map<String, dynamic>.from(json));
          }
        } catch (_) {
          continue;
        }
      }

      // If no result block found, try parsing the entire output
      final json = jsonDecode(jsonBlocks.last);
      return _parseJson(Map<String, dynamic>.from(json));
    } catch (e) {
      return OoklaSpeedtestResult(error: 'Failed to parse speedtest result: $e');
    }
  }

  OoklaSpeedtestResult _parseJson(Map<String, dynamic> json) {
    // Download and upload are in bytes/sec, convert to Mbps
    final downloadBps = (json['download']?['bandwidth'] ?? 0) as num;
    final uploadBps = (json['upload']?['bandwidth'] ?? 0) as num;

    final downloadMbps = (downloadBps * 8) / 1000000; // bytes to megabits
    final uploadMbps = (uploadBps * 8) / 1000000;

    final pingMs = (json['ping']?['latency'] ?? 0) as num;
    final jitterMs = (json['ping']?['jitter'] ?? 0) as num;
    final packetLoss = (json['packetLoss'] ?? 0) as num;

    final server = json['server'] ?? {};
    final serverName = server['name'] ?? '';
    final serverLocation = server['location'] ?? '';
    final serverHost = server['host'] ?? '';
    final serverId = server['id'] ?? 0;

    final isp = json['isp'] ?? '';
    final externalIp = json['interface']?['externalIp'] ?? '';
    final resultUrl = json['result']?['url'] ?? '';

    return OoklaSpeedtestResult(
      downloadMbps: downloadMbps.toDouble(),
      uploadMbps: uploadMbps.toDouble(),
      pingMs: pingMs.toDouble(),
      jitterMs: jitterMs.toDouble(),
      packetLoss: packetLoss.toInt(),
      serverName: serverName,
      serverLocation: serverLocation,
      serverHost: serverHost,
      serverId: serverId,
      isp: isp,
      externalIp: externalIp,
      resultUrl: resultUrl,
    );
  }
}
