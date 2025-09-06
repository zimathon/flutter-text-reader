import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connectivity state model
class ConnectivityState {
  final bool isConnected;
  final ConnectivityResult connectivityResult;
  final DateTime lastChecked;

  const ConnectivityState({
    required this.isConnected,
    required this.connectivityResult,
    required this.lastChecked,
  });

  factory ConnectivityState.initial() {
    return ConnectivityState(
      isConnected: true, // Assume connected initially
      connectivityResult: ConnectivityResult.none,
      lastChecked: DateTime.now(),
    );
  }

  ConnectivityState copyWith({
    bool? isConnected,
    ConnectivityResult? connectivityResult,
    DateTime? lastChecked,
  }) {
    return ConnectivityState(
      isConnected: isConnected ?? this.isConnected,
      connectivityResult: connectivityResult ?? this.connectivityResult,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  @override
  String toString() {
    return 'ConnectivityState(isConnected: $isConnected, type: $connectivityResult)';
  }
}

/// Connectivity service provider
class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Connectivity _connectivity;
  StreamSubscription<ConnectivityResult>? _subscription;

  ConnectivityNotifier({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(ConnectivityState.initial()) {
    _initialize();
  }

  void _initialize() {
    // Check initial connectivity
    _checkConnectivity();

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectivity(result);
    });
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectivity(result);
    } catch (e) {
      print('ConnectivityNotifier: Error checking connectivity: $e');
    }
  }

  void _updateConnectivity(ConnectivityResult result) {
    final isConnected = result != ConnectivityResult.none;
    
    state = state.copyWith(
      isConnected: isConnected,
      connectivityResult: result,
      lastChecked: DateTime.now(),
    );

    print('ConnectivityNotifier: Updated - $state');
  }

  /// Manually refresh connectivity status
  Future<void> refresh() async {
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Connectivity provider
final connectivityProvider = 
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

/// Convenience provider for checking if connected
final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).isConnected;
});

/// Convenience provider for getting connectivity type
final connectivityTypeProvider = Provider<ConnectivityResult>((ref) {
  return ref.watch(connectivityProvider).connectivityResult;
});