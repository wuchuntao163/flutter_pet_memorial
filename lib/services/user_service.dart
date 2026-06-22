import 'package:flutter/foundation.dart';

import '../api/api.dart';

/// 用户相关接口：展示读本地缓存，需最新数据时调用 [refreshUserInfo]
class UserService {
  UserService._();

  /// 本地缓存的用户信息（loginByUuid / getUserInfo 写入 SharedPreferences）
  static Map<String, dynamic>? get cachedUserInfo {
    final data = AuthSessionStore.instance.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// 从服务端拉取用户信息并合并写入本地缓存
  static Future<void> refreshUserInfo() async {
    try {
      final userId = AuthSessionStore.instance.userId;
      final query = <String, dynamic>{};
      if (userId != null) query['user_id'] = userId;

      if (kDebugMode) {
        final params = <String, dynamic>{
          'app_id': ApiConfig.appId,
          'source': ApiConfig.source,
          ...query,
        };
        debugPrint(
          '[UserService] getUserInfo ${ApiPaths.getUserInfo} params: $params',
        );
      }

      final res = await Api.get(ApiPaths.getUserInfo, query: query);
      final info = res.data;
      if (info is Map) {
        await AuthSessionStore.instance.mergeUserInfo(
          Map<String, dynamic>.from(info),
        );
      }
      if (kDebugMode) {
        debugPrint('[UserService] getUserInfo response data: $info');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[UserService] refreshUserInfo failed: $e');
      }
    }
  }
}
