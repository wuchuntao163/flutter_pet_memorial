/// 用户选定的 AI 宠物形象
class PetAvatarStore {
  PetAvatarStore._();

  static String? customAvatarUrl;
  static String? customAvatarDescription;

  static void setAvatar({required String url, String? description}) {
    customAvatarUrl = url;
    customAvatarDescription = description;
  }

  static void clear() {
    customAvatarUrl = null;
    customAvatarDescription = null;
  }
}
