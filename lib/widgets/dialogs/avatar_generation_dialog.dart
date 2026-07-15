import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../l10n/tr.dart';
import '../../config/colors.dart';
import '../../data/pet_avatar_store.dart';
import '../../services/pet_gif_service.dart';
import '../../services/pet_image_service.dart';
import '../../utils/app_permission_util.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_image_picker.dart';
import '../common/gradient_tap_button.dart';
import '../common/pet_avatar_image.dart';

/// 生成结果
class AvatarGenerationResult {
  final String imageUrl;
  final String description;

  const AvatarGenerationResult({
    required this.imageUrl,
    required this.description,
  });
}

Future<AvatarGenerationResult?> showAvatarGenerationDialog(
  BuildContext context, {
  required String selectedStyleId,
  required String selectedStyleName,
  VoidCallback? onGenerationComplete,
}) {
  return showDialog<AvatarGenerationResult>(
    context: context,
    builder: (_) => AvatarGenerationDialog(
      selectedStyleId: selectedStyleId,
      selectedStyleName: selectedStyleName,
      onGenerationComplete: onGenerationComplete,
    ),
  );
}

class AvatarGenerationDialog extends StatefulWidget {
  final String selectedStyleId;
  final String selectedStyleName;
  final VoidCallback? onGenerationComplete;

  const AvatarGenerationDialog({
    super.key,
    required this.selectedStyleId,
    required this.selectedStyleName,
    this.onGenerationComplete,
  });

  @override
  State<AvatarGenerationDialog> createState() => _AvatarGenerationDialogState();
}

class _AvatarGenerationDialogState extends State<AvatarGenerationDialog> {
  static const _uploadAreaHeight = 170.0;

  final _descriptionController = TextEditingController();
  final _descriptionFocusNode = FocusNode();

  String? _localPath;

  /// 本地图片上传接口返回的 URL，选图后自动上传
  String? _uploadedImageUrl;
  String? _imageUrl;
  bool _isUploadingPhoto = false;
  bool _isGenerating = false;
  bool _isApplyingAvatar = false;
  bool _hasGeneratedOnce = false;
  int _uploadGeneration = 0;

  /// 生成/上传过程中的说明（预览区转圈文案）
  String _statusText = '';

  int _generateGeneration = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  bool get _hasUploadedPhoto => _localPath != null;

  bool get _canTapGenerate =>
      _hasUploadedPhoto && _uploadedImageUrl != null && !_isBusy;

  String get _generateButtonLabel {
    if (_isUploadingPhoto || _isGenerating) return _statusText;
    if (_hasGeneratedOnce) return tr('avatar.regenerate');
    return tr('avatar.generate');
  }

  bool get _isBusy =>
      _isUploadingPhoto || _isGenerating || _isApplyingAvatar;

  bool get _showGenerateLoading => _isUploadingPhoto || _isGenerating;

