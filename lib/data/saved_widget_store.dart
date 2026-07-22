import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_widget.dart';
import '../models/widget_definition.dart';
import '../models/font_style_config.dart';
import '../services/pet_image_service.dart';
import 'auth_session_store.dart';

class SavedWidgetStore extends ChangeNotifier {
  SavedWidgetStore._();

  static final SavedWidgetStore instance = SavedWidgetStore._();
  static const _storageKey = 'saved_widget_library_v1';
  static const _channel = MethodChannel(
    'com.example.flutterPetMemorial/widget',
  );

  final List<SavedWidget> _items = [];
  bool _loaded = false;

  List<SavedWidget> get items => List.unmodifiable(_items);

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items
            ..clear()
            ..addAll(
              decoded.whereType<Map>().map(
                (item) => SavedWidget.fromJson(Map<String, dynamic>.from(item)),
              ),
            );
        }
      } catch (error) {
        debugPrint('[SavedWidgetStore] load failed: $error');
      }
    } else if (force) {
      _items.clear();
    }
    notifyListeners();
  }

  Future<void> saveDefinition(
    WidgetDefinition definition, {
    Map<String, dynamic> settings = const {},
    Uint8List? previewPng,
  }) async {
    if (definition.type != 1 || definition.id <= 0) return;
    await load();

    final mergedSettings = <String, dynamic>{
      ...settings,
      'widget_column': definition.columnSpan,
      'widget_row': definition.rowSpan,
    };

    // 截图 → App Group 本地预览 → 上传拿网络链接
    var image = definition.image;
    if (previewPng != null && previewPng.isNotEmpty) {
      final localPath = await _persistPreviewImage(definition.id, previewPng);
      if (localPath != null) {
        await _syncPreviewToAppGroup(definition.id, localPath);
        try {
          image = await PetImageService.upload(localPath);
        } catch (error) {
          debugPrint('[SavedWidgetStore] upload preview failed: $error');
          rethrow;
        }
      }
    }

    // 背景图：网络地址先由 Flutter 下载到本地，再写入 App Group（Widget 扩展网络不可靠）
    // 纯色色盘：清空 background_image，并删掉旧的 App Group 背景文件，否则会盖住 background_color
    final bg = '${mergedSettings['background_image'] ?? ''}'.trim();
    if (bg.isNotEmpty) {
      await syncBackgroundImage(widgetId: definition.id, imageRef: bg);
    } else {
      await clearBackgroundImage(widgetId: definition.id);
    }

    // 自定义数字字体 0–9 → 小组件实时天数
    final fontStyle = '${mergedSettings['font_style'] ?? ''}'.trim();
    await _syncDigitsToAppGroup(definition.id, fontStyle);

    // 类型图标（照片倒计时标题旁）
    final iconUrl = '${mergedSettings['icon_url'] ?? ''}'.trim();
    if (iconUrl.isNotEmpty) {
      await _syncIconToAppGroup(definition.id, iconUrl);
    }

    final item = SavedWidget(
      widgetId: definition.id,
      title: definition.title,
      image: image,
      template: definition.template,
      savedAt: DateTime.now(),
      settings: mergedSettings,
    );
    final index = _items.indexWhere((value) => value.widgetId == item.widgetId);
    if (index == -1) {
      _items.insert(0, item);
    } else {
      _items
        ..removeAt(index)
        ..insert(0, item);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(int widgetId) async {
    await load();
    _items.removeWhere((item) => item.widgetId == widgetId);
    await _persist();
    await _deletePreview(widgetId);
    notifyListeners();
  }

  Future<String?> _persistPreviewImage(int widgetId, Uint8List bytes) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/saved_widget_preview_$widgetId.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (error) {
      debugPrint('[SavedWidgetStore] persist preview failed: $error');
      return null;
    }
  }

  Future<void> _syncPreviewToAppGroup(int widgetId, String localPath) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('saveWidgetPreview', {
        'widgetId': widgetId,
        'localImagePath': localPath,
      });
    } catch (error) {
      debugPrint('[SavedWidgetStore] sync preview failed: $error');
    }
  }

  /// 把相册临时图拷到 Documents，避免保存/同步时原路径已失效。
  Future<String?> persistLocalBackgroundCopy({
    required int widgetId,
    required String sourcePath,
  }) async {
    try {
      final src = sourcePath.startsWith('file://')
          ? Uri.parse(sourcePath).toFilePath()
          : sourcePath;
      final bytes = await File(src).readAsBytes();
      if (bytes.isEmpty) return null;
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/widget_album_bg_$widgetId.bin');
      await dest.writeAsBytes(bytes, flush: true);
      return dest.path;
    } catch (error) {
      debugPrint('[SavedWidgetStore] persistLocalBackgroundCopy failed: $error');
      return null;
    }
  }

  Future<void> clearBackgroundImage({required int widgetId}) async {
    if (!Platform.isIOS || widgetId <= 0) return;
    try {
      await _channel.invokeMethod<void>('clearWidgetBackground', {
        'widgetId': widgetId,
      });
    } catch (error) {
      debugPrint('[SavedWidgetStore] clear background failed: $error');
    }
  }

  /// [imageRef] 可为本地路径或 http(s) URL。
  /// 与背景列表相同：先落到 App 沙盒，再写入 App Group 供桌面读取（扩展内网络不可靠）。
  Future<void> syncBackgroundImage({
    required int widgetId,
    required String imageRef,
  }) async {
    if (!Platform.isIOS || widgetId <= 0) return;
    final trimmed = imageRef.trim();
    if (trimmed.isEmpty) return;

    try {
      final isLocal =
          trimmed.startsWith('/') ||
          trimmed.startsWith('file://') ||
          RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed);

      late final String localPath;
      if (isLocal) {
        localPath =
            await persistLocalBackgroundCopy(
              widgetId: widgetId,
              sourcePath: trimmed,
            ) ??
            (trimmed.startsWith('file://')
                ? Uri.parse(trimmed).toFilePath()
                : trimmed);
      } else {
        // 相册 upload 得到的 URL 与背景列表 URL 同一处理
        localPath = await PetImageService.downloadToDocuments(
          PetImageService.resolveUrl(trimmed),
          filename: 'saved_widget_bg_$widgetId.img',
        );
      }

      await _channel.invokeMethod<void>('saveWidgetBackground', {
        'widgetId': widgetId,
        'localImagePath': localPath,
      });
    } catch (error) {
      debugPrint('[SavedWidgetStore] sync background failed: $error');
      rethrow;
    }
  }

  Future<void> _syncDigitsToAppGroup(int widgetId, String fontStyleId) async {
    if (!Platform.isIOS) return;
    final urls = FontStyleConfig.digitImageUrls(fontStyleId);
    try {
      if (urls == null || urls.length < 10) {
        // 切回普通数字：清掉旧的自定义数字图，否则桌面仍按图片字体渲染
        await _channel.invokeMethod<void>('clearWidgetDigits', {
          'widgetId': widgetId,
        });
        return;
      }
      await _channel.invokeMethod<void>('saveWidgetDigits', {
        'widgetId': widgetId,
        'digitUrls': urls
            .take(10)
            .map((u) => PetImageService.resolveUrl(u))
            .toList(),
        'authToken': AuthSessionStore.instance.token ?? '',
      });
    } catch (error) {
      debugPrint('[SavedWidgetStore] sync digits failed: $error');
    }
  }

  Future<void> _syncIconToAppGroup(int widgetId, String imageUrl) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('saveWidgetIcon', {
        'widgetId': widgetId,
        'imageUrl': PetImageService.resolveUrl(imageUrl),
        'authToken': AuthSessionStore.instance.token ?? '',
      });
    } catch (error) {
      debugPrint('[SavedWidgetStore] sync icon failed: $error');
    }
  }

  Future<void> _deletePreview(int widgetId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/saved_widget_preview_$widgetId.png');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('[SavedWidgetStore] delete local preview failed: $error');
    }
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('removeWidgetPreview', {
        'widgetId': widgetId,
      });
    } catch (error) {
      debugPrint('[SavedWidgetStore] remove iOS preview failed: $error');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod<void>('syncWidgetConfigs', {
          'configs': jsonEncode(_items.map((item) => item.toJson()).toList()),
          'authToken': AuthSessionStore.instance.token ?? '',
        });
      } catch (error) {
        debugPrint('[SavedWidgetStore] iOS sync failed: $error');
      }
    }
  }
}
