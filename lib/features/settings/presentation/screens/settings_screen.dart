import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/font_scale_provider.dart';
import '../../../../core/providers/terminal_theme_provider.dart';
import '../../../../core/providers/security_provider.dart';
import '../../../../core/constants/app_constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final terminalTheme = ref.watch(terminalThemeProvider);
    final security = ref.watch(securityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Appearance
          _SectionTitle('Appearance'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode),
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Optimized for low-light environments'),
                  value: themeMode == ThemeMode.dark,
                  onChanged: (_) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.text_fields),
                  title: const Text('Font Size'),
                  subtitle: Text(ref.read(fontScaleProvider.notifier).label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showFontSizeDialog(context, ref, fontScale),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.terminal),
                  title: const Text('Terminal Theme'),
                  subtitle: Text(ref.read(terminalThemeProvider.notifier).label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTerminalThemeDialog(context, ref, terminalTheme),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Security
          _SectionTitle('Security'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.pin,
                    color: security.isPinSet ? AppTheme.success : null,
                  ),
                  title: const Text('App PIN Lock'),
                  subtitle: Text(security.isPinSet ? 'PIN is set' : 'No PIN configured'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showPinDialog(context, ref, security),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biometric Authentication'),
                  subtitle: const Text('Use fingerprint or Face ID'),
                  value: security.isBiometricEnabled,
                  onChanged: security.isPinSet
                      ? (v) => _toggleBiometric(context, ref, v)
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: const Text('Auto-Lock Timeout'),
                  subtitle: Text(ref.read(securityProvider.notifier).autoLockLabel),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: security.isPinSet,
                  onTap: security.isPinSet
                      ? () => _showAutoLockDialog(context, ref, security)
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: AppTheme.error),
                  title: const Text('Secure Erase All Data'),
                  subtitle: const Text('Remove all stored credentials'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _confirmSecureErase(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Monitoring
          _SectionTitle('Monitoring'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  subtitle: const Text('Alert when monitor goes down'),
                  trailing: Switch(
                    value: true,
                    onChanged: (v) {},
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Default Check Interval'),
                  subtitle: const Text('60 seconds'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.battery_saver),
                  title: const Text('Background Monitoring'),
                  subtitle: const Text('Continue monitoring when app is closed'),
                  value: false,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Data
          _SectionTitle('Data Management'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload),
                  title: const Text('Export Configurations'),
                  subtitle: const Text('Backup connections and monitors'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _exportConfig(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Import Configurations'),
                  subtitle: const Text('Restore from backup file'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _importConfig(context, ref),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Clear Monitor History'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _clearMonitorHistory(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About
          _SectionTitle('About'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Version'),
                  subtitle: Text(AppConstants.appVersion),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.policy),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Licenses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: AppConstants.appVersion,
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Font Size Dialog ──
  void _showFontSizeDialog(BuildContext context, WidgetRef ref, double currentScale) {
    showDialog(
      context: context,
      builder: (ctx) {
        double tempScale = currentScale;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String scaleLabel(double s) {
              if (s <= 0.85) return 'Small';
              if (s <= 0.95) return 'Medium Small';
              if (s <= 1.05) return 'Medium';
              if (s <= 1.15) return 'Medium Large';
              return 'Large';
            }

            return AlertDialog(
              title: const Text('Font Size'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Aa',
                    style: GoogleFonts.inter(fontSize: 24 * tempScale, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(scaleLabel(tempScale), style: GoogleFonts.inter(fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('A', style: GoogleFonts.inter(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: tempScale,
                          min: 0.8,
                          max: 1.3,
                          divisions: 5,
                          label: scaleLabel(tempScale),
                          onChanged: (v) {
                            setDialogState(() => tempScale = v);
                          },
                        ),
                      ),
                      Text('A', style: GoogleFonts.inter(fontSize: 20)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    ref.read(fontScaleProvider.notifier).setScale(tempScale);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Terminal Theme Dialog ──
  void _showTerminalThemeDialog(BuildContext context, WidgetRef ref, TerminalTheme current) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Terminal Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: TerminalTheme.values.map((theme) {
              final label = switch (theme) {
                TerminalTheme.dark => 'Dark',
                TerminalTheme.light => 'Light',
                TerminalTheme.solarized => 'Solarized',
                TerminalTheme.monokai => 'Monokai',
                TerminalTheme.dracula => 'Dracula',
              };
              return RadioListTile<TerminalTheme>(
                title: Text(label),
                subtitle: Container(
                  height: 28,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: _getThemeBg(theme),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '\$ bullseye --status',
                    style: GoogleFonts.firaCode(
                      fontSize: 12,
                      color: _getThemeFg(theme),
                    ),
                  ),
                ),
                value: theme,
                // ignore: deprecated_member_use
                groupValue: current,
                // ignore: deprecated_member_use
                onChanged: (v) {
                  if (v != null) {
                    ref.read(terminalThemeProvider.notifier).setTheme(v);
                    Navigator.pop(ctx);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Color _getThemeBg(TerminalTheme theme) {
    return switch (theme) {
      TerminalTheme.dark => const Color(0xFF0C0C0C),
      TerminalTheme.light => const Color(0xFFF5F5F5),
      TerminalTheme.solarized => const Color(0xFF002B36),
      TerminalTheme.monokai => const Color(0xFF272822),
      TerminalTheme.dracula => const Color(0xFF282A36),
    };
  }

  Color _getThemeFg(TerminalTheme theme) {
    return switch (theme) {
      TerminalTheme.dark => const Color(0xFF00FF41),
      TerminalTheme.light => const Color(0xFF1A1A1A),
      TerminalTheme.solarized => const Color(0xFF839496),
      TerminalTheme.monokai => const Color(0xFFF8F8F2),
      TerminalTheme.dracula => const Color(0xFFF8F8F2),
    };
  }

  // ── PIN Dialog ──
  void _showPinDialog(BuildContext context, WidgetRef ref, SecurityState security) {
    if (security.isPinSet) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('PIN Lock'),
          content: const Text('Your PIN lock is active. What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showChangePinDialog(context, ref);
              },
              child: const Text('Change PIN'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmRemovePin(context, ref);
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Remove PIN'),
            ),
          ],
        ),
      );
    } else {
      _showSetPinDialog(context, ref);
    }
  }

  void _showSetPinDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set 6-Digit PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final pin = controller.text;
                final confirm = confirmController.text;
                if (pin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pin)) {
                  setDialogState(() => errorText = 'PIN must be 6 digits');
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => errorText = 'PINs do not match');
                  return;
                }
                await ref.read(securityProvider.notifier).setPin(pin);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN lock enabled')),
                  );
                }
              },
              child: const Text('Set PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, WidgetRef ref) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'New PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final verified = await ref.read(securityProvider.notifier).verifyPin(currentController.text);
                if (!verified) {
                  setDialogState(() => errorText = 'Current PIN is incorrect');
                  return;
                }
                final newPin = newController.text;
                if (newPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(newPin)) {
                  setDialogState(() => errorText = 'New PIN must be 6 digits');
                  return;
                }
                if (newPin != confirmController.text) {
                  setDialogState(() => errorText = 'PINs do not match');
                  return;
                }
                await ref.read(securityProvider.notifier).setPin(newPin);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN changed successfully')),
                  );
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemovePin(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Remove PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current PIN to remove it:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final verified = await ref.read(securityProvider.notifier).verifyPin(controller.text);
                if (!verified) {
                  setDialogState(() => errorText = 'Incorrect PIN');
                  return;
                }
                await ref.read(securityProvider.notifier).removePin();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN lock removed')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Biometric Toggle ──
  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      try {
        final localAuth = LocalAuthentication();
        final canCheck = await localAuth.canCheckBiometrics;
        final isSupported = await localAuth.isDeviceSupported();

        if (!canCheck && !isSupported) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric auth is not available on this device')),
            );
          }
          return;
        }

        final didAuthenticate = await localAuth.authenticate(
          localizedReason: 'Verify identity to enable biometric unlock',
          biometricOnly: false,
        );

        if (didAuthenticate) {
          await ref.read(securityProvider.notifier).setBiometric(true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biometric error: $e')),
          );
        }
      }
    } else {
      await ref.read(securityProvider.notifier).setBiometric(false);
    }
  }

  // ── Auto Lock Dialog ──
  void _showAutoLockDialog(BuildContext context, WidgetRef ref, SecurityState security) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-Lock Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AutoLockDuration.values.map((duration) {
            final label = switch (duration) {
              AutoLockDuration.off => 'Off',
              AutoLockDuration.oneMinute => '1 minute',
              AutoLockDuration.fiveMinutes => '5 minutes',
              AutoLockDuration.fifteenMinutes => '15 minutes',
              AutoLockDuration.thirtyMinutes => '30 minutes',
            };
            return RadioListTile<AutoLockDuration>(
              title: Text(label),
              value: duration,
              // ignore: deprecated_member_use
              groupValue: security.autoLockDuration,
              // ignore: deprecated_member_use
              onChanged: (v) {
                if (v != null) {
                  ref.read(securityProvider.notifier).setAutoLockDuration(v);
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Export Config ──
  Future<void> _exportConfig(BuildContext context) async {
    try {
      final connectionsBox = Hive.box('connections');
      final monitorsBox = Hive.box('monitors');
      final settingsBox = Hive.box('settings');

      final exportData = {
        'app': 'Bullseye',
        'version': AppConstants.appVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'connections': connectionsBox.toMap().map((k, v) => MapEntry(k.toString(), v)),
        'monitors': monitorsBox.toMap().map((k, v) => MapEntry(k.toString(), v)),
        'settings': settingsBox.toMap().map((k, v) => MapEntry(k.toString(), v)),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'bullseye_backup_$timestamp.json';

      final dir = Directory.systemTemp;
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  // ── Import Config ──
  Future<void> _importConfig(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the full path to the backup JSON file:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'File Path',
                hintText: 'C:\\path\\to\\bullseye_backup.json',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final path = controller.text.trim();
              if (path.isEmpty) return;

              try {
                final file = File(path);
                if (!await file.exists()) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File not found')),
                    );
                  }
                  return;
                }

                final jsonStr = await file.readAsString();
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;

                if (data['app'] != 'Bullseye') {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid backup file')),
                    );
                  }
                  return;
                }

                if (data['connections'] != null) {
                  final box = Hive.box('connections');
                  final connections = data['connections'] as Map<String, dynamic>;
                  for (final entry in connections.entries) {
                    await box.put(entry.key, entry.value);
                  }
                }

                if (data['monitors'] != null) {
                  final box = Hive.box('monitors');
                  final monitors = data['monitors'] as Map<String, dynamic>;
                  for (final entry in monitors.entries) {
                    await box.put(entry.key, entry.value);
                  }
                }

                if (data['settings'] != null) {
                  final box = Hive.box('settings');
                  final settings = data['settings'] as Map<String, dynamic>;
                  for (final entry in settings.entries) {
                    await box.put(entry.key, entry.value);
                  }
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuration imported successfully. Restart app to apply.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Import failed: $e')),
                  );
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  // ── Clear Monitor History ──
  void _clearMonitorHistory(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('This will clear all monitor check history. Monitors will not be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final box = Hive.box('monitors');
                final entries = box.toMap();
                for (final entry in entries.entries) {
                  if (entry.value is Map) {
                    final data = Map<String, dynamic>.from(entry.value as Map);
                    data['history'] = [];
                    await box.put(entry.key, data);
                  }
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Monitor history cleared')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ── Secure Erase ──
  void _confirmSecureErase(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Secure Erase'),
        content: const Text(
          'This will permanently delete ALL stored credentials, connections, and monitor data. This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await Hive.box('connections').clear();
                await Hive.box('monitors').clear();
                await Hive.box('history').clear();
                await Hive.box('settings').clear();
                await Hive.box('snippets').clear();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data securely erased')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erase failed: $e')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Erase Everything'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
