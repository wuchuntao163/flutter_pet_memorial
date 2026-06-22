import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../router/app_routes.dart';
import '../../utils/center_tip_util.dart';
import '../../widgets/common/action_button.dart';

class BindPhoneScreen extends StatefulWidget {
  const BindPhoneScreen({super.key});

  @override
  State<BindPhoneScreen> createState() => _BindPhoneScreenState();
}

class _BindPhoneScreenState extends State<BindPhoneScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _submitting = false;
  bool _sendingCode = false;
  bool _agreedPrivacy = false;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _phoneValid =>
      RegExp(r'^1\d{10}$').hasMatch(_phoneController.text.trim());

  Future<void> _sendCode() async {
    if (!_phoneValid || _countdown > 0 || _sendingCode) return;
    if (!_agreedPrivacy) {
      showCenterTip(context, tr('bind_phone.privacy_required'));
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final res = await Api.post(
        ApiPaths.getSmsCode,
        data: {'phone': _phoneController.text.trim()},
      );
      if (!mounted) return;
      showCenterTip(
        context,
        res.msg.isNotEmpty ? res.msg : tr('bind_phone.code_sent'),
      );
      setState(() => _countdown = 60);
      _tickCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      showCenterTip(context, e.message);
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _tickCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _countdown <= 0) return;
      setState(() => _countdown--);
      if (_countdown > 0) _tickCountdown();
    });
  }

  Future<void> _bindPhone() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (!_phoneValid) {
      showCenterTip(context, tr('bind_phone.invalid_phone'));
      return;
    }
    if (code.isEmpty) {
      showCenterTip(context, tr('bind_phone.invalid_code'));
      return;
    }
    if (!_agreedPrivacy) {
      showCenterTip(context, tr('bind_phone.privacy_required'));
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await Api.post(
        ApiPaths.bindPhone,
        data: {'phone': phone, 'code': code, 'type': 1},
      );
      await AuthSessionStore.instance.applyBindPhoneResult(
        phone: phone,
        data: res.data,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await showCenterTip(
        context,
        res.msg.isNotEmpty ? res.msg : tr('bind_phone.bind_success'),
      );
      if (!mounted) return;
      context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showCenterTip(context, e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(height: 12),
              Text(
                tr('bind_phone.title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildInput(
                controller: _phoneController,
                hint: tr('bind_phone.phone_hint'),
                keyboardType: TextInputType.phone,
                maxLength: 11,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInput(
                      controller: _codeController,
                      hint: tr('bind_phone.code_hint'),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 108,
                    height: 48,
                    child: TextButton(
                      onPressed: _phoneValid && _countdown == 0 && !_sendingCode
                          ? _sendCode
                          : null,
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.bgWhite,
                        foregroundColor: AppColors.accentDarker,
                        disabledForegroundColor: AppColors.textTertiary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      child: _sendingCode
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _countdown > 0
                                  ? '${_countdown}s'
                                  : tr('bind_phone.get_code'),
                              style: const TextStyle(fontSize: 13),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPrivacyAgreement(),
              const Spacer(),
              ActionButton(
                text: _submitting
                    ? tr('bind_phone.binding')
                    : tr('bind_phone.confirm'),
                onTap: _submitting || !_agreedPrivacy ? null : _bindPhone,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyAgreement() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedPrivacy,
            onChanged: (value) =>
                setState(() => _agreedPrivacy = value ?? false),
            activeColor: AppColors.orange,
            side: const BorderSide(color: AppColors.borderLight),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(
                tr('bind_phone.privacy_prefix'),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.privacyPolicy),
                child: Text(
                  tr('bind_phone.privacy_link'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.accentDarker,
                    height: 1.4,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
          ),
          border: InputBorder.none,
          counterText: '',
          isDense: true,
        ),
      ),
    );
  }
}
