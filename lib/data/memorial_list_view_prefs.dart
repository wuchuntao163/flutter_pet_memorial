import 'package:shared_preferences/shared_preferences.dart';

/// 纪念事项首页列表 / 网格展示偏好（仅 UI，与通知无关）
class MemorialListViewPrefs {
  MemorialListViewPrefs._();

  static const _keyIsGrid = 'memorial_list_is_grid';

  static Future<bool> loadIsGrid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsGrid) ?? false;
  }

  static Future<void> saveIsGrid(bool isGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGrid, isGrid);
  }
}
