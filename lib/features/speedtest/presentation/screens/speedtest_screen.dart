import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speed_test_dart/speed_test_dart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/themes/app_theme.dart';

final speedTestProvider = NotifierProvider<SpeedTestNotifier, SpeedTestState>(SpeedTestNotifier.new);

enum TestStage { idle, findingServer, ping, download, upload, complete }

class SpeedTestState {
  final TestStage stage;
  final double progress; // 0.0 to 1.0
  final double currentSpeed; // Mbps
  final double downloadSpeed; // Mbps
  final double uploadSpeed; // Mbps
  final int ping; // ms
  final String serverName;
  final String errorMessage;

  const SpeedTestState({
    this.stage = TestStage.idle,
    this.progress = 0.0,
    this.currentSpeed = 0.0,
    this.downloadSpeed = 0.0,
    this.uploadSpeed = 0.0,
    this.ping = 0,
    this.serverName = '',
    this.errorMessage = '',
  });

  SpeedTestState copyWith({
    TestStage? stage,
    double? progress,
    double? currentSpeed,
    double? downloadSpeed,
    double? uploadSpeed,
    int? ping,
    String? serverName,
    String? errorMessage,
  }) {
    return SpeedTestState(
      stage: stage ?? this.stage,
      progress: progress ?? this.progress,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      serverName: serverName ?? this.serverName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SpeedTestNotifier extends Notifier<SpeedTestState> {
  @override
  SpeedTestState build() {
    return const SpeedTestState();
  }
  
  final _tester = SpeedTestDart();

  Future<void> startTest() async {
    if (state.stage != TestStage.idle && state.stage != TestStage.complete) return;

    state = const SpeedTestState(stage: TestStage.findingServer);

    try {
      final settings = await _tester.getSettings();
      final servers = settings.servers;
      
      if (servers.isEmpty) {
        state = state.copyWith(stage: TestStage.idle, errorMessage: 'No servers found');
        return;
      }

      final bestServer = servers.first;
      state = state.copyWith(serverName: '${bestServer.host} (${bestServer.country})');

      // Ping
      state = state.copyWith(stage: TestStage.ping);
      
      // Download
      state = state.copyWith(stage: TestStage.download, currentSpeed: 0);
      try {
        final downloadSpeed = await _tester.testDownloadSpeed(servers: [bestServer]);
        state = state.copyWith(
          downloadSpeed: downloadSpeed,
          currentSpeed: downloadSpeed,
          progress: 0.5,
        );
      } catch (e) {
         // Continue to upload even if download fails?
         state = state.copyWith(errorMessage: 'Download failed: $e');
      }

      // Upload
      state = state.copyWith(stage: TestStage.upload, currentSpeed: 0);
      try {
        final uploadSpeed = await _tester.testUploadSpeed(servers: [bestServer]);
        state = state.copyWith(
          stage: TestStage.complete,
          uploadSpeed: uploadSpeed,
          currentSpeed: uploadSpeed,
          progress: 1.0,
        );
      } catch (e) {
         state = state.copyWith(errorMessage: 'Upload failed: $e');
      }

    } catch (e) {
      state = state.copyWith(stage: TestStage.idle, errorMessage: e.toString());
    }
  }

  void reset() {
    state = const SpeedTestState();
  }
}

class SpeedTestScreen extends ConsumerWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(speedTestProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speedtest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(speedTestProvider.notifier).reset(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Speedometer Area
            Expanded(
              flex: 3,
              child: Center(
                child: _Speedometer(
                  speed: state.currentSpeed,
                  stage: state.stage,
                  progress: state.progress,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Results Area
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
                     if (state.errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                        child: Text(state.errorMessage, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ResultItem(
                          label: 'DOWNLOAD',
                          value: state.downloadSpeed.toStringAsFixed(1),
                          unit: 'Mbps',
                          icon: Icons.download,
                          color: Colors.blueAccent,
                          isActive: state.stage == TestStage.download || state.stage == TestStage.complete,
                        ),
                        _ResultItem(
                          label: 'UPLOAD',
                          value: state.uploadSpeed.toStringAsFixed(1),
                          unit: 'Mbps',
                          icon: Icons.upload,
                          color: Colors.purpleAccent,
                           isActive: state.stage == TestStage.upload || state.stage == TestStage.complete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      state.serverName.isEmpty ? 'Waiting to start...' : state.serverName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: state.stage == TestStage.idle || state.stage == TestStage.complete
                            ? () => ref.read(speedTestProvider.notifier).startTest()
                            : null,
                        child: Text(state.stage == TestStage.idle || state.stage == TestStage.complete ? 'START TEST' : 'TESTING...'),
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

class _ResultItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
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
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isActive ? color : Colors.grey,
            fontFamily: GoogleFonts.inter().fontFamily,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
            fontFamily: GoogleFonts.inter().fontFamily,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey.withAlpha(200),
            fontFamily: GoogleFonts.inter().fontFamily,
          ),
        ),
      ],
    );
  }
}

class _Speedometer extends StatelessWidget {
  final double speed;
  final TestStage stage;
  final double progress;

  const _Speedometer({required this.speed, required this.stage, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = stage == TestStage.upload ? Colors.purpleAccent : Colors.blueAccent;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Circle
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.colorScheme.outline.withAlpha(30), width: 2),
          ),
        ),
        // Active Arc
        SizedBox(
            width: 250,
            height: 250,
            child: CircularProgressIndicator(
              value: stage == TestStage.download || stage == TestStage.upload ? null : 0, // Indeterminate during test
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: Colors.transparent,
            ),
        ),
        // Center Text
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Text(
              speed.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
            ),
            Text(
              'Mbps',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withAlpha(150),
                fontFamily: GoogleFonts.inter().fontFamily,
              ),
            ),
            const SizedBox(height: 8),
             if (stage != TestStage.idle && stage != TestStage.complete)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                 decoration: BoxDecoration(
                   color: color.withAlpha(30),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   stage == TestStage.findingServer ? 'Finding Server...' :
                   stage == TestStage.download ? 'Downloading...' :
                   stage == TestStage.upload ? 'Uploading...' : 'Initializing',
                   style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                 ),
               ),
          ],
        ),
      ],
    );
  }
}
