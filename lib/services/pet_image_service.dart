import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../api/api.dart';

class GeneratedPetImage {
  final String localPath;
  final String remoteUrl;

  const GeneratedPetImage({
    required this.localPath,
    required this.remoteUrl,
  });
}

class MattingTaskProgress {
  final String status;
  final String? message;
  final String? imageUrl;

  const MattingTaskProgress({
    required this.status,
    this.message,
    this.imageUrl,
  });
}

/// 宠物 AI 形象：本地上传 → 生成图片 → 抠图轮询
class PetImageService {
  PetImageService._();

  static const _mattingPollInterval = Duration(seconds: 2);
  static const _mattingMaxAttempts = 60;

  static Future<String> upload(String localPath) async {
    ApiResponse<dynamic> res;
    try {
      res = await Api.upload(
        ApiPaths.upload,
        filePath: localPath,
        fields: {'type': 'image'},
      );
      _logRes('upload', res);
    } on ApiException catch (e) {
      _logError('upload', e);
      rethrow;
    }
    final url = _extractUrl(res.data);
    if (url == null || url.isEmpty) {
      throw ApiException.business(0, '图片上传失败');
    }
    return resolveUrl(url);
  }

  static Future<String> uploadLocalImage(String localPath) async {
    ApiResponse<dynamic> res;
    try {
      res = await Api.upload(
        ApiPaths.uploadLocalImage,
        filePath: localPath,
        fields: {'type': 'image'},
      );
      _logRes('uploadLocalImage', res);
    } on ApiException catch (e) {
      _logError('uploadLocalImage', e);
      rethrow;
    }
    final url = _extractUrl(res.data);
    if (url == null || url.isEmpty) {
      throw ApiException.business(0, '图片上传失败');
    }
    return resolveUrl(url);
  }

  static Future<String> generatePetImage({
    required String description,
    required String imageUrl,
    String? styleId,
  }) async {
    final data = <String, dynamic>{
      'description': description,
      'image': imageUrl,
    };
    if (styleId != null && styleId.isNotEmpty) {
      final parsed = int.tryParse(styleId);
      data['style_id'] = parsed ?? styleId;
    }
    ApiResponse<dynamic> res;
    try {
      res = await Api.post(
        ApiPaths.generatePetImage,
        data: data,
        receiveTimeout: const Duration(seconds: 120),
      );
      // _logRes('generatePetImage', res);
    } on ApiException catch (e) {
      _logError('generatePetImageError', e);
      rethrow;
    }
    final url = _extractImageUrl(res.data, fallbackMsg: '生成失败', msg: res.msg);
    return resolveUrl(url);
  }

  static Future<String> mattingPetImage({
    required String imageUrl,
    void Function(MattingTaskProgress progress)? onProgress,
  }) async {
    final ApiResponse<dynamic> res;
    try {
      res = await Api.post(
        ApiPaths.mattingPetImage,
        data: {'image': imageUrl},
        receiveTimeout: const Duration(seconds: 120),
      );
      _logRes('mattingPetImage', res);
    } on ApiException catch (e) {
      _logError('mattingPetImageError', e);
      rethrow;
    }

    final data = dataMap(res.data);

    final directUrl = _extractImageUrlFromMap(data);
    if (directUrl != null) {
      onProgress?.call(
        MattingTaskProgress(
          status: 'completed',
          message: res.msg,
          imageUrl: directUrl,
        ),
      );
      return resolveUrl(directUrl);
    }

    final taskId = _extractTaskId(data);
    if (taskId == null) {
      throw ApiException.business(
        0,
        res.msg.isNotEmpty ? res.msg : '抠图任务创建失败',
        data,
      );
    }

    return _pollMattingTaskResult(
      taskId,
      onProgress: onProgress,
    );
  }

  static Future<String> _pollMattingTaskResult(
    String taskId, {
    void Function(MattingTaskProgress progress)? onProgress,
  }) async {
    for (var attempt = 0; attempt < _mattingMaxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(_mattingPollInterval);
      }

      ApiResponse<dynamic> res;
      try {
        res = await Api.get(
          ApiPaths.getMattingTaskResult,
          query: {'task_id': taskId},
        );
      } on ApiException catch (e) {
        _logError('getMattingTaskResult', e);
        rethrow;
      }

      _logRes('getMattingTaskResult', res);

      final data = dataMap(res.data);
      final status = _normalizeTaskStatus(data['status']);
      final message = data['message']?.toString() ?? res.msg;
      final imageUrl = _extractImageUrlFromMap(data);

      final progress = MattingTaskProgress(
        status: status,
        message: message,
        imageUrl: imageUrl,
      );
      onProgress?.call(progress);

      if (_isTaskCompleted(status, imageUrl)) {
        return resolveUrl(imageUrl!);
      }
      if (_isTaskFailed(status)) {
        throw ApiException.business(
          0,
          message.isNotEmpty ? message : '抠图失败',
          data,
        );
      }
    }

