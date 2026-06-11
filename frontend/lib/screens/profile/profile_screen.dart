// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : profile_screen.dart
// Description   : My Financial Profile — read-only screen showing
//                 what the user declared and what Aria concluded
// First Written : 06-06-2026
// Edited on     : 06-06-2026
// ============================================

import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/api/ai_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await AiApi().getMyProfile();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────

  String _label(String? raw) {
    if (raw == null || raw.isEmpty) return 'Not specified';
    return raw.replaceAll('_', ' ').split(' ').map((w) =>
        w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back button + large title ───────────
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppTheme.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'My Financial Profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _error != null
                      ? _buildError()
                      : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _buildContent() {
    final onboarding =
        _data?['onboarding'] as Map<String, dynamic>? ?? {};
    final aiProfile =
        _data?['ai_profile'] as Map<String, dynamic>? ?? {};
    final history =
        (_data?['allocation_history'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // ── Section 1: What you told Aria ──────────
        const _SectionHeader(
          icon: Icons.person_rounded,
          title: 'What You Told Aria',
          subtitle: 'Your declarations during setup',
        ),
        const SizedBox(height: 12),
        _InfoCard(children: [
          _Row('Monthly Budget',
              'RM ${onboarding['monthly_income']?.toString() ?? '—'}'),
          _Divider(),
          _Row('Life Situation',
              _label(onboarding['life_situation'] as String?)),
          _Divider(),
          _Row('Spending Habit',
              _label(onboarding['spending_habit'] as String?)),
          _Divider(),
          _Row('Risk Tolerance',
              _label(onboarding['risk_level'] as String?)),
          _Divider(),
          _Row('Challenges',
              onboarding['financial_challenges'] as String? ?? '—'),
        ]),
        const SizedBox(height: 12),

        // Goals list
        if (_buildGoals(onboarding).isNotEmpty) ...[
          _GoalsCard(goals: _buildGoals(onboarding)),
          const SizedBox(height: 24),
        ],

        // ── Section 2: What Aria concluded ─────────
        const _SectionHeader(
          icon: Icons.psychology_rounded,
          title: 'What Aria Knows',
          subtitle: 'AI observations from your behaviour',
        ),
        const SizedBox(height: 12),

        // Behavioural classification badge
        _ClassificationCard(
            classification: aiProfile['behavioral_classification'] as String?),
        const SizedBox(height: 12),

        // Key insights
        _KeyInsightsCard(
            insights: aiProfile['key_insights'] as Map<String, dynamic>?),
        const SizedBox(height: 12),

        // Recommended allocation
        _AllocationCard(
            allocation:
                aiProfile['recommended_allocation'] as Map<String, dynamic>?),
        const SizedBox(height: 24),

        // ── Section 3: Allocation history ──────────
        const _SectionHeader(
          icon: Icons.history_rounded,
          title: 'Allocation History',
          subtitle: 'How Aria\'s recommendations evolved',
        ),
        const SizedBox(height: 12),
        _HistoryTimeline(entries: history, formatDate: _formatDate),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'All changes are AI-driven — chat with Aria to adjust',
            style: TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _buildGoals(Map<String, dynamic> onboarding) {
    final raw = onboarding['financial_goals'];
    if (raw == null) return [];
    final goals = (raw['goals'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ?? [];
    return goals;
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// INFO CARD — key/value rows
// ─────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: children),
        ),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppTheme.glassBorderColor);
}

// ─────────────────────────────────────────────
// GOALS CARD
// ─────────────────────────────────────────────
class _GoalsCard extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  const _GoalsCard({required this.goals});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial Goals',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ...goals.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 4, right: 10),
                      decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g['goal'] as String? ?? '—',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          if (g['timeline'] != null)
                            Text(
                                'Timeline: ${g['timeline']}  ·  ${g['priority'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BEHAVIOURAL CLASSIFICATION CARD
// ─────────────────────────────────────────────
class _ClassificationCard extends StatelessWidget {
  final String? classification;
  const _ClassificationCard({this.classification});

  Color get _color {
    switch (classification) {
      case 'disciplined_saver':
      case 'goal_oriented_spender':
        return const Color(0xFF16A34A);
      case 'balanced_spender':
        return AppTheme.primaryColor;
      case 'impulse_spender':
      case 'high_variability_spender':
        return const Color(0xFFF59E0B);
      case 'risk_averse':
        return const Color(0xFF6366F1);
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = (classification ?? 'Not yet classified')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _color.withValues(alpha: 0.3)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: _color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Aria\'s behavioural classification based on your transaction patterns',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// KEY INSIGHTS CARD
// ─────────────────────────────────────────────
class _KeyInsightsCard extends StatelessWidget {
  final Map<String, dynamic>? insights;
  const _KeyInsightsCard({this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights == null) {
      return const SizedBox.shrink();
    }
    final summary = insights!['summary'] as String?;
    final patterns =
        (insights!['financial_patterns'] as List<dynamic>?)
            ?.cast<String>() ?? [];
    final goals =
        (insights!['goals_discussed'] as List<dynamic>?)
            ?.cast<String>() ?? [];
    final behavioural =
        (insights!['behavioral_notes'] as List<dynamic>?)
            ?.cast<String>() ?? [];

    final hasContent = summary != null ||
        patterns.isNotEmpty ||
        goals.isNotEmpty ||
        behavioural.isNotEmpty;

    if (!hasContent) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aria\'s Notes About You',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textSecondary)),
          if (summary != null) ...[
            const SizedBox(height: 10),
            Text(summary,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                    height: 1.5)),
          ],
          if (patterns.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InsightGroup(label: 'Spending Patterns', items: patterns),
          ],
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InsightGroup(label: 'Goals Discussed', items: goals),
          ],
          if (behavioural.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InsightGroup(label: 'Behavioural Notes', items: behavioural),
          ],
        ],
      ),
    );
  }
}

class _InsightGroup extends StatelessWidget {
  final String label;
  final List<String> items;
  const _InsightGroup({required this.label, required this.items});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text(item,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary,
                                height: 1.4))),
                  ],
                ),
              )),
        ],
      );
}

