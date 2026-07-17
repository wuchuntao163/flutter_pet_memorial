/// 应用内路由路径
abstract final class AppRoutes {
  // ── 主 Tab（底部导航）──
  static const home = '/page/home';
  static const profile = '/page/profile';
  static const component = '/page/component';
  static const componentPet = '/component/pet';
  static const componentPhotoCountdown = '/component/photo-countdown';
  static const componentSimpleCountdown = '/component/simple-countdown';
  static const componentMediumCountdown = '/component/medium-countdown';
  static const componentMultiMemorial = '/component/multi-memorial';
  static const componentBirthdayCountdown = '/component/birthday-countdown';
  static const componentCalendar = '/component/calendar';
  static const componentPetIsland = '/component/pet-island';
  static const componentCountUpIsland = '/component/count-up-island';
  static const componentCountDownIsland = '/component/count-down-island';
  static const componentMemorialIsland = '/component/memorial-island';
  static const componentPhotoIsland = '/component/photo-island';
  static const componentCustomIsland = '/component/custom-island';
  static String componentConfig(int id) => '/component/config/$id';
  static const bindPhone = '/bind-phone';
  static const privacyPolicy = '/privacy-policy';
  static const feedback = '/feedback';

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
