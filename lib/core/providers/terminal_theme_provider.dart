import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TerminalTheme { dark, light, solarized, monokai, dracula }

final terminalThemeProvider = NotifierProvider<TerminalThemeNotifier, TerminalTheme>(TerminalThemeNotifier.new);

class TerminalThemeNotifier extends Notifier<TerminalTheme> {
  static const String _key = 'terminalTheme';

  @override
  TerminalTheme build() {
    _load();
    return TerminalTheme.dark;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_key) ?? 'dark';
    state = TerminalTheme.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TerminalTheme.dark,
    );
  }

  Future<void> setTheme(TerminalTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.name);
    state = theme;
  }

  String get label {
    return switch (state) {
      TerminalTheme.dark => 'Dark',
      TerminalTheme.light => 'Light',
      TerminalTheme.solarized => 'Solarized',
      TerminalTheme.monokai => 'Monokai',
      TerminalTheme.dracula => 'Dracula',
    };
  }

  Color get backgroundColor {
    return switch (state) {
      TerminalTheme.dark => const Color(0xFF0C0C0C),
      TerminalTheme.light => const Color(0xFFF5F5F5),
      TerminalTheme.solarized => const Color(0xFF002B36),
      TerminalTheme.monokai => const Color(0xFF272822),
      TerminalTheme.dracula => const Color(0xFF282A36),
    };
  }

  Color get foregroundColor {
    return switch (state) {
      TerminalTheme.dark => const Color(0xFF00FF41),
      TerminalTheme.light => const Color(0xFF1A1A1A),
      TerminalTheme.solarized => const Color(0xFF839496),
      TerminalTheme.monokai => const Color(0xFFF8F8F2),
      TerminalTheme.dracula => const Color(0xFFF8F8F2),
    };
  }

  Color get cursorColor {
    return switch (state) {
      TerminalTheme.dark => const Color(0xFF00FF41),
      TerminalTheme.light => const Color(0xFF000000),
      TerminalTheme.solarized => const Color(0xFFB58900),
      TerminalTheme.monokai => const Color(0xFFF92672),
      TerminalTheme.dracula => const Color(0xFFFF79C6),
    };
  }
}