// ─────────────────────────────────────────────
// RECOMMENDED ALLOCATION CARD
// ─────────────────────────────────────────────
class _AllocationCard extends StatelessWidget {
  final Map<String, dynamic>? allocation;
  const _AllocationCard({this.allocation});

  @override
  Widget build(BuildContext context) {
    if (allocation == null || allocation!.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = allocation!.entries.toList()
      ..sort((a, b) =>
          (b.value as num).compareTo(a.value as num));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recommended Allocation',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final pct = (e.value as num).toDouble();
            final label = e.key
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isEmpty
                    ? w
                    : '${w[0].toUpperCase()}${w.substring(1)}')
                .join(' ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textPrimary)),
                      Text('${pct.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation(
                          AppTheme.primaryColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ALLOCATION HISTORY TIMELINE
// ─────────────────────────────────────────────
class _HistoryTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final String Function(String) formatDate;
  const _HistoryTimeline(
      {required this.entries, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.glassBorderColor),
        ),
        child: const Center(
          child: Text('No allocation changes yet',
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderColor),
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isLast = i == entries.length - 1;
          return _TimelineEntry(
            entry: e,
            isLast: isLast,
            formatDate: formatDate,
          );
        }).toList(),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final Map<String, dynamic> entry;
  final bool isLast;
  final String Function(String) formatDate;
  const _TimelineEntry(
      {required this.entry,
      required this.isLast,
      required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final date = entry['created_at'] as String? ?? '';
    final reason = entry['change_reason'] as String? ?? '—';
    final triggeredBy = entry['triggered_by'] as String? ?? '—';
    final newAlloc =
        entry['new_allocation'] as Map<String, dynamic>? ?? {};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + dot
            Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                        width: 2,
                        color: AppTheme.primaryColor
                            .withValues(alpha: 0.2)),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    top: 8, bottom: isLast ? 16 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date.isNotEmpty ? formatDate(date) : '—',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(reason,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Triggered by: ${_triggeredByLabel(triggeredBy)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary)),
                    if (newAlloc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: newAlloc.entries
                            .take(4)
                            .map((e) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                      '${e.key.replaceAll('_', ' ')}: ${e.value}%',
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.primaryColor,
                                          fontWeight:
                                              FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _triggeredByLabel(String raw) {
    switch (raw) {
      case 'onboarding':
        return 'Onboarding';
      case 'ai_chat':
        return 'Chat with Aria';
      case 'ai_analysis':
        return 'Aria background analysis';
      default:
        return raw.replaceAll('_', ' ');
    }
  }
}
