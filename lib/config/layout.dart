import 'package:flutter/material.dart';

/// 主 Tab 页布局常量
class AppLayout {
  AppLayout._();

  /// 顶部为悬浮宠物预留的额外高度（在 SafeArea 之下）
  static const double floatingPetTopSpace = 56;

  /// 首页 / 我的 顶部宠物卡片上边距（SafeArea 之下）
  static const double homeTopPadding = 61;

  /// 首页 / 我的 顶部宠物卡片内边距
  static const EdgeInsets petCardPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 12,
  );

  static const double petCardBorderRadius = 16;

  /// 顶部卡片：头像与右侧文字间距
  static const double petCardAvatarGap = 12;

  /// 顶部卡片：主标题与下方描述间距（首页名称/我的 ID）
  static const double petCardTextGap = 6;

  /// 首页顶部卡片召唤/召回按钮最大宽度（英文超长时换行）
  static const double petSummonButtonMaxWidth = 80;

  /// 首页 / 我的 顶部卡片宠物头像尺寸
  static const double petAvatarSize = 55;

  /// 召唤悬浮宠物 / GIF 尺寸（与顶部卡片头像独立）
  static const double homePetAvatarSize = 75;

  /// 底部导航条高度 + 下边距（与 [BottomNavBar] 一致）
  static const double bottomNavBarHeight = 55;
  static const double bottomNavBarBottomGap = 16;
  static const double bottomNavBarInset =
      bottomNavBarHeight + bottomNavBarBottomGap;

  /// 首页纪念列表底部为「添加新日子」悬浮按钮预留的滚动内边距
  static const double memorialListAddFabInset = 100;

  /// 首页列表底部滚动留白（FAB + 底部导航占位）
  static const double memorialListBottomInset =
      memorialListAddFabInset + bottomNavBarInset;

  /// 首页「纪念事项」标题区左侧缩进
  static const double memorialSectionTitleInset = 8;

  /// 纪念事项标题与列表间距（网格模式略短，配合图钉区）
  static const double memorialSectionListGap = 4;

  /// 网格列表左右边距（仅网格模式，列表模式不加）
  static const double memorialGridListHorizontalInset = 5;

  /// 网格列表顶部留白（置顶图钉向上溢出半高）
  static const double memorialGridPinTopInset = 8;

  /// 首页网格卡片宽高比（>1 时卡片更扁、高度更矮）
  static const double memorialGridChildAspectRatio = 1.12;

  /// 首页网格行间距
  static const double memorialGridMainAxisSpacing = 12;

  /// 首页网格列间距
  static const double memorialGridCrossAxisSpacing = 18;

  /// 网格卡片水平内边距
  static const double memorialGridCardInsetH = 16;

  /// 网格卡片名称距顶部（略向下靠中间）
  static const double memorialGridTitleTopInset = 20;

  /// 网格卡片底部日期/图标距底边（略向上靠中间）
  static const double memorialGridBottomInset = 20;

  /// 网格卡片名称字号
  static const double memorialGridTitleFontSize = 15;

  /// 网格卡片天数区上下留白（标题与日期之间）
  static const double memorialGridDayCountTopGap = 0;
  static const double memorialGridDayCountBottomGap = 20;

  /// 网格卡片天数字号 / 单位字号
  static const double memorialGridDayCountFontSize = 32;
  static const double memorialGridDayUnitFontSize = 14;

  /// 网格卡片右下角类型图标尺寸
  static const double memorialGridTypeIconSize = 32;

  /// 首页列表卡片编辑/删除按钮宽度（英文 Delete 单行）
  static const double memorialCardActionButtonWidth = 50;

  /// 启动选宠 / 取名页：标题上方留白（配合 SafeArea 内 top: 24）
  static const double petOnboardingTitleTopInset = 84;

  /// 启动页（选宠）列表头像尺寸
  static const double petTypeSelectionAvatarSize = 70;

  /// 取名页预览头像尺寸
  static const double petNamingAvatarSize = 140;

  /// 添加/编辑纪念日页顶部间距（SafeArea 之下）
  static const double memorialAddTopPadding = 20;

  /// 添加/编辑纪念日页标题区固定高度（避免多语言换行导致右上角装饰图错位）
  static const double memorialAddTitleHeight = 50;

  /// 倒数日详情页顶栏下移间距（嵌入 AppBar 工具区上方）
  static const double memorialDetailTopPadding = 15;

  /// 倒数日详情页顶栏工具区高度（不含 topPadding）
  static const double memorialDetailAppBarHeight = 40;

  /// 倒数日详情页天数卡片高度
  static const double memorialDetailCountdownHeight = 290;

  /// 详情 / 存为图片 倒计时卡片内容区左右内边距
  static const double memorialCountdownContentInsetH = 16;

  /// 倒数日详情页天数卡片状态文字字号
  static const double memorialDetailCountdownStatusFontSize = 16;

  /// 倒数日详情页状态文字与天数间距
  static const double memorialDetailCountdownStatusGap = 35;

  /// 倒数日详情页天数字号（在默认基础上 +2）
  static const double memorialDetailCountdownFontSize = 62;

  /// 倒数日详情页天数单位字号（在默认基础上 +2）
  static const double memorialDetailCountdownUnitFontSize = 22;

  /// 倒数日详情页天数图片数字高度
  static const double memorialDetailCountdownDigitHeight = 74;

  /// 倒数日详情页日期卡片垂直内边距
  static const double memorialDetailDateCardPaddingV = 10;

  /// 倒数日详情页日期卡片类型图标尺寸
  static const double memorialDetailDateCardIconSize = 20;

  /// 倒数日详情页日期卡片年份字号
  static const double memorialDetailDateCardYearFontSize = 14;

  /// 存为图片页预览区名称/日期距上下边缘间距（两者相等）
  static const double memorialSaveImageVerticalInset = 28;

  /// 存为图片页预览区状态文字上移偏移
  static const double memorialSaveImageStatusOffset = -20;

  /// 存为图片页预览区状态与天数间距
  static const double memorialSaveImageStatusGap = 40;

  /// 存为图片页预览区状态文字字号
  static const double memorialSaveImageStatusFontSize = 14;

  /// 存为图片页预览区日期文字字号
  static const double memorialSaveImageDateFontSize = 13;
}
