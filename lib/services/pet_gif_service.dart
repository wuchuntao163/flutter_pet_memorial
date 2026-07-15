import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../data/app_cache_store.dart';
import '../l10n/tr.dart';
import 'pet_image_service.dart';

/// GIF 任务结果
class PetGifTaskResult {
  final int? status;
  final String message;
  final String? imageUrl;
  final Map<String, int> progress;

  const PetGifTaskResult({
    this.status,
    this.message = '',
    this.imageUrl,
    this.progress = const {},
  });

  bool get isReady {
    final url = imageUrl?.trim();
    return status == 3 && url != null && url.isNotEmpty;
  }

  bool get isFailed => status == 2;

  /// 任务级生成中：`0` 或 `1`
  bool get isGenerating => status == 0 || status == 1;

  /// 兼容旧 map 键；实际以 [orderedStepStatuses] 为准
  static const orderedStepKeys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
  ];

  /// 单步：`3`=已完成，`1`=进行中（闪烁），`0`=未开始，`2`=失败
  static bool isStepCompleted(int value) => value == 3;

  static bool isStepActive(int value) => value == 1;

  int get totalSteps =>
      progress.isNotEmpty ? progress.length : orderedStepKeys.length;

  /// 已完成步数（值为 `3`）
  int get completedCount =>
      orderedStepStatuses.where(isStepCompleted).length;

  /// 当前进行中（status=1）的步骤下标；没有则 -1
  int get currentStepIndex {
    final statuses = orderedStepStatuses;
    for (var i = 0; i < statuses.length; i++) {
      if (isStepActive(statuses[i])) return i;
    }
    return -1;
  }

  /// 按 key 升序的每步 status
  List<int> get orderedStepStatuses {
    if (progress.isEmpty) {
      return List.filled(orderedStepKeys.length, 0);
    }

    final entries = progress.entries.toList()
      ..sort((a, b) {
        final ak = int.tryParse(a.key) ?? 0;
        final bk = int.tryParse(b.key) ?? 0;
        if (ak != bk) return ak.compareTo(bk);
        return a.key.compareTo(b.key);
      });
    return entries.map((e) => e.value).toList();
  }

  double get progressFraction {
    if (isReady) return 1;
    if (totalSteps <= 0) return 0;
    return completedCount / totalSteps;
  }
}

/// 宠物 GIF：查询 / 生成 / 轮询（单路径，避免短时间重复打接口）
class PetGifService {
  PetGifService._();

  static const _pollInterval = Duration(seconds: 2);

  /// 档案已有 GIF 时直接返回 URL
  static String? existingAnimatedImageUrl() {
    final existing =
        AppCacheStore.instance.petProfile?['animated_image']?.toString().trim();
    if (existing == null || existing.isEmpty) return null;
    return PetImageService.resolveUrl(existing);
  }

  /// 触发动图生成（不等待完成）。「使用此形象」时调用。
  static Future<void> requestGeneration({int? petId, String? imageUrl}) async {
    final id = petId ?? AppCacheStore.instance.petId;
    if (id == null) return;

    final image = imageUrl?.trim() ??
        AppCacheStore.instance.petProfile?['image']?.toString().trim();
    if (image == null || image.isEmpty) return;

    try {
      // 已成功或生成中（0/1）则不再提交；失败（2）或未生成则重新发起
      final current = await _fetchTaskResult(id);
      if (current.isReady || current.isGenerating) return;

      await Api.post(
        ApiPaths.generateImageWithTextGif,
        data: {
          'pet_id': id,
          'image': image,
        },
        receiveTimeout: const Duration(seconds: 120),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[PetGifService] requestGeneration failed: $e\n$st');
      }
    }
  }

  /// 召唤宠物时解析动图：有 animated_image 直接用；否则查任务并按需生成/轮询。
  /// [onStatus]：preparing / checking / generating / waiting
  /// [onProgress]：每次查询结果回调（用于进度条），不会额外请求接口
  static Future<String?> resolveAnimatedImage({
    void Function(String statusKey)? onStatus,
    void Function(PetGifTaskResult result)? onProgress,
  }) async {
    final existing = existingAnimatedImageUrl();
    if (existing != null && existing.isNotEmpty) return existing;

    final petId = AppCacheStore.instance.petId;
    if (petId == null) {
      throw ApiException.business(0, tr('memorial.create_pet_first'));
    }

    onStatus?.call('checking');
    var result = await _fetchTaskResult(petId);
    onProgress?.call(result);

    while (true) {
      if (result.isReady) {
        final url = result.imageUrl!;
        return PetImageService.resolveUrl(url);
      }

      if (result.isFailed) {
        // status=2：失败后从头重新发起生成
        onStatus?.call('generating');
        await _postGenerate(petId);
      } else if (result.isGenerating) {
        onStatus?.call('waiting');
      } else if (result.status == null) {
        onStatus?.call('generating');
        await _postGenerate(petId);
      } else {
        onStatus?.call('waiting');
      }

      await Future.delayed(_pollInterval);
      result = await _fetchTaskResult(petId);
      onProgress?.call(result);
    }
  }

  static Future<void> _postGenerate(int petId) async {
    final image =
        AppCacheStore.instance.petProfile?['image']?.toString().trim();
    if (image == null || image.isEmpty) {
      throw ApiException.business(0, tr('summon.no_image'));
    }

    await Api.post(
      ApiPaths.generateImageWithTextGif,
      data: {
        'pet_id': petId,
        'image': image,
      },
      receiveTimeout: const Duration(seconds: 120),
    );
  }

  static Future<PetGifTaskResult> _fetchTaskResult(int petId) async {
    final res = await Api.get(
      ApiPaths.getGifTaskResult,
      query: {'pet_id': petId},
    );
    if (kDebugMode) {
      debugPrint('[PetGifService] getGifTaskResult res=$res');
    }
    final data = PetImageService.dataMap(res.data);
    return PetGifTaskResult(
      status: _parseStatus(data['status']),
      message: data['message']?.toString() ?? res.msg,
      imageUrl: _extractImageUrl(data),
      progress: _parseStepProgress(data),
    );
  }

  /// 解析步骤进度：优先 `list: [{key, status}]`，兼容旧 `progress` map
  static Map<String, int> _parseStepProgress(Map<String, dynamic> data) {
    final list = data['list'];
    if (list is List && list.isNotEmpty) {
      final parsed = <String, int>{};
      for (final item in list) {
        if (item is! Map) continue;
        final key = item['key']?.toString().trim();
        if (key == null || key.isEmpty) continue;
        parsed[key] = _parseStatus(item['status']) ?? 0;
      }
      return parsed;
    }
    return _parseStepsMap(data['progress']);
  }

  static Map<String, int> _parseStepsMap(dynamic raw) {
    if (raw is! Map) return {};
    final parsed = <String, int>{};
    for (final entry in raw.entries) {
      var key = entry.key.toString();
      // 兼容 step_1 → 1
      if (key.startsWith('step_')) {
        key = key.substring(5);
      }
      parsed[key] = int.tryParse(entry.value.toString()) ?? 0;
    }
    return parsed;
  }

  static int? _parseStatus(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final text = raw.trim().toLowerCase();
      if (text.isEmpty || text == 'null') return null;
    }
    return int.tryParse(raw.toString());
  }

  static String? _extractImageUrl(Map<String, dynamic> data) {
    final url = data['image_url']?.toString() ??
        data['gif_url']?.toString() ??
        data['url']?.toString();
    if (url == null || url.trim().isEmpty) return null;
    return url.trim();
  }
}
