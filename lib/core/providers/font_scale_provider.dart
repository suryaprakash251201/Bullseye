import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final fontScaleProvider = NotifierProvider<FontScaleNotifier, double>(FontScaleNotifier.new);

class FontScaleNotifier extends Notifier<double> {
  static const String _key = 'fontScale';

  @override
  double build() {
    _load();
    return 1.0;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? 1.0;
  }

  Future<void> setScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, scale);
    state = scale;
  }

  String get label {
    if (state <= 0.85) return 'Small';
    if (state <= 0.95) return 'Medium Small';
    if (state <= 1.05) return 'Medium';
    if (state <= 1.15) return 'Medium Large';
    return 'Large';
  }
}
