import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../website_monitor/presentation/providers/monitor_provider.dart';
import '../../../../shared/models/website_monitor.dart';
import '../../../../config/main_shell.dart';
import '../../../website_monitor/presentation/providers/monitor_filter_provider.dart';
import '../providers/alerts_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final monitors = ref.watch(monitorsProvider);
    final connectivity = ref.watch(connectivityProvider);
    final alerts = ref.watch(alertsProvider);
    final up = monitors.where((m) => m.currentStatus == MonitorStatus.up).length;
    final down = monitors.where((m) => m.currentStatus == MonitorStatus.down).length;

    return Scaffold(
      body: SafeArea(
        child: _AnimatedDashboard(
          isDark: isDark,
          connectivity: connectivity,
          monitors: monitors,
          alerts: alerts,
          up: up,
          down: down,
          ref: ref,
        ),
      ),
    );
  }
}

class _AnimatedDashboard extends StatefulWidget {
  final bool isDark;
  final ConnectivityState connectivity;
  final List monitors;
  final List<MonitorAlert> alerts;
  final int up;
  final int down;
  final WidgetRef ref;

  const _AnimatedDashboard({
    required this.isDark,
    required this.connectivity,
    required this.monitors,
    required this.alerts,
    required this.up,
    required this.down,
    required this.ref,
  });

  @override
  State<_AnimatedDashboard> createState() => _AnimatedDashboardState();
}

class _AnimatedDashboardState extends State<_AnimatedDashboard> with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _stagger(double delay, Widget child) {
    final begin = delay;
    final end = (delay + 0.3).clamp(0.0, 1.0);
    final curved = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  IconData _alertIcon(AlertType type) {
    switch (type) {
      case AlertType.monitorDown: return Icons.error_outline;
      case AlertType.highLatency: return Icons.speed;
      case AlertType.lowUptime: return Icons.trending_down;
      case AlertType.unchecked: return Icons.help_outline;
    }
  }

