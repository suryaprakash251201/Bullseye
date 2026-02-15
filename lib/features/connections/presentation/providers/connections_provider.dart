import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../shared/models/connection_profile.dart';
import '../../../../core/services/storage_service.dart';

final connectionsProvider = NotifierProvider<ConnectionsNotifier, List<ConnectionProfile>>(ConnectionsNotifier.new);

class ConnectionsNotifier extends Notifier<List<ConnectionProfile>> {
  @override
  List<ConnectionProfile> build() {
    _load();
    return [];
  }

  void _load() {
    try {
      final storage = ref.read(storageServiceProvider);
      final raw = storage.getAllMap(StorageService.connectionsBox);
      final connections = raw.values
          .map((v) => ConnectionProfile.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      connections.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = connections;
    } catch (_) {
      state = [];
    }
  }

  Future<void> addConnection(ConnectionProfile connection) async {
    final storage = ref.read(storageServiceProvider);
    await storage.save(
      StorageService.connectionsBox,
      connection.id,
      connection.toJson(),
    );
    state = [connection, ...state];
  }

  Future<void> updateConnection(ConnectionProfile connection) async {
    final storage = ref.read(storageServiceProvider);
    await storage.save(
      StorageService.connectionsBox,
      connection.id,
      connection.toJson(),
    );
    state = state.map((c) => c.id == connection.id ? connection : c).toList();
  }

  Future<void> removeConnection(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.delete(StorageService.connectionsBox, id);
    await ref.read(secureStorageServiceProvider).deleteConnectionCredentials(id);
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> updateLastConnected(String id) async {
    final index = state.indexWhere((c) => c.id == id);
    if (index != -1) {
      final updated = state[index].copyWith(lastConnectedAt: DateTime.now());
      await updateConnection(updated);
    }
  }

  List<ConnectionProfile> getByType(ConnectionType type) {
    return state.where((c) => c.type == type).toList();
  }

  List<String> get groups {
    return state
        .where((c) => c.group != null)
        .map((c) => c.group!)
        .toSet()
        .toList()
      ..sort();
  }
}
