import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/api.dart';
import '../../config/colors.dart';
import '../../config/fonts.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../data/memorial_store.dart';
import '../../models/memorial_day.dart';
import '../../services/language_service.dart';
import '../../widgets/dialogs/custom_memorial_type_dialog.dart';
import '../../utils/date_format_util.dart';
import '../../utils/lunar_calendar_util.dart';
import '../../widgets/dialogs/lunar_date_picker_dialog.dart';
import '../../widgets/dialogs/solar_date_picker_dialog.dart';
import '../../widgets/dialogs/repeat_frequency_dialog.dart';
import '../../widgets/common/gradient_tap_button.dart';
import '../../widgets/common/memorial_type_info.dart';
import '../../l10n/tr.dart';
import '../../widgets/common/pet_profile_decor_image.dart';
import '../../utils/center_tip_util.dart';

class AddMemorialScreen extends StatefulWidget {
  final MemorialDay? editingDay;

  const AddMemorialScreen({super.key, this.editingDay});

  bool get isEditing => editingDay != null;

  @override
  State<AddMemorialScreen> createState() => _AddMemorialScreenState();
}

class _AddMemorialScreenState extends State<AddMemorialScreen> {
  int? _selectedTypeId;
  late CalendarType _calendarType;
  late bool _isLunarLeapMonth;
  late RepeatFrequency _repeatFrequency;
  DateTime? _selectedDate;
  late bool _isPinned;
  late bool _hasReminder;

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final day = widget.editingDay;
    if (day != null) {
      _nameController.text = day.title;
      _selectedTypeId = day.typeId;
      _calendarType = day.calendarType;
      _isLunarLeapMonth = day.isLunarLeapMonth;
      _repeatFrequency = day.repeatFrequency;
      _selectedDate = day.date;
      _isPinned = day.isPinned;
      _hasReminder = day.hasReminder;
    } else {
      _calendarType = CalendarType.solar;
      _isLunarLeapMonth = false;
      _repeatFrequency = RepeatFrequency.none;
      _isPinned = false;
      _hasReminder = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (MemorialStore.instance.typeList.isEmpty) {
          await MemorialStore.instance.fetchTypes();
        }
        if (!mounted || _selectedTypeId != null) return;
        final types = MemorialStore.instance.pickerTypeList;
        if (types.isNotEmpty) {
          setState(() => _selectedTypeId = _typeId(types.first));
        }
      });
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _goBack() {
    _unfocus();
    context.pop();
  }

  Future<void> _pickDate() async {
    _unfocus();
    if (_calendarType == CalendarType.lunar) {
      await _pickLunarDate();
      return;
    }

    final picked = await showSolarDatePickerDialog(
      context,
      initial: _selectedDate,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _isLunarLeapMonth = false;
      });
    }
  }

  Future<void> _pickLunarDate() async {
    LunarDateSelection? initial;
    if (_selectedDate != null) {
      initial = LunarDateSelection(
        year: _selectedDate!.year,
        month: _selectedDate!.month,
        day: _selectedDate!.day,
        isLeapMonth: _isLunarLeapMonth,
      );
    }
    final picked = await showLunarDatePickerDialog(
      context,
      initial: initial,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked.toDateTime();
        _isLunarLeapMonth = picked.isLeapMonth;
      });
    }
  }

  void _setCalendarType(CalendarType type) {
    if (type == _calendarType) return;
    _unfocus();

    if (_selectedDate != null) {
      if (type == CalendarType.lunar) {
        final lunar = LunarCalendarUtil.solarToLunar(_selectedDate!);
        _selectedDate = DateTime(lunar.year, lunar.month, lunar.day);
        _isLunarLeapMonth = lunar.isLeapMonth;
      } else {
        _selectedDate = LunarCalendarUtil.lunarToSolar(
          year: _selectedDate!.year,
          month: _selectedDate!.month,
          day: _selectedDate!.day,
          isLeapMonth: _isLunarLeapMonth,
        );
        _isLunarLeapMonth = false;
      }
    }

    setState(() => _calendarType = type);
  }

  String _dateDisplayText() {
    if (_selectedDate == null) return tr('memorial.date_placeholder');
    if (_calendarType == CalendarType.lunar) {
      return LunarCalendarUtil.formatLunar(
        year: _selectedDate!.year,
        month: _selectedDate!.month,
        day: _selectedDate!.day,
        isLeapMonth: _isLunarLeapMonth,
      );
    }
    return DateFormatUtil.formatSolarYmd(
      year: _selectedDate!.year,
      month: _selectedDate!.month,
      day: _selectedDate!.day,
    );
  }

  Future<void> _pickRepeatFrequency() async {
    _unfocus();
    final result = await showRepeatFrequencyDialog(
      context,
      initial: _repeatFrequency,
    );
    if (result != null) {
      setState(() => _repeatFrequency = result);
    }
  }

  void _submit() async {
    _unfocus();
    final title = _nameController.text.trim();
    if (title.isEmpty) {
      _showTip(tr('memorial.name_required'));
      return;
    }
    if (_selectedDate == null) {
      _showTip(tr('memorial.date_required'));
      return;
    }
    if (_selectedTypeId == null) {
      _showTip(tr('memorial.type_required'));
      return;
    }

    if (widget.isEditing) {
      try {
        final msg = await MemorialStore.instance.editAnniversary(
          anniversaryId: widget.editingDay!.id,
          name: title,
          date: _selectedDate!,
          typeId: _selectedTypeId!,
          dateType: _calendarType == CalendarType.lunar ? 2 : 1,
          repeatFrequency: MemorialDay.repeatToApi(_repeatFrequency),
          isTop: _isPinned ? 1 : 0,
          isRemind: _hasReminder ? 1 : 0,
          isLunarLeapMonth: _isLunarLeapMonth,
        );
        if (!mounted) return;
        await showCenterTip(context, msg);
        if (!mounted) return;
        context.pop();
      } on ApiException catch (e) {
        _showTip(e.message);
      }
      return;
    }

    try {
      final msg = await MemorialStore.instance.addAnniversary(
        name: title,
        date: _selectedDate!,
        typeId: _selectedTypeId!,
        dateType: _calendarType == CalendarType.lunar ? 2 : 1,
        repeatFrequency: MemorialDay.repeatToApi(_repeatFrequency),
        isTop: _isPinned ? 1 : 0,
        isRemind: _hasReminder ? 1 : 0,
        isLunarLeapMonth: _isLunarLeapMonth,
      );
      if (!mounted) return;
      await showCenterTip(context, msg);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      _showTip(e.message);
    }
  }

  void _showTip(String message) {
    showCenterTip(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle =
        widget.isEditing ? tr('memorial.edit_title') : tr('memorial.add_title');
    final submitLabel =
        widget.isEditing ? tr('memorial.save') : tr('memorial.add');

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _unfocus();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          left: false,
          right: false,
          bottom: true,
          child: GestureDetector(
            onTap: _unfocus,
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: const EdgeInsets.only(top: AppLayout.memorialAddTopPadding),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPageHeader(pageTitle),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentDark.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNameField(),
                          const SizedBox(height: 16),
                          _buildDateField(),
                          const SizedBox(height: 16),
                          _buildTypeSelector(),
                          const SizedBox(height: 16),
                          _buildRepeatField(),
                          const SizedBox(height: 16),
                          _buildOptions(),
                          const SizedBox(height: 16),
                          _buildSubmitButton(submitLabel),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader(String title) {
    return ListenableBuilder(
      listenable: AppCacheStore.instance,
      builder: (context, _) {
        final decorUrl = AppCacheStore.instance.petProfileOne;
        final hasDecor = decorUrl != null;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 0, hasDecor ? 100 : 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _goBack,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_back_ios_new,
                          size: 14,
                          color: AppColors.accentDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tr('memorial.back'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // const SizedBox(height: 12),
                  SizedBox(
                    height: AppLayout.memorialAddTitleHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentDark,
                          // height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasDecor)
              Positioned(
                top: 0,
                right: 8,
                child: PetProfileDecorImage(url: decorUrl),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.0,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(Icons.edit_outlined, tr('memorial.name_label')),
        const SizedBox(height: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgInput,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _unfocus(),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: tr('memorial.name_hint'),
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.textPlaceholder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final dateText = _dateDisplayText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(
          Icons.calendar_today_outlined,
          tr('memorial.date_label_full'),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickDate,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      dateText,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontSize: 14,
                        color: _selectedDate == null
                            ? AppColors.textTertiary
                            : AppColors.textPrimary,
                        fontWeight: _selectedDate == null
                            ? FontWeight.w500
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppColors.bgButtonSecondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _buildCalendarToggle(
                        label: tr('memorial.solar'),
                        isSelected: _calendarType == CalendarType.solar,
                        onTap: () => _setCalendarType(CalendarType.solar),
                      ),
                      _buildCalendarToggle(
                        label: tr('memorial.lunar'),
                        isSelected: _calendarType == CalendarType.lunar,
                        onTap: () => _setCalendarType(CalendarType.lunar),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : null,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.family,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color:
                isSelected ? const Color(0xFF785C35) : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  int? _typeId(Map type) {
    final id = type['id'];
    return id is int ? id : int.tryParse('$id');
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.accent;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  Future<void> _addCustomType() async {
    _unfocus();
    final otherType = MemorialStore.instance.otherType;
    final result = await showCustomMemorialTypeDialog(
      context,
      mode: CustomTypeDialogMode.add,
      initialColor: otherType?['bg_color']?.toString() ?? '#FF6B6B',
    );
    if (result == null || !mounted) return;

    try {
      final res = await MemorialStore.instance.addCustomType(
        title: result.title,
        bgColor: result.bgColor,
        icon: result.icon,
      );
      if (!mounted) return;
      await showCenterTip(context, res.msg);
      if (res.typeId > 0) {
        setState(() => _selectedTypeId = res.typeId);
      }
    } on ApiException catch (e) {
      _showTip(e.message);
    }
  }

  Future<void> _editCustomType(Map<String, dynamic> type) async {
    _unfocus();
    final id = _typeId(type);
    if (id == null) return;

    final result = await showCustomMemorialTypeDialog(
      context,
      mode: CustomTypeDialogMode.edit,
      initialTitle: type['title']?.toString() ?? '',
      initialColor: type['bg_color']?.toString() ?? '#FF6B6B',
      initialIcon: type['icon']?.toString() ?? '',
    );
    if (result == null || !mounted) return;

    try {
      if (result.deleted) {
        final msg = await MemorialStore.instance.deleteCustomType(id);
        _showTip(msg);
        if (_selectedTypeId == id) {
          final types = MemorialStore.instance.pickerTypeList;
          setState(() {
            _selectedTypeId =
                types.isNotEmpty ? _typeId(types.first) : null;
          });
        }
        return;
      }

      final msg = await MemorialStore.instance.editCustomType(
        typeId: id,
        title: result.title,
        bgColor: result.bgColor,
        icon: result.icon,
      );
      await showCenterTip(context, msg);
      if (_selectedTypeId == id) setState(() {});
    } on ApiException catch (e) {
      _showTip(e.message);
    }
  }

  Widget _buildTypeSelector() {
    return ListenableBuilder(
      listenable: Listenable.merge([
        MemorialStore.instance,
        LanguageService.instance,
      ]),
      builder: (context, _) {
        final types = MemorialStore.instance.pickerTypeList;
        if (types.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel(Icons.category_outlined, tr('memorial.type_label')),
              const SizedBox(height: 8),
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }

        const crossCount = 3;
        const spacing = 8.0;
        const aspectRatio = 1.15;
        final rows = (types.length / crossCount).ceil();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(Icons.category_outlined, tr('memorial.type_label')),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final cellWidth =
                    (constraints.maxWidth - spacing * (crossCount - 1)) /
                        crossCount;
                final cellHeight = cellWidth / aspectRatio;
                final height =
                    cellHeight * rows + spacing * (rows - 1);

                return SizedBox(
                  height: height,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                      childAspectRatio: aspectRatio,
                    ),
                    itemCount: types.length,
                    itemBuilder: (context, index) {
                      final type = types[index];
                      final id = _typeId(type);
                      final isOther = MemorialStore.isOtherType(type);
                      final isCustom = MemorialStore.isCustomType(type);
                      final isSelected = !isOther && _selectedTypeId == id;
                      final color = _parseColor(type['bg_color']?.toString());
                      final title = MemorialStore.localizedTypeTitle(type);

                      return Stack(
                        clipBehavior: Clip.none,
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () {
                              _unfocus();
                              if (isOther) {
                                _addCustomType();
                                return;
                              }
                              setState(() => _selectedTypeId = id);
                            },
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.35)
                                    : AppColors.bgButtonSecondary,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: color, width: 2)
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  MemorialTypeInfo.typeIcon(
                                    type,
                                    size: 26,
                                    color: isSelected
                                        ? color
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? color
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isCustom)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _editCustomType(type),
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: AppColors.bgWhite
                                        .withValues(alpha: 0.95),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentDark
                                            .withValues(alpha: 0.12),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRepeatField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(Icons.repeat, tr('memorial.repeat_label')),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickRepeatFrequency,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.repeat, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  _repeatFrequency.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptions() {
    return Column(
      children: [
        _buildOptionRow(
          imageAsset: 'assets/images/image_47.png',
          title: tr('memorial.pin_title'),
          subtitle: tr('memorial.pin_subtitle'),
          value: _isPinned,
          onChanged: (v) {
            _unfocus();
            setState(() => _isPinned = v);
          },
        ),
        const SizedBox(height: 8),
        _buildOptionRow(
          imageAsset: 'assets/images/image_89.png',
          title: tr('memorial.reminder_title'),
          subtitle: tr('memorial.reminder_subtitle'),
          value: _hasReminder,
          onChanged: (v) {
            _unfocus();
            setState(() => _hasReminder = v);
          },
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required String imageAsset,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => onChanged(!value),
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: value ? AppColors.accentDark : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? Colors.transparent : AppColors.borderPlaceholder,
                width: 2,
              ),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    imageAsset,
                    height: 19,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textPlaceholder,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String label) {
    return GradientTapButton(
      onTap: _submit,
      gradient: AppColors.avatarActionGradient,
      borderRadius: 16,
      height: 48,
      width: double.infinity,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          height: 1,
          fontWeight: FontWeight.bold,
          color: AppColors.avatarGenerateButtonText,
        ),
      ),
    );
  }
}
