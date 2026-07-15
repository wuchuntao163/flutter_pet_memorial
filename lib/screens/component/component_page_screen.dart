import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../l10n/tr.dart';

/// 底部导航主 Tab（/page/component），内容待对接
class ComponentPageScreen extends StatelessWidget {
  const ComponentPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          tr('nav.组件', fb: '组件'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Center(
        child: Text(
          tr('nav.page_coming_soon', fb: '页面建设中'),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}
