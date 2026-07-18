// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : protection_screen.dart
// Description   : Protection planning — emergency fund analysis +
//                 AI-personalised insurance recommendations from Aion.
// First Written : 17-06-2026
// Edited on     : 21-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../config/app_theme.dart';
import '../../models/vault_model.dart';
import '../../providers/vault_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../services/api/finance_api.dart';
import '../../widgets/shimmer_loading.dart';

class ProtectionScreen extends ConsumerStatefulWidget {
  const ProtectionScreen({super.key});

  @override
  ConsumerState<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends ConsumerState<ProtectionScreen> {
  final _fmt = NumberFormat.currency(locale: 'ms_MY', symbol: 'RM ', decimalDigits: 2);

  List<Map<String, dynamic>> _recommendations = [];
  bool _loadingRecs = true;
  Map<String, dynamic> _insurance = {};
  bool _loadingInsurance = true;

  static const _insuranceLabels = {
    'medical_health': 'Medical & Health Insurance',
    'life_takaful': 'Life Insurance / Takaful',
    'personal_accident': 'Personal Accident Insurance',
    'motor_vehicle': 'Motor / Vehicle Insurance',
    'critical_illness': 'Critical Illness Coverage',
  };

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadInsurance();
  }

  Future<void> _loadInsurance() async {
    try {
      final data = await FinanceApi().getInsuranceCoverage();
      if (mounted) setState(() { _insurance = data; _loadingInsurance = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingInsurance = false);
    }
  }

  Future<void> _toggleInsurance(String key, bool value) async {
    setState(() => _insurance[key] = value);
    try {
      final coverage = <String, bool>{};
      for (final k in _insuranceLabels.keys) {
        coverage[k] = _insurance[k] == true;
      }
      coverage[key] = value;
      await FinanceApi().updateInsuranceCoverage(coverage);

      // Refresh Aion's recommendations with latest insurance data
      setState(() => _loadingRecs = true);
      _loadRecommendations();
    } catch (_) {}
  }

  Future<void> _loadRecommendations() async {
    try {
      final response = await FinanceApi().getProtection();
      if (mounted) {
        setState(() {
          _recommendations = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _loadingRecs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecs = false);
    }
  }

  VaultModel? _findEmergency(List<VaultModel> vaults) {
    try {
      return vaults.firstWhere((v) => v.categoryKey.contains('emergency'));
    } catch (_) {
      return null;
    }
  }

  double? _parseIncome(dynamic state) {
    try {
      final profile = state.profileData as Map<String, dynamic>?;
      if (profile == null) return null;
      final income = profile['monthly_income'];
      if (income == null) return null;
      if (income is num) return income.toDouble();
      return double.tryParse(income.toString());
    } catch (_) {
      return null;
    }
  }

  static const _priorityColors = {
    'essential': AppTheme.errorColor,
    'important': Color(0xFFF59E0B),
    'suggested': AppTheme.primaryColor,
    'later': AppTheme.textHint,
  };

  static const _priorityLabels = {
    'essential': 'ESSENTIAL',
    'important': 'IMPORTANT',
    'suggested': 'SUGGESTED',
    'later': 'LATER',
  };

  static const _iconMap = {
    'car': Icons.directions_car_rounded,
    'medical': Icons.local_hospital_rounded,
    'life': Icons.favorite_rounded,
    'home': Icons.home_rounded,
    'travel': Icons.flight_rounded,
    'disability': Icons.accessible_rounded,
    'education': Icons.school_rounded,
    'business': Icons.business_rounded,
    'pet': Icons.pets_rounded,
    'critical_illness': Icons.monitor_heart_rounded,
    'personal_accident': Icons.health_and_safety_rounded,
    'other': Icons.shield_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);
    final onboardingState = ref.watch(onboardingProvider);
    final emergencyVault = _findEmergency(vaultState.vaults);
    final monthlyIncome = _parseIncome(onboardingState);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Text('Protection Planning', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 108),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EmergencyFundCard(
                        vault: emergencyVault,
                        monthlyIncome: monthlyIncome,
                        currency: _fmt,
                      ),
                      const SizedBox(height: 24),
                      _buildInsuranceChecklist(),
                      const SizedBox(height: 24),
                      _buildRecommendations(),
                      const SizedBox(height: 16),
                      const Text(
                        'Recommendations are personalised by Aion based on your financial profile. FinWise does not sell insurance products.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsuranceChecklist() {
    final covered = _insuranceLabels.keys.where((k) => _insurance[k] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF5090E0)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Insurance Coverage', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
          Text('$covered/${_insuranceLabels.length}', style: TextStyle(
            color: covered == _insuranceLabels.length ? AppTheme.successColor : AppTheme.textHint,
            fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        const Text('Tick the insurance types you currently have', style: TextStyle(
          color: AppTheme.textHint, fontSize: 11)),
        const SizedBox(height: 12),
        if (_loadingInsurance)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: AppTheme.primaryColor)))
        else
          ..._insuranceLabels.entries.map((e) {
            final checked = _insurance[e.key] == true;
            return GestureDetector(
              onTap: () => _toggleInsurance(e.key, !checked),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: checked ? AppTheme.successColor.withValues(alpha: 0.06) : AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: checked
                    ? AppTheme.successColor.withValues(alpha: 0.3)
                    : AppTheme.glassBorderColor)),
                child: Row(children: [
                  Icon(
                    checked ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: checked ? AppTheme.successColor : AppTheme.textHint,
                    size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value, style: TextStyle(
                    color: checked ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 14, fontWeight: checked ? FontWeight.w600 : FontWeight.w400))),
                ]),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16,
              color: AppTheme.primaryColor.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            const Text("Aion's Recommendations", style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Personalised based on your financial profile', style: TextStyle(
          color: AppTheme.textHint, fontSize: 12)),
        const SizedBox(height: 16),
        if (_loadingRecs)
          const SkeletonTransactionList(count: 3)
        else if (_recommendations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorderColor),
            ),
            child: const Text('Chat with Aion to build your profile — recommendations will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          )
        else
          ..._recommendations.map((rec) {
            final type = rec['type'] as String? ?? '';
            final priority = rec['priority'] as String? ?? 'suggested';
            final iconKey = rec['icon'] as String? ?? 'other';
            final reason = rec['reason'] as String? ?? '';
            final benefit = rec['benefit'] as String? ?? '';
            final color = _priorityColors[priority] ?? AppTheme.textHint;
            final label = _priorityLabels[priority] ?? 'SUGGESTED';
            final icon = _iconMap[iconKey] ?? Icons.shield_rounded;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(type, style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(label, style: TextStyle(
                          color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Aion's personalised reasoning
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 13,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(reason, style: TextStyle(
                            color: AppTheme.primaryColor.withValues(alpha: 0.85),
                            fontSize: 12, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                  if (benefit.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(benefit, style: const TextStyle(
                      color: AppTheme.textHint, fontSize: 11, height: 1.3)),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ── Emergency Fund Card (kept from original) ──────────────────
class _EmergencyFundCard extends StatelessWidget {
  final VaultModel? vault;
  final double? monthlyIncome;
  final NumberFormat currency;

  const _EmergencyFundCard({
    required this.vault, required this.monthlyIncome, required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final balance = vault?.currentBalance ?? 0;
    final target = monthlyIncome != null ? monthlyIncome! * 6 : null;
    double coverage = 0;
    double progress = 0;
    if (monthlyIncome != null && monthlyIncome! > 0) {
      coverage = balance / monthlyIncome!;
      progress = (coverage / 6).clamp(0.0, 1.0);
    }

    final Color coverageColor;
    final String coverageLabel;
    if (coverage >= 6) {
      coverageColor = AppTheme.successColor;
      coverageLabel = 'Fully protected';
    } else if (coverage >= 3) {
      coverageColor = AppTheme.primaryColor;
      coverageLabel = 'Getting there';
    } else if (coverage >= 1) {
      coverageColor = const Color(0xFFFFAB40);
      coverageLabel = 'Building up';
    } else {
      coverageColor = AppTheme.errorColor;
      coverageLabel = 'Needs attention';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [coverageColor.withValues(alpha: 0.08), AppTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: coverageColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, size: 20, color: coverageColor),
              const SizedBox(width: 8),
              const Text('Emergency Fund', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: coverageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(coverageLabel, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: coverageColor)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vault == null)
            const Text('No emergency vault found. Ask Aion to create one.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))
          else ...[
            Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(currency.format(balance), style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: coverageColor)),
                  ],
                )),
                if (target != null)
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('6-month target', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text(currency.format(target), style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textHint)),
                    ],
                  )),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress, minHeight: 8,
                backgroundColor: AppTheme.glassBorderColor,
                valueColor: AlwaysStoppedAnimation<Color>(coverageColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${coverage.toStringAsFixed(1)} months covered — target is 6 months',
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
          ],
        ],
      ),
    );
  }
}
