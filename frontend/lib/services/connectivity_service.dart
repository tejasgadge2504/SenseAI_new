import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'storage_service.dart';

enum SyncStatus { idle, syncing, success, error, offline }

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _statusController = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = SyncStatus.idle;
  bool _isOnline = true;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;
  bool get isOnline => _isOnline;

  void init() {
    _connectivity.onConnectivityChanged.listen((result) async {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (!_isOnline) {
        _updateStatus(SyncStatus.offline);
      } else if (!wasOnline && _isOnline) {
        // Just came back online — attempt sync
        await _syncQueue();
      } else {
        _updateStatus(SyncStatus.idle);
      }
    });

    // Check initial state
    _connectivity.checkConnectivity().then((result) {
      _isOnline = result != ConnectivityResult.none;
      if (!_isOnline) _updateStatus(SyncStatus.offline);
    });
  }

  Future<void> _syncQueue() async {
    _updateStatus(SyncStatus.syncing);
    await Future.delayed(const Duration(seconds: 2)); // simulate network flush
    await StorageService.clearSyncQueue();
    _updateStatus(SyncStatus.success);
    await Future.delayed(const Duration(seconds: 3));
    _updateStatus(SyncStatus.idle);
  }

  void _updateStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void dispose() {
    _statusController.close();
  }
}