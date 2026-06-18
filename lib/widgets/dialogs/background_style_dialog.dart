import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../data/background_store.dart';
import '../../l10n/tr.dart';
import '../../models/background_style_config.dart';
import '../../models/memorial_day.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/pet_image_picker.dart';
import '../../widgets/common/memorial_type_info.dart';
import 'style_picker_dialog.dart';

class BackgroundStyleDialog extends StatefulWidget {
  final MemorialDay memorialDay;
  final String initialStyleId;
  final ValueChanged<BackgroundStyleSelection>? onConfirm;

  const BackgroundStyleDialog({
    super.key,
    required this.memorialDay,
    this.initialStyleId = '',
    this.onConfirm,
  });

  @override
  State<BackgroundStyleDialog> createState() => _BackgroundStyleDialogState();
}

class _BackgroundStyleDialogState extends State<BackgroundStyleDialog> {
  late String _selectedStyleId;
  bool _uploading = false;

  MemorialDay get _day => widget.memorialDay;

  static const _tabBorder = Color(0xFFE5E7EB);
  static const _tabBarBg = Color(0xFFFAFAFA);
  static const _gridAreaBg = AppColors.bgWhite;
  static const _tileRadius = 8.0;
  static const _categoryPillWidth = 75.0;

  @override
  void initState() {
    super.initState();
    _selectedStyleId = widget.initialStyleId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final customTab =
          _day.backgroundTab.trim() == BackgroundStore.customTabKey;
      await BackgroundStore.instance.ensureReady(customTab: customTab);
      if (!mounted) return;
      _syncSelection();
    });
  }

  void _syncSelection() {
    final effective = BackgroundStyleConfig.effectiveStyleId(
      _selectedStyleId,
      day: _day,
    );
    if (effective != _selectedStyleId) {
      setState(() => _selectedStyleId = effective);
    }
  }

  int? _categoryId(Map<String, dynamic> category) {
    final id = category['id'] ?? category['category_id'];
    return id is int ? id : int.tryParse('$id');
  }

  bool _isLocked(Map<String, dynamic> item) {
    final lock = item['is_lock'] ?? item['need_vip'] ?? item['is_vip'];
    if (lock == 1 || lock == true) return true;
    return false;
  }

  Future<void> _uploadCustomBackground() async {
    if (_uploading) return;
    final path = await PetImagePicker.pickFromGallery(context);
    if (path == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final created = await BackgroundStore.instance.uploadCustomBackground(
        localPath: path,
        name: tr('style.custom_background'),
      );
      if (!mounted) return;
      if (created != null) {
        setState(() => _selectedStyleId = '${created['id']}');
      } else {
        _showMessage(tr('style.upload_background_fail'));
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('${tr('style.upload_background_fail')}$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['id']}');
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('style.delete_background')),
        content: Text(tr('style.delete_background_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('common.confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await BackgroundStore.instance.deleteBackground(id);
    if (!mounted) return;
    if (!ok) {
      _showMessage(tr('style.delete_background_fail'));
      return;
    }
    if (_selectedStyleId == '$id') {
      setState(() {
        _selectedStyleId = BackgroundStyleConfig.typeColorStyleId;
      });
    }
  }

  void _showMessage(String message) {
    showCenterTip(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BackgroundStore.instance,
      builder: (context, _) {
        final store = BackgroundStore.instance;
        return StylePickerDialog(
          title: tr('dialogs.background_picker'),
          fullWidthTop: _buildCategorySection(store),
          bodyPadding: EdgeInsets.zero,
          onConfirm: () {
            if (_selectedStyleId.isEmpty) return;
            final item =
                BackgroundStyleConfig.itemFor(_selectedStyleId, _day);
            widget.onConfirm?.call(
              BackgroundStyleSelection(
                styleId: _selectedStyleId,
                categoryId: store.isCustomTab
                    ? BackgroundStore.customTabKey
                    : item?['category_id']?.toString() ??
                        store.selectedCategoryId?.toString(),
              ),
            );
          },
          body: _buildGridSection(store),
        );
      },
    );
  }

  Widget _buildCategorySection(BackgroundStore store) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: _tabBarBg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _buildCategoryBar(store),
        ),
        const Divider(height: 1, thickness: 1, color: _tabBorder),
      ],
    );
  }

  Widget _buildCategoryBar(BackgroundStore store) {
    final tabs = <({String label, bool selected, VoidCallback? onTap})>[
      for (final category in store.categories)
        (
          label: category['name']?.toString() ?? '',
          selected: !store.isCustomTab &&
              store.selectedCategoryId == _categoryId(category),
          onTap: () {
            final id = _categoryId(category);
            if (id != null) BackgroundStore.instance.selectCategory(id);
          },
        ),
      (
        label: tr('memorial_type.custom'),
        selected: store.isCustomTab,
        onTap: () => BackgroundStore.instance.selectCustomTab(),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            SizedBox(
              width: _categoryPillWidth,
              child: _buildCategoryPill(
                label: tabs[i].label,
                selected: tabs[i].selected,
                onTap: tabs[i].onTap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.modalHeader : AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: _tabBorder, width: 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.bgWhite : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildGridSection(BackgroundStore store) {
    final showSpinner = (store.categoriesLoading && store.categories.isEmpty) ||
        (store.listLoading && store.items.isEmpty);

    const crossCount = 2;
    const spacing = 10.0;
    const maxRows = 2;
    const delegate = StylePickerDialog.numberStyleGridDelegate;
    final aspectRatio = delegate.childAspectRatio;

    final backgrounds = store.items;
    final showUpload = store.isCustomTab;
    final gridItems = <Map<String, dynamic>>[
      if (store.isFirstCategorySelected)
        BackgroundStyleConfig.typeColorItem(_day),
      ...backgrounds,
    ];
    final totalSlots = gridItems.length + (showUpload ? 1 : 0);
    final rows =
        totalSlots == 0 ? 0 : (totalSlots / crossCount).ceil();
    final visibleRows = rows > maxRows ? maxRows : rows;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth - 32;
        final cellWidth =
            (contentWidth - spacing * (crossCount - 1)) / crossCount;
        final cellHeight = cellWidth / aspectRatio;
        final gridHeight = visibleRows == 0
            ? 0.0
            : cellHeight * visibleRows + spacing * (visibleRows - 1);

        return Container(
          width: double.infinity,
          color: _gridAreaBg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            height: gridHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!showSpinner && totalSlots > 0)
                  GridView.builder(
                    physics: rows > maxRows
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    gridDelegate: delegate.copyWith(
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                    ),
                    itemCount: totalSlots,
                    itemBuilder: (context, index) {
                      if (showUpload && index == totalSlots - 1) {
                        return _buildUploadTile();
                      }

                      final item = gridItems[index];
                      final id = '${item['id']}';
                      final isSelected = _selectedStyleId == id;
                      final isLocal = item['is_local'] == 1;
                      final canDelete = store.isCustomTab &&
                          !isLocal &&
                          BackgroundStore.isUserOwned(item);

                      return _buildBackgroundTile(
                        isSelected: isSelected,
                        showLock: !isLocal && _isLocked(item),
                        onTap: () => setState(() => _selectedStyleId = id),
                        onLongPress:
                            canDelete ? () => _confirmDelete(item) : null,
                        child: isLocal
                            ? Container(
                                color: MemorialTypeInfo.daysBackground(_day),
                              )
                            : _networkImage(item['image']?.toString() ?? ''),
                      );
                    },
                  ),
                if (showSpinner)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundTile({
    required bool isSelected,
    required bool showLock,
    required VoidCallback onTap,
    required Widget child,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_tileRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_tileRadius),
                border: Border.all(
                  color: isSelected
                      ? AppColors.modalHeader
                      : const Color(0xFFF3F4F6),
                  width: 2,
                ),
              ),
            ),
            if (showLock)
              Positioned(
                right: 6,
                bottom: 6,
                child: Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: AppColors.modalHeader.withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTile() {
    return _buildBackgroundTile(
      isSelected: false,
      showLock: false,
      onTap: _uploading ? () {} : _uploadCustomBackground,
      child: Container(
        color: AppColors.bgInput,
        alignment: Alignment.center,
        child: _uploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: AppColors.textTertiary.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('style.upload_background'),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _networkImage(String image) {
    if (image.isEmpty) return _placeholder();
    return Image.network(
      image,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.bgWhite,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 28,
        color: AppColors.textTertiary.withValues(alpha: 0.6),
      ),
    );
  }
}

extension on SliverGridDelegateWithFixedCrossAxisCount {
  SliverGridDelegateWithFixedCrossAxisCount copyWith({
    int? crossAxisCount,
    double? mainAxisSpacing,
    double? crossAxisSpacing,
    double? childAspectRatio,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount ?? this.crossAxisCount,
      mainAxisSpacing: mainAxisSpacing ?? this.mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing ?? this.crossAxisSpacing,
      childAspectRatio: childAspectRatio ?? this.childAspectRatio,
    );
  }
}