  Color _alertColor(AlertType type) {
    switch (type) {
      case AlertType.monitorDown: return AppTheme.error;
      case AlertType.highLatency: return AppTheme.warning;
      case AlertType.lowUptime: return Colors.orange;
      case AlertType.unchecked: return AppTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 16),
        _stagger(0.0, _buildHeader(context, widget.isDark, widget.connectivity)),
        const SizedBox(height: 14),
        _stagger(0.08, _NetworkStatusBanner(connectivity: widget.connectivity, isDark: widget.isDark)),
        const SizedBox(height: 20),
        _stagger(0.16, _SystemStatusCard(isDark: widget.isDark, upCount: widget.up, totalCount: widget.monitors.length)),
        const SizedBox(height: 20),
        _stagger(0.24, _SectionHeader(title: 'Monitor Overview', isDark: widget.isDark)),
        const SizedBox(height: 12),
        _stagger(0.3, _MonitorStatsRow(
          total: widget.monitors.length,
          up: widget.up,
          down: widget.down,
          isDark: widget.isDark,
          onTotalTap: () {
            widget.ref.read(monitorFilterProvider.notifier).set(MonitorFilter.all);
            widget.ref.read(currentTabProvider.notifier).set(2);
          },
          onUpTap: () {
            widget.ref.read(monitorFilterProvider.notifier).set(MonitorFilter.up);
            widget.ref.read(currentTabProvider.notifier).set(2);
          },
          onDownTap: () {
            widget.ref.read(monitorFilterProvider.notifier).set(MonitorFilter.down);
            widget.ref.read(currentTabProvider.notifier).set(2);
          },
        )),
        const SizedBox(height: 20),
        _stagger(0.38, _SectionHeader(title: 'Quick Actions', isDark: widget.isDark)),
        const SizedBox(height: 12),
        _stagger(0.44, _QuickActionsRow(isDark: widget.isDark, onMonitorTap: () {
          widget.ref.read(currentTabProvider.notifier).set(2);
        })),
        const SizedBox(height: 20),
        _stagger(0.52, _SectionHeader(title: 'Alerts', isDark: widget.isDark)),
        const SizedBox(height: 12),
        if (widget.alerts.isEmpty)
          _stagger(0.58, Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.success.withAlpha(widget.isDark ? 20 : 12), AppTheme.success.withAlpha(widget.isDark ? 8 : 4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.success.withAlpha(30)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.success.withAlpha(40), AppTheme.success.withAlpha(15)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('All Clear', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: widget.isDark ? Colors.white : const Color(0xFF1A202C))),
                      Text('No active alerts', style: GoogleFonts.inter(fontSize: 12, color: widget.isDark ? Colors.white54 : const Color(0xFF718096))),
                    ],
                  ),
                ),
              ],
            ),
          )),
        for (int i = 0; i < widget.alerts.length; i++) ...[
          _stagger((0.58 + i * 0.04).clamp(0.0, 0.9), _AlertCard(
            icon: _alertIcon(widget.alerts[i].type),
            title: widget.alerts[i].title,
            subtitle: widget.alerts[i].subtitle,
            color: _alertColor(widget.alerts[i].type),
            isDark: widget.isDark,
          )),
          if (i < widget.alerts.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
        _stagger(0.68, _SectionHeader(title: 'Monitors', isDark: widget.isDark)),
        const SizedBox(height: 12),
        _stagger(0.74, _MonitorsCard(monitors: widget.monitors, isDark: widget.isDark, onViewAll: () {
          widget.ref.read(currentTabProvider.notifier).set(2);
        })),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, ConnectivityState connectivity) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? AppTheme.glowShadow(AppTheme.primaryDark) : AppTheme.cardShadowLight,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Generated Premium Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/dashboard_header_bg.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: isDark ? AppTheme.heroGradientDark : AppTheme.heroGradientLight,
                    ),
                  );
                },
              ),
            ),
            // Glassmorphism overlay gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.darkBg.withAlpha(isDark ? 200 : 100),
                      AppTheme.darkBg.withAlpha(isDark ? 240 : 180),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Header Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => AppTheme.accentGradient.createShader(bounds),
                          child: Text(
                            'Bullseye',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'System overview & quick actions',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // Navigate to Monitors tab (index 2)
                      widget.ref.read(currentTabProvider.notifier).set(2);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(isDark ? 10 : 30),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withAlpha(20),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- System Status Card ---
class _SystemStatusCard extends StatelessWidget {
  final bool isDark;
  final int upCount;
  final int totalCount;

  const _SystemStatusCard({required this.isDark, required this.upCount, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    final allUp = totalCount > 0 && upCount == totalCount;
    final statusColor = allUp ? AppTheme.cyan : AppTheme.warning;
    final statusText = allUp ? 'All Systems Operational' : '$upCount / $totalCount Services Up';
    final subtitle = allUp ? 'All monitors reporting healthy' : 'Some services need attention';

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withAlpha(isDark ? 35 : 20),
                statusColor.withAlpha(isDark ? 12 : 5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withAlpha(40), width: 1.5),
            boxShadow: [
              BoxShadow(color: statusColor.withAlpha(15), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor.withAlpha(60), statusColor.withAlpha(20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: statusColor.withAlpha(50)),
                ),
                child: Icon(
                  allUp ? Icons.check_circle : Icons.warning_rounded,
                  color: statusColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A202C),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Section Header ---
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A202C),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// --- Monitor Stats Row ---
class _MonitorStatsRow extends StatelessWidget {
  final int total;
  final int up;
  final int down;
  final bool isDark;
  final VoidCallback onTotalTap;
  final VoidCallback onUpTap;
  final VoidCallback onDownTap;

  const _MonitorStatsRow({required this.total, required this.up, required this.down, required this.isDark, required this.onTotalTap, required this.onUpTap, required this.onDownTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'TOTAL', value: '$total', icon: Icons.monitor_heart_outlined, color: AppTheme.cyan, isDark: isDark, onTap: onTotalTap)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'UP', value: '$up', icon: Icons.arrow_circle_up_outlined, color: AppTheme.success, isDark: isDark, onTap: onUpTap)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'DOWN', value: '$down', icon: Icons.arrow_circle_down_outlined, color: AppTheme.error, isDark: isDark, onTap: onDownTap)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard.withAlpha(200) : AppTheme.lightCard.withAlpha(220),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFE2E8F0)),
              boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withAlpha(isDark ? 20 : 15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withAlpha(30)),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A202C),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : const Color(0xFF718096),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Quick Actions Row ---
class _QuickActionsRow extends StatelessWidget {
  final bool isDark;
  final VoidCallback onMonitorTap;

  const _QuickActionsRow({required this.isDark, required this.onMonitorTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickAction(icon: Icons.terminal, label: 'SSH', color: AppTheme.cyan, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ssh')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.folder_copy, label: 'SFTP', color: Colors.purple, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ftp')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.monitor_heart, label: 'Monitors', color: AppTheme.success, isDark: isDark, onTap: onMonitorTap),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.cell_tower, label: 'Ping', color: Colors.blue, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ping')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.dns, label: 'DNS', color: Colors.teal, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/dns')),
          const SizedBox(width: 10),
          _QuickAction(icon: Icons.security, label: 'SSL', color: Colors.red, isDark: isDark, onTap: () => Navigator.pushNamed(context, '/ssl')),
        ],
      ),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.isDark, required this.onTap});

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.animateTo(0.92),
      onTapUp: (_) {
        _controller.animateTo(1.0);
        widget.onTap();
      },
      onTapCancel: () => _controller.animateTo(1.0),
      child: ScaleTransition(
        scale: _controller,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 80,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: widget.isDark ? AppTheme.darkCard.withAlpha(200) : AppTheme.lightCard.withAlpha(220),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.isDark ? Colors.white.withAlpha(10) : const Color(0xFFE2E8F0)),
                boxShadow: widget.isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(widget.isDark ? 20 : 15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: widget.color.withAlpha(30)),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.label,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.white70 : const Color(0xFF4A5568),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Alert Card ---
