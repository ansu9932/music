import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity status simplified for the app.
enum ConnectivityStatus { online, offline, metered }

/// Wraps `connectivity_plus` into a single broadcast stream of
/// [ConnectivityStatus], distinguishing metered (mobile) from unmetered.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<ConnectivityStatus> get statusStream =>
      _connectivity.onConnectivityChanged.map(_mapList);

  Future<ConnectivityStatus> current() async {
    final result = await _connectivity.checkConnectivity();
    return _mapList(result);
  }

  Future<bool> get isOnline async =>
      (await current()) != ConnectivityStatus.offline;

  Future<bool> get isMetered async =>
      (await current()) == ConnectivityStatus.metered;

  ConnectivityStatus _mapList(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return ConnectivityStatus.online;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return ConnectivityStatus.metered;
    }
    return ConnectivityStatus.online;
  }
}
