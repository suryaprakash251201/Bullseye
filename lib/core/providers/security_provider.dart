import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';

enum AutoLockDuration {
  off,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  thirtyMinutes,
}

class SecurityState {
  final bool isPinSet;
  final bool isBiometricEnabled;
  final bool isLocked;
  final AutoLockDuration autoLockDuration;

  const SecurityState({
    this.isPinSet = false,
    this.isBiometricEnabled = false,
    this.isLocked = false,
    this.autoLockDuration = AutoLockDuration.fiveMinutes,
  });

  SecurityState copyWith({
    bool? isPinSet,
    bool? isBiometricEnabled,
    bool? isLocked,
    AutoLockDuration? autoLockDuration,
  }) {
    return SecurityState(
      isPinSet: isPinSet ?? this.isPinSet,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isLocked: isLocked ?? this.isLocked,
      autoLockDuration: autoLockDuration ?? this.autoLockDuration,
    );
  }
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(SecurityNotifier.new);

class SecurityNotifier extends Notifier<SecurityState> {
  Timer? _lockTimer;

  @override
  SecurityState build() {
    _load();
    ref.onDispose(() => _lockTimer?.cancel());
    return const SecurityState();
  }

  Future<void> _load() async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    final prefs = await SharedPreferences.getInstance();

    final pin = await secureStorage.getCredential('app_pin');
    final biometric = prefs.getBool('biometric_enabled') ?? false;
    final lockDurationIndex = prefs.getInt('auto_lock_duration') ?? 2;
    final autoLock = AutoLockDuration.values[lockDurationIndex.clamp(0, AutoLockDuration.values.length - 1)];
    final hasPinSet = pin != null && pin.isNotEmpty;

    state = SecurityState(
      isPinSet: hasPinSet,
      isBiometricEnabled: biometric,
      isLocked: hasPinSet, // Lock on startup if PIN is set
      autoLockDuration: autoLock,
    );

    if (hasPinSet) {
      _startLockTimer();
    }
  }

  Future<bool> setPin(String pin) async {
    if (pin.length != 6) return false;
    final secureStorage = ref.read(secureStorageServiceProvider);
    await secureStorage.saveCredential('app_pin', pin);
    state = state.copyWith(isPinSet: true);
    _startLockTimer();
    return true;
  }

  Future<bool> verifyPin(String pin) async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    final storedPin = await secureStorage.getCredential('app_pin');
    if (storedPin == pin) {
      state = state.copyWith(isLocked: false);
      _startLockTimer();
      return true;
    }
    return false;
  }

  Future<void> removePin() async {
    final secureStorage = ref.read(secureStorageServiceProvider);
    await secureStorage.deleteCredential('app_pin');
    state = state.copyWith(isPinSet: false, isLocked: false);
    _lockTimer?.cancel();
  }

  Future<void> setBiometric(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  Future<void> setAutoLockDuration(AutoLockDuration duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_lock_duration', duration.index);
    state = state.copyWith(autoLockDuration: duration);
    _startLockTimer();
  }

  void lock() {
    if (state.isPinSet) {
      state = state.copyWith(isLocked: true);
    }
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
    _startLockTimer();
  }

  void resetLockTimer() {
    if (state.isPinSet && state.autoLockDuration != AutoLockDuration.off) {
      _startLockTimer();
    }
  }

  void _startLockTimer() {
    _lockTimer?.cancel();
    if (state.autoLockDuration == AutoLockDuration.off || !state.isPinSet) return;

    final duration = switch (state.autoLockDuration) {
      AutoLockDuration.off => Duration.zero,
      AutoLockDuration.oneMinute => const Duration(minutes: 1),
      AutoLockDuration.fiveMinutes => const Duration(minutes: 5),
      AutoLockDuration.fifteenMinutes => const Duration(minutes: 15),
      AutoLockDuration.thirtyMinutes => const Duration(minutes: 30),
    };

    if (duration == Duration.zero) return;

    _lockTimer = Timer(duration, () {
      if (state.isPinSet) {
        state = state.copyWith(isLocked: true);
      }
    });
  }

  String get autoLockLabel => switch (state.autoLockDuration) {
    AutoLockDuration.off => 'Off',
    AutoLockDuration.oneMinute => '1 minute',
    AutoLockDuration.fiveMinutes => '5 minutes',
    AutoLockDuration.fifteenMinutes => '15 minutes',
    AutoLockDuration.thirtyMinutes => '30 minutes',
  };
}
