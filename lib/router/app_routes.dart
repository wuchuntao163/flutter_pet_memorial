/// 应用内路由路径
abstract final class AppRoutes {
  // ── 主 Tab（底部导航）──
  static const home = '/page/home';
  static const profile = '/page/profile';
  static const bindPhone = '/bind-phone';

  // ── 宠物引导 ──
  static const petType = '/pet-type';
  static const avatarStyle = '/avatar-style';
  static String petNaming(String petType) => '/pet-naming/$petType';

  // ── 纪念日 ──
  static const memorialAdd = '/memorial/add';
  static String memorialDetail(String id) => '/memorial/$id';
  static String memorialEdit(String id) => '/memorial/$id/edit';
  static String memorialOverview(String id) => '/memorial/$id/overview';

  /// 领养成功进入首页（带提示）
  static const homeAdopted = '$home?adopted=1';
}
