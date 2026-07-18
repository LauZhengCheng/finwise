// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : account_profile_screen.dart
// Description   : Account Profile screen — editable name and phone number,
//                 read-only email, reset password, feature links, logout
// First Written : 11-06-2026
// Edited on     : 18-06-2026
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/auth_api.dart';
import '../../services/api/notification_api.dart';
import '../../widgets/shimmer_loading.dart';
import '../main_scaffold.dart';

class AccountProfileScreen extends ConsumerStatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  ConsumerState<AccountProfileScreen> createState() =>
      _AccountProfileScreenState();
}

class _AccountProfileScreenState extends ConsumerState<AccountProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _authApi = AuthApi();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isResetting = false;
  bool _hasChanges = false;
  String? _email;
  String? _originalName;
  String? _originalPhone;
  String? _error;
  String? _successMessage;
  String? _passwordSuccessMessage;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _nameController.addListener(_checkChanges);
    _phoneController.addListener(_checkChanges);
    profileTabRefresh.addListener(_loadProfile);
  }

  @override
  void dispose() {
    profileTabRefresh.removeListener(_loadProfile);
    _nameController.dispose();
    _phoneController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _authApi.getProfile();
      if (!mounted) return;
      setState(() {
        _nameController.text = data['full_name'] ?? '';
        _phoneController.text = data['phone_number'] ?? '';
        _email = data['email'] ?? '';
        _originalName = data['full_name'] ?? '';
        _originalPhone = data['phone_number'] ?? '';
        _hasChanges = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _checkChanges() {
    final changed = _nameController.text != _originalName || _phoneController.text != _originalPhone;
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      setState(() => _error = 'Name and phone number cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await _authApi.updateProfile(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': _nameController.text.trim()}),
      );
      // Refresh auth session so name updates everywhere (dashboard greeting etc.)
      await Supabase.instance.client.auth.refreshSession();
      if (!mounted) return;
      setState(() {
        _successMessage = 'Profile updated successfully';
        _originalName = _nameController.text.trim();
        _originalPhone = _phoneController.text.trim();
        _hasChanges = false;
      });
      _messageTimer?.cancel();
      _messageTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _successMessage = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email == null) return;
    setState(() {
      _isResetting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_email!);
      if (!mounted) return;
      setState(() => _isResetting = false);
      _showOtpSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to send reset email. Try again.';
        _isResetting = false;
      });
    }
  }

  void _showOtpSheet() {
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formError = ValueNotifier<String?>(null);
    final isSubmitting = ValueNotifier<bool>(false);
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.textHint.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Change Password', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('OTP sent to $_email', style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
                ],
              )),
            ]),
            const SizedBox(height: 24),
            TextField(
              controller: otpCtrl,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, letterSpacing: 4),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Enter OTP code',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14, letterSpacing: 0),
                filled: true, fillColor: AppTheme.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: obscureNew,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'New password',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textHint, size: 20),
                suffixIcon: GestureDetector(
                  onTap: () => setSheetState(() => obscureNew = !obscureNew),
                  child: Icon(obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppTheme.textHint, size: 20)),
                filled: true, fillColor: AppTheme.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassCtrl,
              obscureText: obscureConfirm,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Confirm new password',
                hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textHint, size: 20),
                suffixIcon: GestureDetector(
                  onTap: () => setSheetState(() => obscureConfirm = !obscureConfirm),
                  child: Icon(obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppTheme.textHint, size: 20)),
                filled: true, fillColor: AppTheme.surfaceColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorderColor)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor)),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: formError,
              builder: (_, err, __) => err != null
                ? Padding(padding: const EdgeInsets.only(bottom: 8),
                    child: Text(err, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)))
                : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.glassBorderColor)),
                    child: const Center(child: Text('Cancel', style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: isSubmitting,
                  builder: (_, loading, __) => GestureDetector(
                    onTap: loading ? null : () async {
                      final otp = otpCtrl.text.trim();
                      final newPass = newPassCtrl.text;
                      final confirmPass = confirmPassCtrl.text;

                      if (otp.isEmpty) { formError.value = 'Enter the OTP code'; return; }
                      if (newPass.length < 6) { formError.value = 'Password must be at least 6 characters'; return; }
                      if (newPass != confirmPass) { formError.value = 'Passwords do not match'; return; }
                      formError.value = null;
                      isSubmitting.value = true;

                      try {
                        await Supabase.instance.client.auth.verifyOTP(
                          email: _email!,
                          token: otp,
                          type: OtpType.recovery,
                        );
                      } catch (e) {
                        final msg = e.toString().toLowerCase();
                        formError.value = msg.contains('expired')
                          ? 'OTP has expired. Tap Cancel and request a new one.'
                          : 'Invalid OTP code. Check your email and try again.';
                        isSubmitting.value = false;
                        return;
                      }

                      try {
                        await Supabase.instance.client.auth.updateUser(
                          UserAttributes(password: newPass),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          setState(() => _passwordSuccessMessage = 'Password changed successfully');
                          _messageTimer?.cancel();
                          _messageTimer = Timer(const Duration(seconds: 5), () {
                            if (mounted) setState(() => _passwordSuccessMessage = null);
                          });
                        }
                      } catch (e) {
                        formError.value = 'Failed to update password. Try a different password.';
                        isSubmitting.value = false;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: loading ? null : AppTheme.goldGradient,
                        color: loading ? AppTheme.textHint.withValues(alpha: 0.3) : null,
                        borderRadius: BorderRadius.circular(14)),
                      child: Center(child: loading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textSecondary))
                        : const Text('Change Password', style: TextStyle(
                            color: Color(0xFF0A0800), fontSize: 14, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ).then((_) {
      otpCtrl.dispose();
      newPassCtrl.dispose();
      confirmPassCtrl.dispose();
      formError.dispose();
      isSubmitting.dispose();
    });
  }

  Future<void> _logout() async {
    try {
      await NotificationApi().clearToken();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Signing out...'),
        backgroundColor: AppTheme.textHint,
        duration: Duration(milliseconds: 500),
      ));
    }
    await Future.delayed(const Duration(milliseconds: 400));
    await ref.read(authProvider.notifier).signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: _isLoading
              ? const Padding(padding: EdgeInsets.all(16), child: SkeletonTransactionList(count: 5))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 108),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Page title ────────────────────────────
                      const Text(
                        'Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Avatar ────────────────────────────────
                      Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _nameController.text.isNotEmpty
                                ? _nameController.text[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0A0800),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Profile Details ───────────────────────
                    const _SectionLabel('Profile Details'),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        _EditableField(
                          label: 'Full Name',
                          controller: _nameController,
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.name,
                        ),
                        _Divider(),
                        _ReadOnlyField(
                          label: 'Email',
                          value: _email ?? '',
                          icon: Icons.email_outlined,
                        ),
                        _Divider(),
                        _EditableField(
                          label: 'Phone Number',
                          controller: _phoneController,
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Feedback message
                    if (_successMessage != null)
                      _FeedbackBanner(
                          message: _successMessage!, isError: false),
                    if (_error != null)
                      _FeedbackBanner(message: _error!, isError: true),
                    if (_successMessage != null || _error != null)
                      const SizedBox(height: 12),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_isSaving || !_hasChanges) ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasChanges ? AppTheme.primaryColor : AppTheme.surfaceColor,
                          foregroundColor: _hasChanges ? const Color(0xFF0A0800) : AppTheme.textHint,
                          disabledBackgroundColor: AppTheme.surfaceColor,
                          disabledForegroundColor: AppTheme.textHint,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0A0800),
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Features ──────────────────────────────
                    const _SectionLabel('Features'),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        _ActionRow(
                          icon: Icons.emoji_events_rounded,
                          label: 'Achievements',
                          sublabel: 'Your unlocked financial milestones',
                          onTap: () => context.push('/achievements'),
                        ),
                        _Divider(),
                        _ActionRow(
                          icon: Icons.calculate_rounded,
                          label: 'Loan Calculator',
                          sublabel: 'EMI & amortisation schedule',
                          onTap: () => context.push('/discover/loan-calc'),
                        ),
                        _Divider(),
                        _ActionRow(
                          icon: Icons.speed_rounded,
                          label: 'Spending Forecast',
                          sublabel: 'Vault runway & velocity',
                          onTap: () => context.push('/discover/forecast'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Security ──────────────────────────────
                    const _SectionLabel('Security'),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        _ActionRow(
                          icon: Icons.lock_reset_rounded,
                          label: 'Change Password',
                          sublabel: 'Verify via email OTP',
                          isLoading: _isResetting,
                          onTap: _resetPassword,
                        ),
                      ],
                    ),
                    if (_passwordSuccessMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                          const SizedBox(width: 8),
                          Text(_passwordSuccessMessage!, style: const TextStyle(
                            color: Color(0xFF059669), fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // ── Session ───────────────────────────────
                    const _SectionLabel('Session'),
                    const SizedBox(height: 12),
                    _buildCard(
                      children: [
                        _ActionRow(
                          icon: Icons.logout_rounded,
                          label: 'Log Out',
                          sublabel: 'Sign out of your account',
                          isDestructive: true,
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Column(children: children),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

// ── Thin divider ──────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.glassBorderColor,
      indent: 52,
    );
  }
}

// ── Editable field row ────────────────────────────────────────────────────
class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;

  const _EditableField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Read-only field row ───────────────────────────────────────────────────
class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'Read only',
            style: TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}

// ── Action row (reset password / logout) ─────────────────────────────────
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool isDestructive;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.isDestructive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.errorColor : AppTheme.primaryColor;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}

// ── Feedback banner ───────────────────────────────────────────────────────
class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppTheme.errorColor : AppTheme.primaryColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: color),
      ),
    );
  }
}
