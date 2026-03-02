import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/providers/security_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String _error = '';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometric();
    });
  }

  Future<void> _tryBiometric() async {
    final security = ref.read(securityProvider);
    if (!security.isBiometricEnabled) return;

    setState(() => _isAuthenticating = true);
    try {
      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();

      if (canCheck || isSupported) {
        final didAuthenticate = await localAuth.authenticate(
          localizedReason: 'Unlock Bullseye',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );
        if (didAuthenticate && mounted) {
          ref.read(securityProvider.notifier).unlock();
        }
      }
    } catch (_) {
      // Biometric auth not available — user can still use PIN
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _onDigit(String digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = '';
    });
    if (_pin.length == 6) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _verifyPin() async {
    final result = await ref.read(securityProvider.notifier).verifyPin(_pin);
    if (!result && mounted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _error = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final security = ref.watch(securityProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Lock icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withAlpha(isDark ? 38 : 25),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.lock_outline, color: AppTheme.cyan, size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bullseye Locked',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your 6-digit PIN to unlock',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : const Color(0xFF718096),
                  ),
                ),
                const SizedBox(height: 32),

                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    final isFilled = i < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? AppTheme.cyan
                            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFilled
                              ? AppTheme.cyan
                              : (isDark ? Colors.white24 : const Color(0xFFCBD5E0)),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),

                // Error text
                SizedBox(
                  height: 20,
                  child: _error.isNotEmpty
                      ? Text(
                          _error,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 24),

                // Numpad
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      for (int row = 0; row < 4; row++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (row < 3) ...[
                                _NumpadKey(digit: '${row * 3 + 1}', onTap: () => _onDigit('${row * 3 + 1}'), isDark: isDark),
                                _NumpadKey(digit: '${row * 3 + 2}', onTap: () => _onDigit('${row * 3 + 2}'), isDark: isDark),
                                _NumpadKey(digit: '${row * 3 + 3}', onTap: () => _onDigit('${row * 3 + 3}'), isDark: isDark),
                              ] else ...[
                                // Biometric button
                                security.isBiometricEnabled && !_isAuthenticating
                                    ? _NumpadKey(
                                        icon: Icons.fingerprint,
                                        onTap: _tryBiometric,
                                        isDark: isDark,
                                      )
                                    : const SizedBox(width: 72),
                                _NumpadKey(digit: '0', onTap: () => _onDigit('0'), isDark: isDark),
                                _NumpadKey(icon: Icons.backspace_outlined, onTap: _onDelete, isDark: isDark),
                              ],
                            ],
                          ),
                        ),
                    ],
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

class _NumpadKey extends StatelessWidget {
  final String? digit;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isDark;

  const _NumpadKey({this.digit, this.icon, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: icon != null
                ? Icon(icon, color: isDark ? Colors.white70 : const Color(0xFF4A5568), size: 24)
                : Text(
                    digit ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1A202C),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
