import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_cache_store.dart';
import '../data/auth_session_store.dart';
import '../data/memorial_store.dart';
import '../data/pet_avatar_store.dart';
import 'pet_image_service.dart';

/// iOS 主屏幕小组件服务
class WidgetService {
  WidgetService._();

  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.example.flutterPetMemorial/widget');
  static const _keyWidgetImageUrlPrefix = 'widget_pet_image_url_';

  /// 更新小组件数据
  Future<void> updateWidget() async {
    if (!Platform.isIOS) return;

    try {
      final cache = AppCacheStore.instance;
      final profile = cache.petProfile;
      final memorials = MemorialStore.instance.items;

      final petName =
          profile?['nickname']?.toString().trim() ??
          profile?['name']?.toString().trim() ??
          '';
      final petType =
          profile?['type']?.toString() ??
          profile?['pet_type']?.toString() ??
          '';
      final petAge = '${cache.accompanyDays}';

      final imageCandidates = await _collectImageCandidates();
      final petImageUrl = imageCandidates.isNotEmpty ? imageCandidates.first : '';
      final petImageBytes = await _loadPetImageBytes(imageCandidates);

      final memorialPayload = memorials
          .take(10)
          .map(
            (day) => {
              'id': day.id,
              'title': day.title,
              'days': '${day.displayDayCount}',
              'status': day.statusLabel,
            },
          )
          .toList();

      final token = AuthSessionStore.instance.token;
      final payload = <String, dynamic>{
        'petName': petName,
        'petType': petType,
        'petAge': petAge,
        'petImageUrl': petImageUrl,
        'memorials': jsonEncode(memorialPayload),
      };
      if (petImageBytes != null && petImageBytes.isNotEmpty) {
        payload['petImageBytes'] = petImageBytes;
      }
      if (token != null && token.isNotEmpty) {
        payload['authToken'] = token;
      }

      await _channel.invokeMethod<void>('updateWidget', payload);

      if (petImageUrl.isNotEmpty) {
        await _persistWidgetImageUrl(petImageUrl);
      }

      if (kDebugMode) {
        debugPrint(
          '[WidgetService] updateWidget ok: name=$petName '
          'candidates=${imageCandidates.length} '
          'url=${petImageUrl.isEmpty ? '-' : petImageUrl} '
          'bytes=${petImageBytes?.length ?? 0}',
        );
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[WidgetService] updateWidget platform error: '
          '${e.code} ${e.message}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[WidgetService] updateWidget failed: $e\n$st');
      }
    }
  }

  static bool _isCustomPet(Map? profile) {
    final type = profile?['type']?.toString() ?? profile?['pet_type']?.toString();
    return type == '3' || type == 'custom';
  }

  Future<List<String>> _collectImageCandidates() async {
    final profile = AppCacheStore.instance.petProfile;
    final urls = <String>[];
    final seen = <String>{};

    void add(String? raw) {
      if (raw == null) return;
      final value = raw.trim();
      if (value.isEmpty) return;
      final resolved = PetImageService.resolveUrl(value);
      for (final candidate in [resolved, value]) {
        if (candidate.isEmpty || seen.contains(candidate)) continue;
        seen.add(candidate);
        urls.add(candidate);
      }
    }

    add(profile?['image']?.toString());
    if (_isCustomPet(profile)) {
      add(PetAvatarStore.customAvatarUrl);
      add(await _loadPersistedWidgetImageUrl());
    }
    add(profile?['animated_image']?.toString());

    return urls;
  }

  Future<String?> _loadPersistedWidgetImageUrl() async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('$_keyWidgetImageUrlPrefix$petId')?.trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Future<void> _persistWidgetImageUrl(String url) async {
    final petId = AppCacheStore.instance.petId;
    if (petId == null || url.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyWidgetImageUrlPrefix$petId', url.trim());
  }

  Future<Uint8List?> _loadPetImageBytes(List<String> candidates) async {
    for (final candidate in candidates) {
      final local = await _readLocalImageBytes(candidate);
      if (local != null && local.isNotEmpty) return local;
    }

    for (final candidate in candidates) {
      if (!candidate.startsWith('http://') && !candidate.startsWith('https://')) {
        continue;
      }
      final bytes = await _downloadBytes(candidate);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    }

    return null;
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final token = AuthSessionStore.instance.token;
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] =
            token.startsWith('Bearer ') ? token : 'Bearer $token';
      }

      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          headers: headers,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WidgetService] download image failed ($url): $e');
      }
      return null;
    }
  }

  Future<Uint8List?> _readLocalImageBytes(String path) async {
    if (path.isEmpty) return null;

    if (path.startsWith('file://')) {
      final file = File(path.replaceFirst('file://', ''));
      if (await file.exists()) {
        return file.readAsBytes();
      }
      return null;
    }

    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      final file = File(path);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }

    return null;
  }
}
