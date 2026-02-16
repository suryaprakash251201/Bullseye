import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/ookla_speedtest_service.dart';
import '../../../../core/themes/app_theme.dart';

final _ooklaTestProvider = NotifierProvider<OoklaTestNotifier, OoklaTestState>(OoklaTestNotifier.new);

class OoklaTestState {
  final SpeedtestStage stage;
  final double downloadSpeed;
  final double uploadSpeed;
  final double ping;
  final double jitter;
  final String serverName;
  final String serverLocation;
  final String isp;
  final String externalIp;
  final String resultUrl;
  final String errorMessage;
  final String progressMessage;

  const OoklaTestState({
    this.stage = SpeedtestStage.idle,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.ping = 0,
    this.jitter = 0,
    this.serverName = '',
    this.serverLocation = '',
    this.isp = '',
    this.externalIp = '',
    this.resultUrl = '',
    this.errorMessage = '',
    this.progressMessage = '',
  });

  OoklaTestState copyWith({
    SpeedtestStage? stage,
    double? downloadSpeed,
    double? uploadSpeed,
    double? ping,
    double? jitter,
    String? serverName,
    String? serverLocation,
    String? isp,
    String? externalIp,
    String? resultUrl,
    String? errorMessage,
    String? progressMessage,
  }) {
    return OoklaTestState(
      stage: stage ?? this.stage,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      jitter: jitter ?? this.jitter,
      serverName: serverName ?? this.serverName,
      serverLocation: serverLocation ?? this.serverLocation,
      isp: isp ?? this.isp,
      externalIp: externalIp ?? this.externalIp,
      resultUrl: resultUrl ?? this.resultUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      progressMessage: progressMessage ?? this.progressMessage,
    );
  }

  bool get isRunning =>
      stage != SpeedtestStage.idle &&
      stage != SpeedtestStage.complete &&
      stage != SpeedtestStage.error;
}

class OoklaTestNotifier extends Notifier<OoklaTestState> {
  @override
  OoklaTestState build() => const OoklaTestState();

  Future<void> startTest() async {
    if (state.isRunning) return;

    state = const OoklaTestState(
      stage: SpeedtestStage.checkingCli,
      progressMessage: 'Initializing Ookla Speedtest...',
    );

    final service = ref.read(ooklaSpeedtestServiceProvider);

    state = state.copyWith(
      stage: SpeedtestStage.selectingServer,
      progressMessage: 'Selecting best server...',
    );

    final result = await service.runTest(
      onProgress: (stage, message, progress) {
        state = state.copyWith(
          stage: stage,
          progressMessage: message,
        );
      },
    );

    if (result.hasError) {
      state = state.copyWith(
        stage: SpeedtestStage.error,
        errorMessage: result.error!,
      );
      return;
    }

    state = OoklaTestState(
      stage: SpeedtestStage.complete,
      downloadSpeed: result.downloadMbps,
      uploadSpeed: result.uploadMbps,
      ping: result.pingMs,
      jitter: result.jitterMs,
      serverName: result.serverName,
      serverLocation: result.serverLocation,
      isp: result.isp,
      externalIp: result.externalIp,
      resultUrl: result.resultUrl,
    );
  }

  void reset() {
    state = const OoklaTestState();
  }
}

