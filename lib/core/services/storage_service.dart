import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref);
});

class StorageService {
  static const String connectionsBox = 'connections';
  static const String monitorsBox = 'monitors';
  static const String historyBox = 'history';
  static const String settingsBox = 'settings';
  static const String snippetsBox = 'snippets';

  final Ref _ref;

  StorageService(this._ref);

  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(connectionsBox);
    await Hive.openBox(monitorsBox);
    await Hive.openBox(historyBox);
    await Hive.openBox(settingsBox);
    await Hive.openBox(snippetsBox);
  }

  Box get connections => Hive.box(connectionsBox);
  Box get monitors => Hive.box(monitorsBox);
  Box get history => Hive.box(historyBox);
  Box get settings => Hive.box(settingsBox);
  Box get snippets => Hive.box(snippetsBox);

  // Generic CRUD operations with optional Firebase sync
  Future<void> save(String boxName, String key, dynamic value) async {
    final box = Hive.box(boxName);
    await box.put(key, value);
    // Fire-and-forget cloud sync
    _syncToCloud(boxName, key, value);
  }

  dynamic get(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  Future<void> delete(String boxName, String key) async {
    final box = Hive.box(boxName);
    await box.delete(key);
  }

  List<dynamic> getAll(String boxName) {
    final box = Hive.box(boxName);
    return box.values.toList();
  }

  Map<dynamic, dynamic> getAllMap(String boxName) {
    final box = Hive.box(boxName);
    return box.toMap();
  }

  Future<void> clearBox(String boxName) async {
    final box = Hive.box(boxName);
    await box.clear();
  }

  /// Background sync to Firebase (fire-and-forget)
  void _syncToCloud(String boxName, String key, dynamic value) {
    try {
      final firebase = _ref.read(firebaseServiceProvider);
      if (!firebase.isAvailable || !firebase.isSignedIn) return;

      if (value is Map<String, dynamic>) {
        switch (boxName) {
          case connectionsBox:
            firebase.syncConnection(key, value);
            break;
          case settingsBox:
            firebase.syncSetting(key, value);
            break;
          // Monitors are synced via monitor_provider directly
        }
      }
    } catch (_) {
      // Cloud sync failure should never break local operations
    }
  }
}

