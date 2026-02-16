import 'package:flutter/material.dart';

@immutable
class SemanticThemeColors extends ThemeExtension<SemanticThemeColors> {
  const SemanticThemeColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.terminalBg,
    required this.terminalText,
    required this.onSuccess,
    required this.onWarning,
    required this.onError,
    required this.onInfo,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color terminalBg;
  final Color terminalText;
  final Color onSuccess;
  final Color onWarning;
  final Color onError;
  final Color onInfo;

  @override
  SemanticThemeColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? terminalBg,
    Color? terminalText,
    Color? onSuccess,
    Color? onWarning,
    Color? onError,
    Color? onInfo,
  }) {
    return SemanticThemeColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      terminalBg: terminalBg ?? this.terminalBg,
      terminalText: terminalText ?? this.terminalText,
      onSuccess: onSuccess ?? this.onSuccess,
      onWarning: onWarning ?? this.onWarning,
      onError: onError ?? this.onError,
      onInfo: onInfo ?? this.onInfo,
    );
  }

  @override
  SemanticThemeColors lerp(ThemeExtension<SemanticThemeColors>? other, double t) {
    if (other is! SemanticThemeColors) {
      return this;
    }
    return SemanticThemeColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      terminalBg: Color.lerp(terminalBg, other.terminalBg, t)!,
      terminalText: Color.lerp(terminalText, other.terminalText, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    );
  }

  // Define the light theme semantic colors
  static const light = SemanticThemeColors(
    success: Color(0xFF00C853),
    warning: Color(0xFFFFD600),
    error: Color(0xFFD50000),
    info: Color(0xFF00B0FF),
    terminalBg: Color(0xFF1E1E1E),
    terminalText: Color(0xFF00FF41),
    onSuccess: Colors.white,
    onWarning: Colors.black,
    onError: Colors.white,
    onInfo: Colors.white,
  );

  // Define the dark theme semantic colors
  static const dark = SemanticThemeColors(
    success: Color(0xFF00E676),
    warning: Color(0xFFFFEA00),
    error: Color(0xFFFF5252),
    info: Color(0xFF40C4FF),
    terminalBg: Color(0xFF0C0C0C),
    terminalText: Color(0xFF00FF41),
    onSuccess: Colors.black,
    onWarning: Colors.black,
    onError: Colors.black,
    onInfo: Colors.black,
  );
}
