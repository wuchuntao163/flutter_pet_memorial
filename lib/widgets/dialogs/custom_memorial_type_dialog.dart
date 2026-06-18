import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../data/memorial_store.dart';
import '../../l10n/tr.dart';
import '../../services/pet_image_service.dart';
import '../../utils/center_tip_util.dart';

enum CustomTypeDialogMode { add, edit }

class CustomTypeDialogResult {
  final String title;
  final String bgColor;
  final String icon;
  final bool deleted;

  const CustomTypeDialogResult({
    required this.title,
    required this.bgColor,
    required this.icon,
    this.deleted = false,
  });

  const CustomTypeDialogResult.deleted()
      : title = '',
        bgColor = '',
        icon = '',
        deleted = true;
}

const kMemorialTypeColorPresets = [
  '#FF6B6B',
  '#FFB347',
  '#FFD93D',
  '#6BCB77',
  '#4D96FF',
  '#9B59B6',
  '#FB923C',
  '#98CBF2',
];

Future<CustomTypeDialogResult?> showCustomMemorialTypeDialog(
  BuildContext context, {
  required CustomTypeDialogMode mode,
  String initialTitle = '',
  String initialColor = '#FF6B6B',
  String initialIcon = '',
}) {
  return showDialog<CustomTypeDialogResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) => _CustomMemorialTypeDialog(
      mode: mode,
      initialTitle: initialTitle,
      initialColor: initialColor,
      initialIcon: initialIcon,
    ),
  );
}

class _CustomMemorialTypeDialog extends StatefulWidget {
  final CustomTypeDialogMode mode;
  final String initialTitle;
  final String initialColor;
  final String initialIcon;

  const _CustomMemorialTypeDialog({
    required this.mode,
    required this.initialTitle,
    required this.initialColor,
    required this.initialIcon,
  });

  @override
  State<_CustomMemorialTypeDialog> createState() =>
      _CustomMemorialTypeDialogState();
}

class _CustomMemorialTypeDialogState extends State<_CustomMemorialTypeDialog> {
  late final TextEditingController _titleController;
  late String _selectedColor;
  String _selectedIcon = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _selectedColor = _normalizeColor(widget.initialColor);
    _selectedIcon = widget.initialIcon.trim();
    MemorialStore.instance.fetchTypeIcons();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _normalizeColor(String hex) {
    final h = hex.replaceFirst('#', '').toUpperCase();
    if (h.length == 6) return '#$h';
    for (final c in kMemorialTypeColorPresets) {
      if (c.replaceFirst('#', '').toUpperCase() == h) return c;
    }
    return kMemorialTypeColorPresets.first;
  }

  List<String> get _colorOptions {
    final initial = _normalizeColor(widget.initialColor);
    final options = List<String>.from(kMemorialTypeColorPresets);
    final exists = options.any(
      (hex) => _normalizeColor(hex) == initial,
    );
    if (!exists) options.insert(0, initial);
    return options;
  }

  Color _parseColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  String _iconImageUrl(Map<String, dynamic> item) =>
      item['image']?.toString().trim() ?? '';

  void _ensureDefaultIcon(List<Map<String, dynamic>> icons) {
    if (_selectedIcon.isNotEmpty) return;
    if (icons.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedIcon.isNotEmpty) return;
      setState(() => _selectedIcon = _iconImageUrl(icons.first));
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showCenterTip(context, tr('dialogs.type_name_required'));
      return;
    }
    final icons = MemorialStore.instance.typeIconList;
    if (icons.isNotEmpty && _selectedIcon.isEmpty) {
      showCenterTip(context, tr('dialogs.type_icon_required'));
      return;
    }
    Navigator.pop(
      context,
      CustomTypeDialogResult(
        title: title,
        bgColor: _selectedColor,
        icon: _selectedIcon,
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final name = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : widget.initialTitle;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('dialogs.delete_type_title')),
        content: Text(
          '${tr('dialogs.delete_type_prefix')}$name${tr('dialogs.delete_type_suffix')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('common.delete'),
              style: const TextStyle(color: AppColors.delete),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, const CustomTypeDialogResult.deleted());
    }
  }

  Widget _buildSectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.0,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildIconGrid(List<Map<String, dynamic>> icons) {
    const crossCount = 5;
    const spacing = 10.0;
    const iconSize = 36.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: icons.map((item) {
            final url = _iconImageUrl(item);
            final selected = _selectedIcon == url;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = url),
              child: SizedBox(
                width: cellWidth,
                height: cellWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? Border.all(color: AppColors.accentDark, width: 2)
                        : Border.all(color: AppColors.borderLight),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.network(
                    PetImageService.resolveUrl(url),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.image_not_supported_outlined,
                      size: iconSize * 0.6,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildIconSection() {
    return ListenableBuilder(
      listenable: MemorialStore.instance,
      builder: (context, _) {
        final store = MemorialStore.instance;
        final icons = store.typeIconList;

        _ensureDefaultIcon(icons);

        Widget body;
        if (store.typeIconsLoading && icons.isEmpty) {
          body = const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
          );
        } else if (icons.isEmpty) {
          body = Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr('dialogs.type_icon_empty'),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          );
        } else {
          body = _buildIconGrid(icons);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(tr('dialogs.type_icon')),
            const SizedBox(height: 8),
            body,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mode == CustomTypeDialogMode.edit;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340, maxHeight: 520),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit
                          ? tr('dialogs.edit_type_title')
                          : tr('dialogs.add_type_title'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.close,
                      size: 22,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 8,
                      decoration: InputDecoration(
                        hintText: tr('dialogs.type_name_hint'),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSectionTitle(tr('dialogs.type_theme_color')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _colorOptions.map((hex) {
                        final color = _parseColor(hex);
                        final selected = _normalizeColor(_selectedColor) ==
                            _normalizeColor(hex);
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: AppColors.textPrimary,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _buildIconSection(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  if (isEdit)
                    TextButton(
                      onPressed: _confirmDelete,
                      child: Text(
                        tr('common.delete'),
                        style: const TextStyle(color: AppColors.delete),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(tr('common.cancel')),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      isEdit ? tr('common.save') : tr('common.confirm'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
