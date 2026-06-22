import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// 启动前网络状态检测：开屏页等待网络就绪后再进入应用初始化。
class NetworkService {
  NetworkService._();

  static final NetworkService instance = NetworkService._();

  static const _pollInterval = Duration(milliseconds: 400);
  static const _maxWait = Duration(seconds: 12);

  final Connectivity _connectivity = Connectivity();

  bool? _hasConnection;
  List<ConnectivityResult>? _results;

  bool get isReady => _hasConnection != null;

  bool get hasConnection => _hasConnection ?? false;

  List<ConnectivityResult> get results =>
      List<ConnectivityResult>.unmodifiable(_results ?? const []);

  /// 等待获取到网络状态（有网/无网均可），再返回。
  Future<void> ensureReady() async {
    if (isReady) return;

    final deadline = DateTime.now().add(_maxWait);
    while (DateTime.now().isBefore(deadline)) {
      final results = await _connectivity.checkConnectivity();
      _results = results;
      _hasConnection = _hasNetwork(results);

      if (_hasConnection!) {
        if (kDebugMode) {
          debugPrint('[NetworkService] ready: connected ($results)');
        }
        return;
      }

      await Future.delayed(_pollInterval);
    }

    final results = await _connectivity.checkConnectivity();
    _results = results;
    _hasConnection = _hasNetwork(results);

    if (kDebugMode) {
      debugPrint(
        '[NetworkService] ready: ${_hasConnection! ? "connected" : "offline"} ($results)',
      );
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
