import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/website_monitor.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/storage_service.dart';

final monitorsProvider = NotifierProvider<MonitorsNotifier, List<WebsiteMonitor>>(MonitorsNotifier.new);

class MonitorsNotifier extends Notifier<List<WebsiteMonitor>> {
  final Map<String, Timer> _timers = {};

  @override
  List<WebsiteMonitor> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });
    _load();
    return [];
  }

  void _load() {
    try {
      final storage = ref.read(storageServiceProvider);
      final raw = storage.getAllMap(StorageService.monitorsBox);
      final monitors = raw.values
          .map((v) => WebsiteMonitor.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      monitors.sort((a, b) => a.name.compareTo(b.name));
      state = monitors;

      // Start timers for active monitors
      for (final monitor in monitors) {
        if (monitor.isActive) {
          _startTimer(monitor);
        }
      }
    } catch (_) {
      state = [];
    }
  }

  void _startTimer(WebsiteMonitor monitor) {
    _timers[monitor.id]?.cancel();
    _timers[monitor.id] = Timer.periodic(
      Duration(seconds: monitor.checkIntervalSeconds),
      (_) => checkMonitor(monitor.id),
    );
  }

  Future<void> addMonitor(WebsiteMonitor monitor) async {
    final storage = ref.read(storageServiceProvider);
    await storage.save(StorageService.monitorsBox, monitor.id, monitor.toJson());
    state = [...state, monitor];
    if (monitor.isActive) {
      _startTimer(monitor);
      checkMonitor(monitor.id);
    }
  }

  Future<void> updateMonitor(WebsiteMonitor monitor) async {
    final storage = ref.read(storageServiceProvider);
    await storage.save(StorageService.monitorsBox, monitor.id, monitor.toJson());
    state = state.map((m) => m.id == monitor.id ? monitor : m).toList();
  }

  Future<void> removeMonitor(String id) async {
    _timers[id]?.cancel();
    _timers.remove(id);
    final storage = ref.read(storageServiceProvider);
    await storage.delete(StorageService.monitorsBox, id);
    state = state.where((m) => m.id != id).toList();
  }

  Future<void> toggleMonitor(String id) async {
    final index = state.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final monitor = state[index];
    final updated = monitor.copyWith(isActive: !monitor.isActive);
    
    if (updated.isActive) {
      _startTimer(updated);
      checkMonitor(updated.id);
    } else {
      _timers[id]?.cancel();
      _timers.remove(id);
    }

    await updateMonitor(updated);
  }

  Future<void> checkMonitor(String id) async {
    final index = state.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final monitor = state[index];
    final networkService = ref.read(networkServiceProvider);

    MonitorCheckResult result;

    try {
      switch (monitor.type) {
        case MonitorType.http:
          final httpResult = await networkService.checkHttp(monitor.url);
          result = MonitorCheckResult(
            timestamp: DateTime.now(),
            isUp: httpResult.isSuccess,
            statusCode: httpResult.statusCode,
            responseTime: httpResult.responseTime,
            error: httpResult.error,
          );
          break;
        case MonitorType.ping:
          final pingResult = await networkService.ping(monitor.url);
          result = MonitorCheckResult(
            timestamp: DateTime.now(),
            isUp: pingResult.isReachable,
            responseTime: pingResult.responseTime,
            error: pingResult.error,
          );
          break;
        case MonitorType.port:
          final portResult = await networkService.scanPort(
            monitor.url,
            monitor.port ?? 80,
          );
          result = MonitorCheckResult(
            timestamp: DateTime.now(),
            isUp: portResult.isOpen,
            responseTime: portResult.responseTime,
          );
          break;
      }
    } catch (e) {
      result = MonitorCheckResult(
        timestamp: DateTime.now(),
        isUp: false,
        error: e.toString(),
      );
    }

    final history = [...monitor.history, result];
    // Keep only last 1000 entries
    final trimmedHistory = history.length > 1000
        ? history.sublist(history.length - 1000)
        : history;

    final updatedMonitor = monitor.copyWith(history: trimmedHistory);
    await updateMonitor(updatedMonitor);
  }

  Future<void> checkAll() async {
    for (final monitor in state) {
      if (monitor.isActive) {
        await checkMonitor(monitor.id);
      }
    }
  }
}
