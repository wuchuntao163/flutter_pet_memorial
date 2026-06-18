/// 全部接口路径 + 功能说明（详见项目根目录 [api.md]）
///
/// 用法：`Api.get(ApiPaths.getConfig)` / `Api.post(ApiPaths.loginByUuid, data: {...})`
class ApiPaths {
  ApiPaths._();

  // ═══════════════════════════════════════════════════════════
  //  无需登录 · Common 公共模块
  // ═══════════════════════════════════════════════════════════

  /// 获取应用配置 · GET
  static const getConfig = '/api/common/getConfig';

  /// 获取应用信息（名称/logo/版本） · GET
  static const getAppInfo = '/api/common/getAppInfo';

  /// 获取导航列表（type:1 中间导航，2 底部导航） · GET
  static const nav = '/api/common/nav';

  /// 获取语言列表 · GET
  static const getLanguage = '/api/common/getLanguage';

  /// 获取导航信息 · GET
  static const navigation = '/api/common/navigation';

  /// 获取会员套餐列表 · GET
  static const setMeal = '/api/common/setMeal';

  /// 获取 Access Token · GET
  static const getNew = '/api/common/getNew';

  /// 获取 Banner 轮播图 · GET
  static const getBanner = '/api/common/getBanner';

  // ═══════════════════════════════════════════════════════════
  //  无需登录 · Login 登录模块
  // ═══════════════════════════════════════════════════════════

  /// UUID 登录/注册 · POST
  static const loginByUuid = '/api/login/loginByUuid';

  /// 微信 OpenId 登录 · POST
  static const loginByOpenId = '/api/login/loginByOpenId';

  /// 获取短信验证码 · POST
  static const getSmsCode = '/api/login/getSmsCode';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · Base 文件上传
  // ═══════════════════════════════════════════════════════════

  /// 通用文件上传 · POST
  static const upload = '/api/base/upload';

  /// 本地图片上传 · POST
  static const uploadLocalImage = '/api/base/uploadLocalImage';

  /// 上传模拟图片 · POST
  static const uploadMimicImage = '/api/base/uploadMimicImage';

  /// 上传字体文件 · POST
  static const uploadTtf = '/api/base/uploadTtf';

  /// 删除文件 · POST
  static const delFile = '/api/base/delFile';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · Index 首页
  // ═══════════════════════════════════════════════════════════

  /// 获取弹窗广告 · GET
  static const pop = '/api/index/pop';

  /// 提交意见反馈 · POST
  static const opinion = '/api/index/opinion';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · Pet 宠物 / 纪念日
  // ═══════════════════════════════════════════════════════════

  /// AI 生成宠物图片 · POST
  static const generatePetImage = '/api/pet/generatePetImage';

  /// 获取宠物风格列表 · GET
  static const getPetStyles = '/api/pet/getPetStyles';

  /// 宠物图片抠图（创建任务） · POST
  static const mattingPetImage = '/api/pet/mattingPetImage';

  /// 获取抠图任务结果 · GET
  static const getMattingTaskResult = '/api/pet/getMattingTaskResult';

  /// 创建宠物档案 · POST
  static const createPetProfile = '/api/pet/createPetProfile';

  /// 获取宠物档案 · GET
  static const getPetProfileInfo = '/api/pet/getPetProfileInfo';

  /// 获取纪念日列表 · GET
  static const getAnniversaryList = '/api/pet/getAnniversaryList';

  /// 获取纪念日类型列表 · GET
  static const getTypes = '/api/pet/getTypes';

  /// 获取纪念日类型图标列表 · GET
  static const getAnniversaryTypeIcons = '/api/pet/getAnniversaryTypeIcons';

  /// 添加自定义纪念日类型 · POST
  static const addCustomType = '/api/pet/addCustomType';

  /// 编辑自定义纪念日类型 · POST
  static const editCustomType = '/api/pet/editCustomType';

  /// 删除自定义纪念日类型 · POST
  static const deleteCustomType = '/api/pet/deleteCustomType';

  /// 添加纪念日 · POST
  static const addAnniversary = '/api/pet/addAnniversary';

  /// 编辑纪念日 · POST
  static const editAnniversary = '/api/pet/editAnniversary';

  /// 删除纪念日 · POST
  static const deleteAnniversary = '/api/pet/deleteAnniversary';

  /// 切换默认宠物（重新选择宠物） · POST
  static const reselectPet = '/api/pet/reselectPet';

  /// 获取字体样式列表 · GET
  static const getFontStyles = '/api/pet/getFontStyles';

  /// 获取纪念日背景列表 · GET（category_id、my_user_id）
  static const getBackgrounds = '/api/pet/getBackgrounds';

  /// 获取背景分类列表 · GET
  static const getBackgroundCategories = '/api/pet/getBackgroundCategories';

  /// 上传自定义背景图片 · POST
  static const uploadBackground = '/api/pet/uploadBackground';

  /// 更新背景图片 · POST
  static const updateBackground = '/api/pet/updateBackground';

  /// 删除背景图片 · POST
  static const deleteBackground = '/api/pet/deleteBackground';

  // ═══════════════════════════════════════════════════════════
  //  需要登录 · User 用户
  // ═══════════════════════════════════════════════════════════

  /// 获取用户信息 · GET
  static const getUserInfo = '/api/user/getUserInfo';

  /// 更新用户信息 · POST
  static const updateUserInfo = '/api/user/updateUserInfo';

  /// 更新用户头像/昵称 · POST
  static const updateUserAvatar = '/api/user/updateUserAvatar';

  /// 更新免费使用次数 · POST
  static const updateUserFreeTimes = '/api/user/updateUserFreeTimes';

  /// 绑定手机号 · POST
  static const bindPhone = '/api/user/bindPhone';

  /// 注销账号 · POST
  static const cancelAccount = '/api/user/cancelAccount';
}
