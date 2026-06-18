import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../utils/language_id_util.dart';

/// 宠物形象生成风格（getPetStyles）
class AvatarGenerationStyle {
  final String id;
  final String name;
  final String? imageUrl;
  final String? imageAsset;

  const AvatarGenerationStyle({
    required this.id,
    required this.name,
    this.imageUrl,
    this.imageAsset,
  });

  factory AvatarGenerationStyle.fromJson(Map<String, dynamic> json) {
    return AvatarGenerationStyle(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      imageUrl: json['image']?.toString() ?? json['image_url']?.toString(),
    );
  }
}

class AvatarStyleStore {
  AvatarStyleStore._();

  static Future<List<AvatarGenerationStyle>> fetchStyles() async {
    ApiResponse<dynamic> res;
    try {
      res = await Api.get(
        ApiPaths.getPetStyles,
        query: LanguageIdUtil.apply({}),
      );
      // debugPrint('[getPetStyles] res=$res');
    } on ApiException catch (e) {
      debugPrint('[getPetStyles] $e');
      rethrow;
    }
    final rawList = _parseList(res.data);
    return rawList
        .map(AvatarGenerationStyle.fromJson)
        .where((style) => style.id.isNotEmpty && style.name.isNotEmpty)
        .toList();
  }

  static List<Map<String, dynamic>> _parseList(dynamic data) {
    final list = data is Map ? data['list'] : data;
    if (list is! List) return [];

    final result = <Map<String, dynamic>>[];
    for (final raw in list.whereType<Map>()) {
      final map = Map<String, dynamic>.from(raw);
      if (map['is_show'] == 0) continue;
      result.add(map);
    }
    result.sort((a, b) {
      final sortA = int.tryParse('${a['sort']}') ?? 0;
      final sortB = int.tryParse('${b['sort']}') ?? 0;
      return sortA.compareTo(sortB);
    });
    return result;
  }
}
