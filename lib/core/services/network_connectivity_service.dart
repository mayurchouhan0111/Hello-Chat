import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized service to monitor and query network connectivity status.
class NetworkConnectivityService {
  static final NetworkConnectivityService _instance = NetworkConnectivityService._internal();
  factory NetworkConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;

  /// Synchronous getter for current online status.
  bool get isOnline => _isOnline;

  /// Stream of online/offline status changes.
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  NetworkConnectivityService._internal() {
    _init();
  }

  void _init() {
    // Initial check
    _connectivity.checkConnectivity().then((results) {
      _updateStatus(results);
    }).catchError((e) {
      debugPrint('[NetworkConnectivityService] Initial check error: $e');
      _isOnline = false;
      _connectivityController.add(false);
    });

    // Listen to changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final bool hasConnection = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);

    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      debugPrint('[NetworkConnectivityService] Connectivity changed: isOnline=$_isOnline (results=$results)');
      _connectivityController.add(_isOnline);
    }
  }

  /// Explicit check returning a Future<bool>.
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return _isOnline;
    } catch (e) {
      debugPrint('[NetworkConnectivityService] Check connection error: $e');
      _isOnline = false;
      _connectivityController.add(false);
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}

/// Provider for the singleton NetworkConnectivityService.
final networkConnectivityServiceProvider = Provider<NetworkConnectivityService>((ref) {
  return NetworkConnectivityService();
});

/// Stream provider for real-time online/offline boolean changes.
final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(networkConnectivityServiceProvider);
  return service.onConnectivityChanged;
});
