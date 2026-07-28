import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../l10n/tr.dart';
import '../../services/pet_image_service.dart';
import '../../utils/app_permission_util.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_image_picker.dart';
import '../../widgets/common/gradient_tap_button.dart';

/// 意见反馈：提交 opinion；有图先调 /api/base/upload
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _maxImages = 3;
  static const _fieldRadius = 16.0;
  static const _imageSize = 88.0;
  /// 输入框浅灰描边（参考设计稿，避免过重）
  static const _borderGray = Color(0xFFE8E2DC);

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _contentController = TextEditingController();
  final List<String> _localImages = [];
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    _dismissKeyboard();
    if (_localImages.length >= _maxImages) {
      showCenterTip(context, tr('feedback.images_limit'));
      return;
    }
    try {
      final remain = _maxImages - _localImages.length;
      final paths = await PetImagePicker.pickMultipleFromGallery(
        context,
        maxAssets: remain,
      );
      if (!mounted || paths.isEmpty) return;
      setState(() => _localImages.addAll(paths));
    } on AppPermissionDeniedException catch (e) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, e);
    } catch (e) {
      if (!mounted) return;
      showCenterTip(context, '$e');
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      showCenterTip(context, tr('feedback.content_required'));
      return;
    }
    if (name.isEmpty) {
      showCenterTip(context, tr('feedback.name_required'));
      return;
    }
    if (phone.isEmpty) {
      showCenterTip(context, tr('feedback.phone_required'));
      return;
    }
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      showCenterTip(context, tr('feedback.phone_invalid'));
      return;
    }

    setState(() => _submitting = true);
    try {
      final imageUrls = <String>[];
      for (final path in _localImages) {
        final url = await PetImageService.upload(path);
        imageUrls.add(url);
      }

      final data = <String, dynamic>{
        'name': name,
        'phone': phone,
        'content': content,
      };
      if (imageUrls.isNotEmpty) {
        data['img'] = imageUrls;
      }

      final res = await Api.post(ApiPaths.opinion, data: data);
      if (!mounted) return;
      await showCenterTip(
        context,
        res.msg.isNotEmpty ? res.msg : tr('feedback.submit_success'),
      );
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      showCenterTip(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showCenterTip(context, '${tr('feedback.submit_failed')}$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textPlaceholder,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: AppColors.bgWhite,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _borderGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _borderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: AppColors.accent, width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: const BorderSide(color: _borderGray),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          tr('profile.feedback'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // 1. 问题描述
              TextField(
                controller: _contentController,
                maxLines: 7,
                minLines: 6,
                maxLength: 500,
                enabled: !_submitting,
                onTapOutside: (_) => _dismissKeyboard(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                decoration: _inputDecoration(
                  hint: tr('feedback.content_hint'),
                ).copyWith(
                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              // 2. 姓名
              TextField(
                controller: _nameController,
                maxLines: 1,
                enabled: !_submitting,
                onTapOutside: (_) => _dismissKeyboard(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: _inputDecoration(hint: tr('feedback.name_hint')),
              ),
              const SizedBox(height: 14),
              // 3. 联系方式
              TextField(
                controller: _phoneController,
                maxLines: 1,
                maxLength: 11,
                keyboardType: TextInputType.phone,
                enabled: !_submitting,
                onTapOutside: (_) => _dismissKeyboard(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: _inputDecoration(hint: tr('feedback.phone_hint')),
              ),
              const SizedBox(height: 18),
              // 4. 上传图片
              Text(
                tr(
                  'feedback.images_label',
                  fb: '上传图片 ({count}/3)',
                ).replaceAll('{count}', '${_localImages.length}'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 10),
              _buildImageGrid(),
              const SizedBox(height: 28),
              GradientTapButton(
                onTap: _submitting
                    ? null
                    : () {
                        _dismissKeyboard();
                        _submit();
                      },
                gradient: AppColors.avatarGenerateGradient,
                width: double.infinity,
                height: 46,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.avatarGenerateButtonText,
                        ),
                      )
                    : Text(
                        tr('feedback.submit'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.avatarGenerateButtonText,
                        ),
                      ),
              ),
              SizedBox(height: AppLayout.bottomNavBarInset),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final canAdd = _localImages.length < _maxImages;
    final count = _localImages.length + (canAdd ? 1 : 0);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(count, (index) {
        if (index < _localImages.length) {
          final path = _localImages[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_fieldRadius),
                child: Image.file(
                  File(path),
                  width: _imageSize,
                  height: _imageSize,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _localImages.removeAt(index)),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5C4033),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return GestureDetector(
          onTap: _submitting ? null : _pickImages,
          child: Container(
            width: _imageSize,
            height: _imageSize,
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(_fieldRadius),
              border: Border.all(color: _borderGray, width: 1),
            ),
            child: const Icon(
              Icons.add,
              size: 32,
              color: _borderGray,
            ),
          ),
        );
      }),
    );
  }
}
