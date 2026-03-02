import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionType { wifi, mobile, ethernet, vpn, none }

class ConnectivityState {
  final ConnectionType type;
  final bool isConnected;

  const ConnectivityState({
    this.type = ConnectionType.none,
    this.isConnected = false,
  });
}

final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityState>(
        ConnectivityNotifier.new);

class ConnectivityNotifier extends Notifier<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  ConnectivityState build() {
    _init();
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return const ConnectivityState();
  }

  Future<void> _init() async {
    // Check initial state
    final results = await Connectivity().checkConnectivity();
    _updateFromResults(results);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen(_updateFromResults);
  }

  void _updateFromResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) {
      state = const ConnectivityState(type: ConnectionType.wifi, isConnected: true);
    } else if (results.contains(ConnectivityResult.ethernet)) {
      state = const ConnectivityState(type: ConnectionType.ethernet, isConnected: true);
    } else if (results.contains(ConnectivityResult.mobile)) {
      state = const ConnectivityState(type: ConnectionType.mobile, isConnected: true);
    } else if (results.contains(ConnectivityResult.vpn)) {
      state = const ConnectivityState(type: ConnectionType.vpn, isConnected: true);
    } else if (results.contains(ConnectivityResult.none)) {
      state = const ConnectivityState(type: ConnectionType.none, isConnected: false);
    } else {
      state = const ConnectivityState(type: ConnectionType.none, isConnected: false);
    }
  }
}
