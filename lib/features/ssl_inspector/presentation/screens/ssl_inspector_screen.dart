import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/formatters.dart';

class SSLInspectorScreen extends ConsumerStatefulWidget {
  const SSLInspectorScreen({super.key});

  @override
  ConsumerState<SSLInspectorScreen> createState() => _SSLInspectorScreenState();
}

class _SSLInspectorScreenState extends ConsumerState<SSLInspectorScreen> {
  final _hostController = TextEditingController();
  bool _isLoading = false;
  _SSLCertInfo? _certInfo;
  String? _error;

  Future<void> _inspect() async {
    final host = _hostController.text.trim().replaceAll('https://', '').replaceAll('http://', '').split('/').first;
    if (host.isEmpty) return;

    setState(() { _isLoading = true; _certInfo = null; _error = null; });

    try {
      final socket = await SecureSocket.connect(host, 443, timeout: const Duration(seconds: 10), onBadCertificate: (cert) => true);
      final cert = socket.peerCertificate;
      if (cert != null) {
        final now = DateTime.now();
        final daysLeft = cert.endValidity.difference(now).inDays;
        final hoursLeft = cert.endValidity.difference(now).inHours % 24;
        setState(() {
          _certInfo = _SSLCertInfo(
            subject: cert.subject.toString(),
            issuer: cert.issuer.toString(),
            validFrom: cert.startValidity,
            validTo: cert.endValidity,
            isValid: daysLeft > 0,
            daysUntilExpiry: daysLeft,
            hoursUntilExpiry: hoursLeft,
            sha1: cert.sha1.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':'),
          );
        });
      }
      socket.destroy();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyCertDetails() {
    if (_certInfo == null) return;
    final buffer = StringBuffer();
    buffer.writeln('SSL Certificate: ${_hostController.text}');
    buffer.writeln('─' * 40);
    buffer.writeln('Status: ${_certInfo!.isValid ? "Valid" : "Expired"}');
    buffer.writeln('Subject: ${_certInfo!.subject}');
    buffer.writeln('Issuer: ${_certInfo!.issuer}');
    buffer.writeln('Valid From: ${Formatters.formatDateTime(_certInfo!.validFrom)}');
    buffer.writeln('Valid To: ${Formatters.formatDateTime(_certInfo!.validTo)}');
    buffer.writeln('Days Until Expiry: ${_certInfo!.daysUntilExpiry}');
    buffer.writeln('SHA-1: ${_certInfo!.sha1}');
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [const Icon(Icons.check_circle, color: AppTheme.success, size: 18), const SizedBox(width: 8), const Text('Certificate details copied')]),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() { _hostController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('SSL Inspector', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          if (_certInfo != null)
            IconButton(icon: const Icon(Icons.copy_all, size: 22), tooltip: 'Copy certificate details', onPressed: _copyCertDetails),
        ],
      ),
      body: _AnimatedSSLBody(
        hostController: _hostController,
        isLoading: _isLoading,
        certInfo: _certInfo,
        error: _error,
        isDark: isDark,
        onInspect: _inspect,
      ),
    );
  }
}

class _AnimatedSSLBody extends StatefulWidget {
  final TextEditingController hostController;
  final bool isLoading;
  final _SSLCertInfo? certInfo;
  final String? error;
  final bool isDark;
  final VoidCallback onInspect;

  const _AnimatedSSLBody({required this.hostController, required this.isLoading, this.certInfo, this.error, required this.isDark, required this.onInspect});

  @override
  State<_AnimatedSSLBody> createState() => _AnimatedSSLBodyState();
}