class _AlertCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _AlertCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard.withAlpha(200) : AppTheme.lightCard.withAlpha(220),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(40), width: 1.5),
            boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withAlpha(40), color.withAlpha(15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withAlpha(30)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A202C),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.chevron_right, color: isDark ? Colors.white38 : const Color(0xFFA0AEC0), size: 18),
          ),
        ],
      ),
    ),
   ),
  );
 }
}

// --- Monitors Card ---
class _MonitorsCard extends StatelessWidget {
  final List monitors;
  final bool isDark;
  final VoidCallback onViewAll;

  const _MonitorsCard({required this.monitors, required this.isDark, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final topMonitors = monitors.take(3).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard.withAlpha(200) : AppTheme.lightCard.withAlpha(220),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFE2E8F0)),
            boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
          ),
      child: Column(
        children: [
          if (topMonitors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.monitor_heart_outlined, size: 40, color: isDark ? Colors.white24 : const Color(0xFFA0AEC0)),
                  const SizedBox(height: 8),
                  Text(
                    'No monitors yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : const Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
          for (int i = 0; i < topMonitors.length; i++) ...[
            _MonitorTile(monitor: topMonitors[i], isDark: isDark),
            if (i < topMonitors.length - 1)
              Divider(color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFE2E8F0), height: 20),
          ],
          if (monitors.length > 3) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onViewAll,
              child: Text(
                'View all ${monitors.length} monitors',
                style: GoogleFonts.outfit(color: AppTheme.cyan, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    ),
  ),
);
  }
}

class _MonitorTile extends StatelessWidget {
  final dynamic monitor;
  final bool isDark;

  const _MonitorTile({required this.monitor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUp = monitor.currentStatus == MonitorStatus.up;
    final dotColor = isUp ? AppTheme.success : AppTheme.error;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: dotColor.withAlpha(120), blurRadius: 8, spreadRadius: 1.5),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                monitor.name,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                monitor.url,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF718096),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: dotColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: dotColor.withAlpha(10), blurRadius: 4),
            ],
          ),
          child: Text(
            isUp ? 'UP' : 'DOWN',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: dotColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

// --- Network Status Banner ---
class _NetworkStatusBanner extends StatelessWidget {
  final ConnectivityState connectivity;
  final bool isDark;
  const _NetworkStatusBanner({required this.connectivity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    final Color color;

    switch (connectivity.type) {
      case ConnectionType.wifi:
        icon = Icons.wifi;
        label = 'WiFi Connected';
        color = AppTheme.success;
      case ConnectionType.ethernet:
        icon = Icons.cable;
        label = 'Ethernet Connected';
        color = AppTheme.cyan;
      case ConnectionType.mobile:
        icon = Icons.cell_tower;
        label = 'Mobile Data';
        color = Colors.orange;
      case ConnectionType.vpn:
        icon = Icons.vpn_lock;
        label = 'VPN Connected';
        color = Colors.purple;
      case ConnectionType.none:
        icon = Icons.wifi_off;
        label = 'No Internet';
        color = AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(isDark ? 25 : 18), color.withAlpha(isDark ? 8 : 5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(35)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha(50), color.withAlpha(25)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A202C),
                  ),
                ),
                Text(
                  connectivity.isConnected ? 'Network active' : 'Check your connection',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
          // Pulsing status dot
          _PulsingDot(color: connectivity.isConnected ? AppTheme.success : AppTheme.error),
        ],
      ),
    );
  }
}

// -- Pulsing Status Dot --
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha((_animation.value * 130).toInt()),
              blurRadius: 6 + (_animation.value * 4),
              spreadRadius: _animation.value * 2,
            ),
          ],
        ),
      ),
    );
  }
}
