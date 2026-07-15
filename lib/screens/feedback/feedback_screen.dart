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
    if (content.isEmpty) {
      showCenterTip(context, tr('feedback.content_required'));
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _field(
                label: tr('feedback.name_label'),
                controller: _nameController,
                hint: tr('feedback.name_hint'),
              ),
              const SizedBox(height: 12),
              _field(
                label: tr('feedback.phone_label'),
                controller: _phoneController,
                hint: tr('feedback.phone_hint'),
                keyboardType: TextInputType.phone,
                maxLength: 11,
              ),
              const SizedBox(height: 12),
              _field(
                label: tr('feedback.content_label'),
                controller: _contentController,
                hint: tr('feedback.content_hint'),
                maxLines: 6,
                maxLength: 500,
              ),
              const SizedBox(height: 12),
              Text(
                tr('feedback.images_label'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr('feedback.images_hint'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              _buildImageGrid(),
              const SizedBox(height: 24),
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
      spacing: 10,
      runSpacing: 10,
      children: List.generate(count, (index) {
        if (index < _localImages.length) {
          final path = _localImages[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(path),
                  width: 84,
                  height: 84,
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
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.bgWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 28,
              color: AppColors.textTertiary,
            ),
          ),
        );
      }),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.accentDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: !_submitting,
          onTapOutside: (_) => _dismissKeyboard(),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
            filled: true,
            fillColor: AppColors.bgWhite,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}