    throw ApiException.business(0, '抠图超时，请稍后重试');
  }

  static void _logRes(String api, ApiResponse<dynamic> res) {
    debugPrint('[$api] res=$res');
  }

  static void _logError(String api, ApiException e) {
    debugPrint('[$api] $e');
  }

  static String? _extractTaskId(Map<String, dynamic> data) {
    final taskId = data['task_id']?.toString() ?? data['taskId']?.toString();
    if (taskId == null || taskId.trim().isEmpty) return null;
    return taskId.trim();
  }

  static String? _extractImageUrlFromMap(Map<String, dynamic> data) {
    final url = data['image_url']?.toString() ??
        data['url']?.toString() ??
        data['image']?.toString();
    if (url == null || url.trim().isEmpty) return null;
    return url.trim();
  }

  static String _normalizeTaskStatus(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    if (value.isEmpty) return '';
    if (value == 'completed' ||
        value == 'complete' ||
        value == 'success' ||
        value == 'done' ||
        value == '2' ||
        value == 'finished') {
      return 'completed';
    }
    if (value == 'failed' ||
        value == 'fail' ||
        value == 'error' ||
        value == '3' ||
        value == '-1') {
      return 'failed';
    }
    if (value == 'processing' ||
        value == 'pending' ||
        value == 'running' ||
        value == 'wait' ||
        value == 'waiting' ||
        value == '1' ||
        value == '0') {
      return 'processing';
    }
    return value;
  }

  static bool _isTaskCompleted(String status, String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return status.isEmpty || status == 'completed';
    }
    return status == 'completed';
  }

  static bool _isTaskFailed(String status) => status == 'failed';

  /// 生成宠物形象：先生成图片，再抠图，返回最终展示 URL
  static Future<String> generateAvatarImage({
    required String description,
    required String referenceImageUrl,
    String? styleId,
    void Function(MattingTaskProgress progress)? onMattingProgress,
  }) async {
    final generated = await generatePetImage(
      description: description,
      imageUrl: referenceImageUrl,
      styleId: styleId,
    );
    return mattingPetImage(
      imageUrl: generated,
      onProgress: onMattingProgress,
    );
  }

  static Future<GeneratedPetImage> generateFromLocal({
    required String localPath,
    required String description,
    String? styleId,
  }) async {
    final uploadedUrl = await uploadLocalImage(localPath);
    final displayUrl = await generateAvatarImage(
      description: description,
      referenceImageUrl: uploadedUrl,
      styleId: styleId,
    );
    final savedPath = await downloadToCache(displayUrl);
    return GeneratedPetImage(localPath: savedPath, remoteUrl: displayUrl);
  }

  static Future<String> downloadToCache(String url) async {
    final dir = await getTemporaryDirectory();
    final ext = _guessExt(url);
    final target = File(
      '${dir.path}/pet_generated_${DateTime.now().millisecondsSinceEpoch}$ext',
    );

    final dio = Dio();
    await dio.download(url, target.path);
    return target.path;
  }

  /// 持久化到 Documents，供桌面小组件读取（临时目录会被系统清理）
  static Future<String> downloadToDocuments(
    String url, {
    String filename = 'pet_widget_avatar.png',
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/$filename');
    final headers = <String, dynamic>{};
    final token = AuthSessionStore.instance.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] =
          token.startsWith('Bearer ') ? token : 'Bearer $token';
    }

    final dio = Dio();
    final response = await dio.download(
      resolveUrl(url),
      target.path,
      options: Options(
        headers: headers,
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw ApiException.business(status, '图片下载失败');
    }
    if (!target.existsSync() || target.lengthSync() == 0) {
      throw ApiException.business(0, '图片下载失败');
    }
    return target.path;
  }

  static String resolveUrl(String url) {
    final value = url.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }
    if (value.startsWith('/')) {
      return '${ApiConfig.baseUrl}$value';
    }
    return '${ApiConfig.baseUrl}/$value';
  }

  static Map<String, dynamic> dataMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final value = data.trim();
      if (value.isEmpty) return {};
      if (value.startsWith('{') || value.startsWith('[')) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      return {'task_id': value};
    }
    return {};
  }

  static String? _extractUrl(dynamic data) {
    if (data is Map) {
      return data['url']?.toString() ?? data['image_url']?.toString();
    }
    return data?.toString();
  }

  static String _extractImageUrl(
    dynamic data, {
    required String fallbackMsg,
    String msg = '',
  }) {
    final url = data is Map
        ? (data['image_url']?.toString() ??
            data['url']?.toString() ??
            data['image']?.toString())
        : data?.toString();
    if (url == null || url.trim().isEmpty) {
      throw ApiException.business(
        0,
        msg.isNotEmpty ? msg : fallbackMsg,
      );
    }
    return url;
  }

  static String _guessExt(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '.png';
    final ext = path.substring(dot).toLowerCase();
    if (ext.length > 5) return '.png';
    return ext;
  }
}