  Future<void> _pickFromGallery() async {
    try {
      final path = await PetImagePicker.pickFromGallery(context);
      if (path != null) await _onLocalImagePicked(path);
    } on AppPermissionDeniedException catch (e) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, e);
    } catch (e) {
      if (!mounted) return;
      _showMessage('$e');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final path = await PetImagePicker.pickFromCamera();
      if (path != null) await _onLocalImagePicked(path);
    } on AppPermissionDeniedException catch (e) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, e);
    } catch (e) {
      if (!mounted) return;
      _showMessage('${tr('avatar.photo_fail')}$e');
    }
  }

  Future<void> _onLocalImagePicked(String path) async {
    if (!mounted) return;
    _dismissKeyboard();
    final generation = ++_uploadGeneration;
    setState(() {
      _localPath = path;
      _uploadedImageUrl = null;
      _imageUrl = null;
      _hasGeneratedOnce = false;
      _isUploadingPhoto = true;
      _statusText = tr('avatar.uploading');
    });

    try {
      final url = await PetImageService.uploadLocalImage(path);
      if (!mounted || generation != _uploadGeneration) return;
      setState(() {
        _uploadedImageUrl = url;
        _isUploadingPhoto = false;
        _statusText = '';
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _uploadGeneration) return;
      setState(() {
        _isUploadingPhoto = false;
        _statusText = '';
      });
      _showMessage(e.message);
    } catch (e) {
      if (!mounted || generation != _uploadGeneration) return;
      setState(() {
        _isUploadingPhoto = false;
        _statusText = '';
      });
      _showMessage('${tr('avatar.upload_fail')}$e');
    }
  }

  Future<void> _showPickSourceSheet() async {
    _dismissKeyboard();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('dialogs.select_from_album')),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('dialogs.take_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mounted) _dismissKeyboard();
  }

  Future<void> _onGenerateTap() async {
    _dismissKeyboard();
    if (_descriptionController.text.trim().isEmpty) {
      showCenterTip(context, tr('avatar.feature_required'));
      return;
    }
    await _startGeneration();
  }

  Future<void> _startGeneration() async {
    if (!_canTapGenerate || _uploadedImageUrl == null) return;

    final generation = ++_generateGeneration;
    setState(() {
      _isGenerating = true;
      _statusText = tr('avatar.generating');
    });

    try {
      final generated = await PetImageService.generatePetImage(
        description: _descriptionController.text.trim(),
        imageUrl: _uploadedImageUrl!,
        styleId: widget.selectedStyleId,
      );
      if (!mounted || generation != _generateGeneration) return;
      setState(() => _statusText = tr('avatar.matting'));

      final displayUrl = await PetImageService.mattingPetImage(
        imageUrl: generated,
        onProgress: (progress) {
          if (!mounted || generation != _generateGeneration) return;
          final detail = progress.message?.trim();
          final status = progress.status.trim();
          setState(() {
            if (detail != null && detail.isNotEmpty) {
              _statusText = detail;
            } else if (status == 'processing') {
              _statusText = tr('avatar.matting');
            } else {
              _statusText = tr('avatar.matting');
            }
          });
        },
      );
      if (!mounted || generation != _generateGeneration) return;
      setState(() {
        _imageUrl = displayUrl;
        _hasGeneratedOnce = true;
        _isGenerating = false;
        _statusText = '';
      });
      widget.onGenerationComplete?.call();
    } on ApiException catch (e) {
      _handleGenerationError(
        generation,
        e.message.isNotEmpty ? e.message : tr('avatar.generate_fail'),
      );
    } catch (e) {
      _handleGenerationError(generation, '${tr('avatar.generate_fail')}$e');
    }
  }

  void _handleGenerationError(int generation, String message) {
    if (!mounted || generation != _generateGeneration) return;
    setState(() {
      _isGenerating = false;
      _statusText = '';
    });
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('common.confirm')),
          ),
        ],
      ),
    );
  }

  Future<void> _useAvatar() async {
    final url = _imageUrl;
    if (url == null) {
      _dismissKeyboard();
      showCenterTip(context, tr('avatar.generate_first'));
      return;
    }

    final description = _descriptionController.text.trim();
    _dismissKeyboard();
    setState(() => _isApplyingAvatar = true);
    // 先持久化并触发动图生成，提示结束后再关闭弹窗进入取名页
    await _persistAvatar(url: url, description: description);
    unawaited(PetGifService.requestGeneration(imageUrl: url));
    if (!mounted) return;
    await showCenterTip(context, tr('avatar.applying_avatar'));
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(AvatarGenerationResult(imageUrl: url, description: description));
  }

  Future<void> _persistAvatar({
    required String url,
    required String description,
  }) async {
    String? localPath;
    try {
      localPath = await PetImageService.downloadToDocuments(url);
    } catch (_) {
      localPath = null;
    }
    await PetAvatarStore.setAvatar(
      url: url,
      description: description,
      localPath: localPath,
    );
  }

  void _showMessage(String text) {
    showCenterTip(context, text);
  }

  void _viewCurrentImage() {
    if (_isBusy) return;
    final networkUrl = _imageUrl;
    final filePath = _localPath;
    if (networkUrl == null && filePath == null) return;

    _dismissKeyboard();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: networkUrl != null
                    ? PetAvatarImage(url: networkUrl, fit: BoxFit.contain)
                    : Image.file(File(filePath!), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                ),
                icon: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dismissKeyboard() {
    if (_descriptionFocusNode.hasFocus) {
      _descriptionFocusNode.unfocus();
    }
  }

  void _onPointerDownOutsideField(PointerDownEvent event) {
    if (!_descriptionFocusNode.hasFocus) return;

    final renderObject = _descriptionFocusNode.context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      _dismissKeyboard();
      return;
    }

    final fieldRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    if (!fieldRect.contains(event.position)) {
      _dismissKeyboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxDialogHeight = mediaQuery.size.height * 0.88;

    return MediaQuery(
      data: mediaQuery.copyWith(viewInsets: EdgeInsets.zero),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 340,
            maxHeight: maxDialogHeight,
          ),
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _dismissKeyboard,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: AppColors.avatarGenerateGradient,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.selectedStyleName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5C4033),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF5C4033),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxDialogHeight - 48),
                child: Listener(
                  onPointerDown: _onPointerDownOutsideField,
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('avatar.upload_hint'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1,
                            color: Color(0xFF5C4033),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildUploadArea(),
                        if (_hasUploadedPhoto) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              tr('avatar.feature_label'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5C4033),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDescriptionField(),
                        ],
                        const SizedBox(height: 14),
                        _buildGradientButton(
                          label: _generateButtonLabel,
                          gradient: AppColors.avatarGenerateGradient,
                          onPressed: _canTapGenerate ? _onGenerateTap : null,
                          showLoading: _showGenerateLoading,
                        ),
                        if (_imageUrl != null) ...[
                          const SizedBox(height: 10),
                          _buildGradientButton(
                            label: _isApplyingAvatar
                                ? tr('avatar.applying_avatar_button')
                                : tr('avatar.use_avatar'),
                            gradient: AppColors.avatarActionGradient,
                            onPressed: _isBusy
                                ? null
                                : () {
                                    _dismissKeyboard();
                                    _useAvatar();
                                  },
                            showLoading: _isApplyingAvatar,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    const borderRadius = 12.0;
    const borderWidth = 1.5;
    final innerRadius = borderRadius - borderWidth;

    return Container(
      width: double.infinity,
      height: _uploadAreaHeight,
      decoration: BoxDecoration(
        color: AppColors.uploadBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.uploadBorder, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: _imageUrl != null
            ? _buildImagePreview(
                PetAvatarImage(url: _imageUrl, fit: BoxFit.cover),
              )
            : _localPath == null
            ? GestureDetector(
                onTap: _isBusy
                    ? null
                    : () {
                        _dismissKeyboard();
                        _showPickSourceSheet();
                      },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.photo_camera,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      tr('avatar.upload_title'),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              )
            : _buildImagePreview(
                Image.file(File(_localPath!), fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildImagePreview(Widget image) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _isBusy ? null : _viewCurrentImage,
            behavior: HitTestBehavior.opaque,
            child: image,
          ),
        ),
        if (_showGenerateLoading) _buildLoadingOverlay(),
        if (!_isBusy) ...[
          Positioned(
            left: 8,
            top: 8,
            child: GestureDetector(
              onTap: _viewCurrentImage,
              child: const _PreviewHintBadge(),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: GestureDetector(
              onTap: () {
                _dismissKeyboard();
                _showPickSourceSheet();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tr('avatar.reupload'),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      focusNode: _descriptionFocusNode,
      maxLines: 3,
      maxLength: 200,
      onChanged: (_) => setState(() {}),
      onTapOutside: (_) => _dismissKeyboard(),
      style: const TextStyle(fontSize: 13, color: Color(0xFF5C4033)),
      decoration: InputDecoration(
        hintText: tr('avatar.feature_hint'),
        hintStyle: const TextStyle(
          fontSize: 13,
          height: 1,
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.uploadBg,
        contentPadding: const EdgeInsets.all(12),
        counterStyle: const TextStyle(fontSize: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.avatarDescriptionBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.avatarDescriptionBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.avatarDescriptionBorder,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.avatarDescriptionBorder,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          const SizedBox(height: 10),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required LinearGradient gradient,
    required VoidCallback? onPressed,
    bool showLoading = false,
  }) {
    return GradientTapButton(
      onTap: onPressed,
      gradient: gradient,
      width: double.infinity,
      height: 44,
      child: showLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.avatarGenerateButtonText,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1,
                      color: AppColors.avatarGenerateButtonText,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                height: 1,
                color: AppColors.avatarGenerateButtonText,
              ),
            ),
    );
  }
}

class _PreviewHintBadge extends StatelessWidget {
  const _PreviewHintBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.zoom_in, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            tr('avatar.tap_preview'),
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
