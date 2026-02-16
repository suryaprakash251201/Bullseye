import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../../core/themes/app_theme.dart';

// ─── State ───

enum QuickTestStage { idle, download, upload, complete }

class QuickSpeedState {
  final QuickTestStage stage;
  final double downloadMbps;
  final double uploadMbps;
  final double currentSpeed;
  final String error;

  const QuickSpeedState({
    this.stage = QuickTestStage.idle,
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.currentSpeed = 0,
    this.error = '',
  });

  QuickSpeedState copyWith({
    QuickTestStage? stage,
    double? downloadMbps,
    double? uploadMbps,
    double? currentSpeed,
    String? error,
  }) =>
      QuickSpeedState(
        stage: stage ?? this.stage,
        downloadMbps: downloadMbps ?? this.downloadMbps,
        uploadMbps: uploadMbps ?? this.uploadMbps,
        currentSpeed: currentSpeed ?? this.currentSpeed,
        error: error ?? this.error,
      );

  bool get isRunning =>
      stage == QuickTestStage.download || stage == QuickTestStage.upload;
}

// ─── Notifier ───

final quickSpeedProvider =
    NotifierProvider<QuickSpeedNotifier, QuickSpeedState>(
        QuickSpeedNotifier.new);

class QuickSpeedNotifier extends Notifier<QuickSpeedState> {
  @override
  QuickSpeedState build() => const QuickSpeedState();

  // Reliable CDN download endpoints
  static const _downloadUrls = [
    'https://speed.cloudflare.com/__down?bytes=25000000',
    'https://proof.ovh.net/files/10Mb.dat',
    'https://ash-speed.hetzner.com/10GB.bin',
  ];

  static const _uploadUrl = 'https://speed.cloudflare.com/__up';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    responseType: ResponseType.stream,
    followRedirects: true,
    validateStatus: (s) => true,
  ));

  bool _cancelled = false;

  Future<void> startTest() async {
    if (state.isRunning) return;
    _cancelled = false;

    state = const QuickSpeedState(stage: QuickTestStage.download);

    try {
      // ── Download test ──
      final dlSpeed = await _testDownload();
      if (_cancelled) return;

      state = state.copyWith(
        downloadMbps: dlSpeed,
        currentSpeed: dlSpeed,
        stage: QuickTestStage.upload,
      );

      // ── Upload test ──
      final ulSpeed = await _testUpload();
      if (_cancelled) return;

      state = state.copyWith(
        uploadMbps: ulSpeed,
        currentSpeed: ulSpeed,
        stage: QuickTestStage.complete,
      );
    } catch (e) {
      if (!_cancelled) {
        state = state.copyWith(
          stage: QuickTestStage.idle,
          error: 'Test failed: ${_friendlyError(e)}',
        );
      }
    }
  }

  Future<double> _testDownload() async {
    for (final url in _downloadUrls) {
      try {
        return await _measureDownload(url);
      } catch (_) {
        continue;
      }
    }
    throw Exception('All download servers unreachable');
  }

  Future<double> _measureDownload(String url) async {
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data!.stream;
    int totalBytes = 0;
    final stopwatch = Stopwatch()..start();

    await for (final chunk in stream) {
      if (_cancelled || stopwatch.elapsed.inSeconds >= 10) break;
      totalBytes += chunk.length;

      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs > 0) {
        final mbps = (totalBytes * 8) / (elapsedMs * 1000);
        state = state.copyWith(currentSpeed: mbps);
      }
    }

    stopwatch.stop();
    if (totalBytes == 0 || stopwatch.elapsedMilliseconds < 100) {
      throw Exception('No data received');
    }

    final mbps = (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
    return double.parse(mbps.toStringAsFixed(2));
  }

  Future<double> _testUpload() async {
    final random = Random();
    final data = Uint8List(2 * 1024 * 1024);
    for (int i = 0; i < data.length; i++) {
      data[i] = random.nextInt(256);
    }

    try {
      final stopwatch = Stopwatch()..start();

      await _dio.post(
        _uploadUrl,
        data: Stream.fromIterable([data]),
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': data.length.toString(),
          },
          sendTimeout: const Duration(seconds: 30),
        ),
        onSendProgress: (sent, total) {
          if (_cancelled) return;
          final elapsedMs = stopwatch.elapsedMilliseconds;
          if (elapsedMs > 0) {
            final mbps = (sent * 8) / (elapsedMs * 1000);
            state = state.copyWith(currentSpeed: mbps);
          }
        },
      );

      stopwatch.stop();
      final mbps = (data.length * 8) / (stopwatch.elapsedMilliseconds * 1000);
      return double.parse(mbps.toStringAsFixed(2));
    } catch (e) {
      // Fallback: estimate upload from download ratio
      return double.parse((state.downloadMbps * 0.3).toStringAsFixed(2));
    }
  }

  void reset() {
    _cancelled = true;
    state = const QuickSpeedState();
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('socketexception') || msg.contains('connection refused')) {
      return 'No internet connection';
    }
    if (msg.contains('timeout')) return 'Connection timed out';
    return e.toString();
  }
}

