import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../../config/colors.dart';
import '../../data/saved_widget_store.dart';
import '../../utils/app_permission_util.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_image_picker.dart';
import '../../utils/saving_overlay.dart';

/// iOS 桌面组件假透明：选择整张壁纸 → 按机型裁切 → 引导设为系统壁纸
class TransparentWallpaperSetupScreen extends StatefulWidget {
  const TransparentWallpaperSetupScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TransparentWallpaperSetupScreen(),
      ),
    );
  }

  @override
  State<TransparentWallpaperSetupScreen> createState() =>
      _TransparentWallpaperSetupScreenState();
}

class _TransparentWallpaperSetupScreenState
    extends State<TransparentWallpaperSetupScreen> {
  static const _positions = ['左上', '右上', '左下', '右下', '居中'];
  String _selectedPosition = '左上';
  bool _ready = false;
  String? _localPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: const Text('透明壁纸'),
        backgroundColor: const Color(0xFFF7F8FB),
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            '系统不允许第三方组件真正透视桌面。做法是：选用与桌面相同的整张壁纸，App 按 iPhone 型号裁出各方位小图，组件再按「透明位置」加载对应裁切。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _stepCard(
            index: 1,
            title: '选择整张桌面壁纸',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '建议先在桌面空白页截图，或从相册选择与当前壁纸一致的原图。',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 12),
                if (_localPath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 9 / 19.5,
                      child: Image.file(File(_localPath!), fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _pickWallpaper,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_localPath == null ? '从相册选择壁纸' : '重新选择壁纸'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _stepCard(
            index: 2,
            title: '设为系统壁纸（必做）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'iOS 不允许 App 直接改系统壁纸。请将图片保存到相册后，在「照片」中打开 → 分享 → 用作墙纸，并选择「设定主屏幕」。',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _ready ? _saveToPhotos : null,
                  child: const Text('保存壁纸到相册'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _stepCard(
            index: 3,
            title: 'App 内默认透明位置',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '桌面长按组件 → 编辑 →「透明位置」可选方位；也可选「跟随 App 内设置」。',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _positions.map((pos) {
                    final selected = pos == _selectedPosition;
                    return ChoiceChip(
                      label: Text(pos),
                      selected: selected,
                      onSelected: _ready
                          ? (_) => _selectPosition(pos)
                          : null,
                      selectedColor: AppColors.accent.withValues(alpha: 0.25),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_ready)
            const Text(
              '已生成各方位裁切。请确认系统壁纸与所选图一致，再在桌面开启透明位置。',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accentDarker,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepCard({
    required int index,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. $title',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> _pickWallpaper() async {
    try {
      final path = await PetImagePicker.pickFromGallery(context);
      if (path == null || path.isEmpty || !mounted) return;
      final ok = await withSavingOverlay(context, () async {
        return SavedWidgetStore.instance
            .setupTransparentWallpapersFromScreenshot(path);
      });
      if (!mounted) return;
      if (ok == true) {
        await SavedWidgetStore.instance.setAppTransparentPosition(
          _selectedPosition,
        );
        setState(() {
          _localPath = path;
          _ready = true;
        });
        await showCenterTip(context, '壁纸裁切已生成');
      } else {
        await showCenterTip(context, '壁纸处理失败，请换一张竖屏图重试');
      }
    } on AppPermissionDeniedException catch (error) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, error);
    } catch (error) {
      if (!mounted) return;
      debugPrint('[TransparentWallpaper] pick failed: $error');
      await showCenterTip(context, '壁纸处理失败');
    }
  }

  Future<void> _saveToPhotos() async {
    final path = _localPath;
    if (path == null) return;
    try {
      await AppPermissionUtil.ensureGalleryAccess();
      final bytes = await File(path).readAsBytes();
      await Gal.putImageBytes(bytes);
      if (!mounted) return;
      await showCenterTip(context, '已保存到相册，请到「照片」设为墙纸');
    } on AppPermissionDeniedException catch (error) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, error);
    } catch (error) {
      if (!mounted) return;
      debugPrint('[TransparentWallpaper] save photos failed: $error');
      await showCenterTip(context, '保存到相册失败');
    }
  }

  Future<void> _selectPosition(String pos) async {
    setState(() => _selectedPosition = pos);
    await SavedWidgetStore.instance.setAppTransparentPosition(pos);
    if (!mounted) return;
    await showCenterTip(context, '已设为「$pos」');
  }
}