class OoklaSpeedtestScreen extends ConsumerWidget {
  const OoklaSpeedtestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_ooklaTestProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E21) : Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Speedtest'),
          ],
        ),
        actions: [
          if (state.stage == SpeedtestStage.complete)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: () => ref.read(_ooklaTestProvider.notifier).reset(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Speedometer
            Expanded(
              flex: 3,
              child: Center(
                child: _OoklaSpeedometer(
                  downloadSpeed: state.downloadSpeed,
                  uploadSpeed: state.uploadSpeed,
                  stage: state.stage,
                  isDark: isDark,
                ),
              ),
            ),

            // Progress message
            if (state.isRunning)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  state.progressMessage,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Results panel
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF111730) : Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Error
                      if (state.errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withAlpha(15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.error.withAlpha(40)),
                          ),
                          child: Text(
                            state.errorMessage,
                            style: TextStyle(color: AppTheme.error, fontSize: 13),
                          ),
                        ),

                      // Speed results
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SpeedResultCard(
                            icon: Icons.download_rounded,
                            label: 'DOWNLOAD',
                            value: state.downloadSpeed.toStringAsFixed(2),
                            unit: 'Mbps',
                            color: const Color(0xFF00B4D8),
                            isActive: state.stage == SpeedtestStage.testingDownload || state.stage == SpeedtestStage.complete,
                            isDark: isDark,
                          ),
                          _SpeedResultCard(
                            icon: Icons.upload_rounded,
                            label: 'UPLOAD',
                            value: state.uploadSpeed.toStringAsFixed(2),
                            unit: 'Mbps',
                            color: const Color(0xFF8338EC),
                            isActive: state.stage == SpeedtestStage.testingUpload || state.stage == SpeedtestStage.complete,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Ping & Jitter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MiniStat(
                            icon: Icons.sync_alt,
                            label: 'Ping',
                            value: '${state.ping.toStringAsFixed(1)} ms',
                            isDark: isDark,
                            isActive: state.stage == SpeedtestStage.complete || state.stage == SpeedtestStage.testingLatency,
                          ),
                          _MiniStat(
                            icon: Icons.swap_vert,
                            label: 'Jitter',
                            value: '${state.jitter.toStringAsFixed(1)} ms',
                            isDark: isDark,
                            isActive: state.stage == SpeedtestStage.complete,
                          ),
                        ],
                      ),

                      // Server info
                      if (state.serverName.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1F3D) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _InfoRow(label: 'Server', value: state.serverName, isDark: isDark),
                              if (state.serverLocation.isNotEmpty)
                                _InfoRow(label: 'Location', value: state.serverLocation, isDark: isDark),
                              if (state.isp.isNotEmpty)
                                _InfoRow(label: 'ISP', value: state.isp, isDark: isDark),
                              if (state.externalIp.isNotEmpty)
                                _InfoRow(label: 'External IP', value: state.externalIp, isDark: isDark),
                            ],
                          ),
                        ),
                      ],

                      // Result URL
                      if (state.resultUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => launchUrl(Uri.parse(state.resultUrl)),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('View result on Speedtest.net'),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Start button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: state.isRunning
                              ? null
                              : () => ref.read(_ooklaTestProvider.notifier).startTest(),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: const Color(0xFF00B4D8),
                          ),
                          child: Text(
                            state.isRunning
                                ? 'TESTING...'
                                : state.stage == SpeedtestStage.complete
                                    ? 'TEST AGAIN'
                                    : state.stage == SpeedtestStage.error
                                        ? 'RETRY'
                                        : 'GO',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        'Powered by Ookla Speedtest CLI',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white24 : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedResultCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isActive;
  final bool isDark;

  const _SpeedResultCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive ? color : Colors.grey;

    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F3D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isActive ? color.withAlpha(60) : Colors.transparent),
        boxShadow: isActive
            ? [BoxShadow(color: color.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4))]
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: effectiveColor, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: effectiveColor,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool isActive;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: isActive ? Colors.tealAccent : Colors.grey),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isActive ? (isDark ? Colors.white : Colors.black87) : Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OoklaSpeedometer extends StatelessWidget {
  final double downloadSpeed;
  final double uploadSpeed;
  final SpeedtestStage stage;
  final bool isDark;

  const _OoklaSpeedometer({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.stage,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isDownload = stage == SpeedtestStage.testingDownload;
    final isUpload = stage == SpeedtestStage.testingUpload;
    final isComplete = stage == SpeedtestStage.complete;
    final isRunning = stage != SpeedtestStage.idle && stage != SpeedtestStage.complete && stage != SpeedtestStage.error;

    final currentSpeed = isUpload || isComplete ? uploadSpeed : downloadSpeed;
    final color = isUpload ? const Color(0xFF8338EC) : const Color(0xFF00B4D8);

    final displaySpeed = isComplete ? downloadSpeed : currentSpeed;

    return SizedBox(
      width: 260,
      height: 260,
      child: CustomPaint(
        painter: _SpeedometerPainter(
          speed: displaySpeed,
          maxSpeed: _calculateMaxSpeed(displaySpeed),
          color: color,
          isDark: isDark,
          isAnimating: isRunning,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displaySpeed.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Mbps',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
              if (isRunning)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isDownload ? 'Downloading' : isUpload ? 'Uploading' : 'Preparing',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              if (isComplete)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Complete',
                    style: TextStyle(fontSize: 12, color: AppTheme.success, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateMaxSpeed(double speed) {
    if (speed <= 10) return 10;
    if (speed <= 50) return 50;
    if (speed <= 100) return 100;
    if (speed <= 250) return 250;
    if (speed <= 500) return 500;
    if (speed <= 1000) return 1000;
    return 2000;
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color color;
  final bool isDark;
  final bool isAnimating;

  _SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.color,
    required this.isDark,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background arc
    final bgPaint = Paint()
      ..color = (isDark ? Colors.white12 : Colors.grey[200]!)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const startAngle = 2.4; // ~137 degrees
    const sweepAngle = 4.3; // ~246 degrees

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    if (speed > 0) {
      final progress = (speed / maxSpeed).clamp(0.0, 1.0);
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [color.withAlpha(100), color],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );

      // Glow at the end point
      final endAngle = startAngle + sweepAngle * progress;
      final endX = center.dx + radius * cos(endAngle);
      final endY = center.dy + radius * sin(endAngle);

      final glowPaint = Paint()
        ..color = color.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(Offset(endX, endY), 6, glowPaint);
      canvas.drawCircle(Offset(endX, endY), 4, Paint()..color = color);
    }

    // Scale marks
    final markPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.grey[300]!
      ..strokeWidth = 1;

    for (int i = 0; i <= 10; i++) {
      final angle = startAngle + (sweepAngle * i / 10);
      final outerX = center.dx + (radius + 8) * cos(angle);
      final outerY = center.dy + (radius + 8) * sin(angle);
      final innerX = center.dx + (radius - (i % 5 == 0 ? 12 : 6)) * cos(angle);
      final innerY = center.dy + (radius - (i % 5 == 0 ? 12 : 6)) * sin(angle);

      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), markPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedometerPainter oldDelegate) {
    return speed != oldDelegate.speed ||
        color != oldDelegate.color ||
        isAnimating != oldDelegate.isAnimating;
  }
}
