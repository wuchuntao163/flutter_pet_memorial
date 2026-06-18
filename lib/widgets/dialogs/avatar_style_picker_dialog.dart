import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../config/colors.dart';
import '../../data/avatar_style_store.dart';
import '../../l10n/tr.dart';
import '../../utils/center_tip_util.dart';
import '../common/gradient_tap_button.dart';
import '../../services/pet_image_service.dart';
import '../common/pet_avatar_image.dart';

const _imageShadow = [
  BoxShadow(color: Color(0x22894E45), blurRadius: 7, offset: Offset(0.5, 0)),
  BoxShadow(color: Color(0x22894E45), blurRadius: 7, offset: Offset(-0.5, 0)),
  BoxShadow(color: Color(0x22894E45), blurRadius: 7, offset: Offset(0, 0.5)),
  BoxShadow(color: Color(0x22894E45), blurRadius: 7, offset: Offset(0, -0.5)),
];

const _styleItemRadius = 20.0;

class AvatarStylePickerResult {
  final String? imageUrl;
  final String? selectedStyleId;
  final String? selectedStyleName;

  const AvatarStylePickerResult({
    this.imageUrl,
    this.selectedStyleId,
    this.selectedStyleName,
  });

  bool get isGenerated => imageUrl != null;
}

Future<AvatarStylePickerResult?> showAvatarStylePickerDialog(
  BuildContext context, {
  required String description,
  required String imageUrl,
  String? initialSelectedStyleId,
}) {
  return showDialog<AvatarStylePickerResult>(
    context: context,
    builder: (_) => AvatarStylePickerDialog(
      description: description,
      imageUrl: imageUrl,
      initialSelectedStyleId: initialSelectedStyleId,
    ),
  );
}

class AvatarStylePickerDialog extends StatefulWidget {
  final String description;
  final String imageUrl;
  final String? initialSelectedStyleId;

  const AvatarStylePickerDialog({
    super.key,
    required this.description,
    required this.imageUrl,
    this.initialSelectedStyleId,
  });

  @override
  State<AvatarStylePickerDialog> createState() =>
      _AvatarStylePickerDialogState();
}

class _AvatarStylePickerDialogState extends State<AvatarStylePickerDialog> {
  List<AvatarGenerationStyle> _styles = const [];
  String? _selectedId;
  bool _loadingStyles = true;
  bool _isGenerating = false;
  String _statusText = '';
  int _generateGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadStyles();
  }

  Future<void> _loadStyles() async {
    try {
      final styles = await AvatarStyleStore.fetchStyles();
      if (!mounted) return;
      setState(() {
        _styles = styles;
        _selectedId = _resolveInitialStyleId(styles);
        _loadingStyles = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingStyles = false);
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStyles = false);
      _showMessage('$e');
    }
  }

  String? _resolveInitialStyleId(List<AvatarGenerationStyle> styles) {
    if (styles.isEmpty) return null;
    final initialId = widget.initialSelectedStyleId;
    if (initialId != null && styles.any((style) => style.id == initialId)) {
      return initialId;
    }
    return styles.first.id;
  }

  AvatarGenerationStyle? get _selectedStyle {
    final selectedId = _selectedId;
    if (selectedId == null) return null;
    for (final style in _styles) {
      if (style.id == selectedId) return style;
    }
    return null;
  }

  AvatarStylePickerResult _buildSelectionResult() {
    final style = _selectedStyle;
    return AvatarStylePickerResult(
      selectedStyleId: style?.id,
      selectedStyleName: style?.name,
    );
  }

  void _onBack() {
    if (_isGenerating) return;
    Navigator.of(context).pop(_buildSelectionResult());
  }

  Future<void> _onNext() async {
    if (_isGenerating) return;

    final generation = ++_generateGeneration;
    setState(() {
      _isGenerating = true;
      _statusText = tr('avatar.generating');
    });

    try {
      final style = _selectedStyle;
      final generated = await PetImageService.generatePetImage(
        description: widget.description,
        imageUrl: widget.imageUrl,
        styleId: style?.id,
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
      Navigator.of(context).pop(
        AvatarStylePickerResult(
          imageUrl: displayUrl,
          selectedStyleId: style?.id,
          selectedStyleName: style?.name,
        ),
      );
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

  void _showMessage(String text) {
    showCenterTip(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.of(context).size.height * 0.82;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: BoxConstraints(maxWidth: 340, maxHeight: maxDialogHeight),
        decoration: BoxDecoration(
          color: AppColors.bgPrimary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton(
                        onPressed: _isGenerating ? null : _onBack,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_ios_new,
                              size: 14,
                              color: Color(0xFF5C4033),
                            ),
                            Transform.translate(
                              offset: const Offset(0, 0),
                              child: Text(
                                tr('common.back'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF5C4033),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          tr('avatar.style_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5C4033),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 18),
                          Text(
                            tr('avatar.style_subtitle'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF5C4033),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr('avatar.style_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF5C4033),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: _loadingStyles
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : _styles.isEmpty
                                ? Center(
                                    child: Text(
                                      tr('avatar.style_empty'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    itemCount: _styles.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 7,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 0.85,
                                        ),
                                    itemBuilder: (context, index) {
                                      final style = _styles[index];
                                      return AvatarStyleGridItem(
                                        style: style,
                                        selected: style.id == _selectedId,
                                        onTap: _isGenerating
                                            ? null
                                            : () => setState(
                                                () => _selectedId = style.id,
                                              ),
                                      );
                                    },
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                            child: Center(child: _buildNextButton()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isGenerating) _buildGeneratingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return GradientTapButton(
      onTap: _isGenerating || _loadingStyles || _styles.isEmpty
          ? null
          : _onNext,
      gradient: AppColors.avatarGenerateGradient,
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 11),
      child: Text(
        tr('avatar.style_next'),
        style: const TextStyle(
          fontSize: 15,
          height: 1,
          color: AppColors.avatarGenerateButtonText,
        ),
      ),
    );
  }

  Widget _buildGeneratingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.bgWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
              const SizedBox(height: 14),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5C4033),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AvatarStyleGridItem extends StatelessWidget {
  final AvatarGenerationStyle style;
  final bool selected;
  final VoidCallback? onTap;

  const AvatarStyleGridItem({super.key, 
    required this.style,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_styleItemRadius),
                        color: AppColors.bgWhite,
                        boxShadow: _imageShadow,
                        border: Border.all(
                          color: selected
                              ? AppColors.avatarDescriptionBorder
                              : AppColors.borderMedium,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          selected
                              ? _styleItemRadius - 2
                              : _styleItemRadius - 1,
                        ),
                        child: _buildPreview(),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.avatarGradientEnd,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            style.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF5C4033),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final asset = style.imageAsset;
    if (asset != null && asset.isNotEmpty) {
      return Image.asset(asset, fit: BoxFit.cover);
    }
    final url = style.imageUrl;
    if (url != null && url.isNotEmpty) {
      return PetAvatarImage(url: url, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: AppColors.uploadBg,
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }
}