class _AnimatedSSLBodyState extends State<_AnimatedSSLBody> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void didUpdateWidget(covariant _AnimatedSSLBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.certInfo != null && oldWidget.certInfo == null) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Widget _stagger(double delay, Widget child) {
    final begin = delay;
    final end = (delay + 0.3).clamp(0.0, 1.0);
    final curved = CurvedAnimation(parent: _controller, curve: Interval(begin, end, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cert = widget.certInfo;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: widget.isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: widget.isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
                ),
                child: TextField(
                  controller: widget.hostController,
                  decoration: InputDecoration(
                    labelText: 'Domain',
                    hintText: 'example.com',
                    prefixIcon: const Icon(Icons.security),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  onSubmitted: (_) => widget.onInspect(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: widget.isLoading ? null : widget.onInspect,
              child: widget.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Inspect'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (widget.error != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.error.withAlpha(20), AppTheme.error.withAlpha(8)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.error.withAlpha(30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
              ],
            ),
          ),

        if (cert != null) ...[
          // ── Status Banner ──
          _stagger(0.0, _StatusBanner(cert: cert, isDark: widget.isDark)),
          const SizedBox(height: 16),

          // ── Expiry Countdown ──
          _stagger(0.15, _ExpiryCountdown(cert: cert, isDark: widget.isDark)),
          const SizedBox(height: 16),

          // ── Certificate Details ──
          _stagger(0.3, _CertDetailsCard(cert: cert, isDark: widget.isDark)),

          // ── Warning ──
          if (cert.daysUntilExpiry <= 30 && cert.daysUntilExpiry > 0) ...[
            const SizedBox(height: 12),
            _stagger(0.5, Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppTheme.warning.withAlpha(20), AppTheme.warning.withAlpha(8)]),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.warning.withAlpha(30)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.warning.withAlpha(40), AppTheme.warning.withAlpha(15)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expiring Soon', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.warning)),
                        Text('Certificate expires in ${cert.daysUntilExpiry} days', style: GoogleFonts.inter(fontSize: 12, color: widget.isDark ? Colors.white54 : const Color(0xFF718096))),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],

        if (!widget.isLoading && cert == null && widget.error == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.security, size: 48, color: theme.colorScheme.onSurface.withAlpha(50)),
                  const SizedBox(height: 12),
                  Text('Enter a domain to inspect its SSL certificate', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Status Banner ──
class _StatusBanner extends StatelessWidget {
  final _SSLCertInfo cert;
  final bool isDark;
  const _StatusBanner({required this.cert, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final statusColor = cert.isValid ? AppTheme.success : AppTheme.error;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [statusColor.withAlpha(isDark ? 30 : 18), statusColor.withAlpha(isDark ? 10 : 5)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withAlpha(40)),
        boxShadow: [BoxShadow(color: statusColor.withAlpha(15), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [statusColor.withAlpha(50), statusColor.withAlpha(20)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(cert.isValid ? Icons.verified : Icons.warning, color: statusColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cert.isValid ? 'Certificate Valid' : 'Certificate Expired',
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1A202C)),
                ),
                const SizedBox(height: 2),
                Text(
                  cert.daysUntilExpiry > 0 ? '${cert.daysUntilExpiry} days remaining' : 'Expired ${-cert.daysUntilExpiry} days ago',
                  style: GoogleFonts.inter(fontSize: 13, color: cert.daysUntilExpiry > 30 ? AppTheme.success : AppTheme.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expiry Countdown ──
class _ExpiryCountdown extends StatelessWidget {
  final _SSLCertInfo cert;
  final bool isDark;
  const _ExpiryCountdown({required this.cert, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final days = cert.daysUntilExpiry;
    final hours = cert.hoursUntilExpiry;

    Color countColor;
    if (days > 60) {
      countColor = AppTheme.success;
    } else if (days > 14) {
      countColor = AppTheme.warning;
    } else {
      countColor = AppTheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _CountdownItem(value: '${days.abs()}', label: days >= 0 ? 'DAYS LEFT' : 'DAYS AGO', color: countColor),
          Container(width: 1, height: 30, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          _CountdownItem(value: '${hours.abs()}', label: 'HOURS', color: countColor),
          Container(width: 1, height: 30, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          _CountdownItem(value: cert.isValid ? '✓' : '✕', label: 'STATUS', color: cert.isValid ? AppTheme.success : AppTheme.error),
        ],
      ),
    );
  }
}

class _CountdownItem extends StatelessWidget {
  final String value; final String label; final Color color;
  const _CountdownItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : const Color(0xFF718096), letterSpacing: 1.0)),
      ],
    );
  }
}

// ── Certificate Details Card ──
class _CertDetailsCard extends StatelessWidget {
  final _SSLCertInfo cert;
  final bool isDark;
  const _CertDetailsCard({required this.cert, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.cardGradientDark : AppTheme.cardGradientLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? AppTheme.cardShadowDark : AppTheme.cardShadowLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3, height: 16,
                decoration: BoxDecoration(gradient: AppTheme.accentGradient, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text('Certificate Details', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1A202C))),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          _CertRow(label: 'Subject', value: cert.subject, isDark: isDark),
          _CertRow(label: 'Issuer', value: cert.issuer, isDark: isDark),
          _CertRow(label: 'Valid From', value: Formatters.formatDateTime(cert.validFrom), isDark: isDark),
          _CertRow(label: 'Valid To', value: Formatters.formatDateTime(cert.validTo), isDark: isDark),
          _CertRow(label: 'SHA-1 Fingerprint', value: cert.sha1, isDark: isDark),
        ],
      ),
    );
  }
}

class _CertRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _CertRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : const Color(0xFF718096), letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1A202C))),
        ],
      ),
    );
  }
}

class _SSLCertInfo {
  final String subject;
  final String issuer;
  final DateTime validFrom;
  final DateTime validTo;
  final bool isValid;
  final int daysUntilExpiry;
  final int hoursUntilExpiry;
  final String sha1;

  _SSLCertInfo({
    required this.subject,
    required this.issuer,
    required this.validFrom,
    required this.validTo,
    required this.isValid,
    required this.daysUntilExpiry,
    required this.hoursUntilExpiry,
    required this.sha1,
  });
}