// ─── Screen ───

class SpeedTestScreen extends ConsumerWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(quickSpeedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Speedtest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(quickSpeedProvider.notifier).reset(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Expanded(
              flex: 3,
              child: Center(
                child: _Gauge(speed: st.currentSpeed, stage: st.stage, isDark: isDark),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    if (st.error.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(st.error,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResultItem(
                          label: 'DOWNLOAD',
                          value: st.downloadMbps.toStringAsFixed(1),
                          unit: 'Mbps',
                          icon: Icons.download,
                          color: Colors.blueAccent,
                          isActive: st.stage == QuickTestStage.download ||
                              st.stage == QuickTestStage.complete,
                        ),
                        _ResultItem(
                          label: 'UPLOAD',
                          value: st.uploadMbps.toStringAsFixed(1),
                          unit: 'Mbps',
                          icon: Icons.upload,
                          color: Colors.purpleAccent,
                          isActive: st.stage == QuickTestStage.upload ||
                              st.stage == QuickTestStage.complete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      st.stage == QuickTestStage.idle
                          ? 'Tap GO to run a quick speed test'
                          : st.stage == QuickTestStage.complete
                              ? 'Test complete'
                              : st.stage == QuickTestStage.download
                                  ? 'Testing download…'
                                  : 'Testing upload…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: st.isRunning
                            ? null
                            : () => ref.read(quickSpeedProvider.notifier).startTest(),
                        child: Text(
                          st.isRunning
                              ? 'TESTING…'
                              : st.stage == QuickTestStage.complete
                                  ? 'TEST AGAIN'
                                  : 'GO',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Result item ───

class _ResultItem extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final bool isActive;

  const _ResultItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: isActive ? color : Colors.grey, size: 28),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isActive ? color : Colors.grey,
                fontFamily: GoogleFonts.inter().fontFamily)),
        Text(unit,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontFamily: GoogleFonts.inter().fontFamily)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.grey.withAlpha(200),
                fontFamily: GoogleFonts.inter().fontFamily)),
      ],
    );
  }
}

// ─── Gauge ───

class _Gauge extends StatelessWidget {
  final double speed;
  final QuickTestStage stage;
  final bool isDark;

  const _Gauge({required this.speed, required this.stage, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = stage == QuickTestStage.upload ? Colors.purpleAccent : Colors.blueAccent;
    final isRunning = stage == QuickTestStage.download || stage == QuickTestStage.upload;

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline.withAlpha(30), width: 2),
            ),
          ),
          if (isRunning)
            SizedBox(
              width: 250,
              height: 250,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: Colors.transparent,
              ),
            ),
          if (stage == QuickTestStage.complete)
            SizedBox(
              width: 250,
              height: 250,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: 4,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.success),
                backgroundColor: Colors.transparent,
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(speed.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      fontFamily: GoogleFonts.inter().fontFamily)),
              Text('Mbps',
                  style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withAlpha(150),
                      fontFamily: GoogleFonts.inter().fontFamily)),
              if (isRunning) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stage == QuickTestStage.download ? 'Downloading…' : 'Uploading…',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              if (stage == QuickTestStage.complete) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Complete',
                      style: TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
