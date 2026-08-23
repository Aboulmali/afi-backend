import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/screens/root_shell.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/utils/format.dart';
import 'package:samapoche/widgets/widgets.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenNotifications;
  final void Function(RouteName)? onGo;
  const HomeScreen({super.key, required this.onOpenNotifications, this.onGo});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final isDark = context.isDark;
          final muted = isDark ? AppDark.muted : AppColors.muted;
          final user = s.user!;
          final now = DateTime.now();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour', style: TextStyle(fontSize: 14, color: muted)),
                        Text(
                          user.firstName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onOpenNotifications,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppDark.surface : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(Icons.notifications_none_rounded, size: 22, color: AppColors.fg2),
                          ),
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Balance card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOLDE TOTAL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatMontant(s.balance)} F CFA',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.03,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '+${formatMontant(s.monthIncome)} F',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF86EFAC), fontFamily: 'Inter'),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Revenus mensuels',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '−${formatMontant(s.monthExpense)} F',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFFCA5A5), fontFamily: 'Inter'),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dépenses mensuelles',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Insight
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppDark.accentSoft : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        size: 20, color: isDark ? AppDark.accent : AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 14, height: 1.4, color: isDark ? AppDark.fg : AppColors.fg),
                          children: [
                            const TextSpan(text: 'Vous avez économisé '),
                            TextSpan(
                              text: '12%',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppDark.accent : AppColors.accent,
                              ),
                            ),
                            const TextSpan(text: ' de plus ce mois-ci. Continuez ainsi !'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Budget card
              AppCard(
                margin: const EdgeInsets.only(bottom: 20),
                onTap: () => _showBudgetModal(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle('Budget Alimentation', link: 'Détails', onLink: () => _showBudgetModal(context)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: s.budgetPct,
                        minHeight: 8,
                        backgroundColor: isDark ? AppDark.borderSoft : AppColors.borderSoft,
                        valueColor: AlwaysStoppedAnimation(
                          s.budgetPct >= 0.85 ? AppColors.danger : s.budgetPct >= 0.6 ? AppColors.warn : AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${formatFCFA(s.budgetSpent)} dépensés',
                            style: TextStyle(fontSize: 14, color: muted)),
                        Text('${formatFCFA(s.budgetRemaining)} restants',
                            style: TextStyle(fontSize: 14, color: muted)),
                      ],
                    ),
                  ],
                ),
              ),

              // Donut chart
              AppCard(
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle('Répartition des dépenses', link: 'Voir tout', onLink: () => _goTransactions(context)),
                    const SizedBox(height: 16),
                    const _DonutChart(),
                  ],
                ),
              ),

              // Recent transactions
              SectionTitle('Transactions récentes'),
              const SizedBox(height: 8),
              ...s.transactions.take(5).map((t) => _TxnRow(txn: t, now: now, onTap: () => _goTransactions(context))),
            ],
          );
        },
      ),
    );
  }

  void _goTransactions(BuildContext context) {
    if (onGo != null) {
      onGo!(RouteName.transactions);
    } else {
      showToast(context, 'Voir toutes les transactions dans l\'onglet Transactions', ToastType.info);
    }
  }

  void _showBudgetModal(BuildContext context) {
    final s = AppState.I;
    showModal(
      context,
      StatefulBuilder(
        builder: (context, setModal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Budget Alimentation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: context.isDark ? AppDark.fg : AppColors.fg)),
            const SizedBox(height: 12),
            Text('${formatFCFA(s.budgetSpent)} dépensés', style: TextStyle(fontSize: 14, color: context.isDark ? AppDark.muted : AppColors.muted)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: s.budgetPct,
                minHeight: 8,
                backgroundColor: context.isDark ? AppDark.borderSoft : AppColors.borderSoft,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(s.budgetPct * 100).round()}% utilisé', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(formatFCFA(s.budget), style: TextStyle(fontSize: 13, color: context.isDark ? AppDark.muted : AppColors.muted)),
              ],
            ),
            const SizedBox(height: 16),
            _BudgetStat(label: 'Restant', value: formatFCFA(s.budgetRemaining), color: AppColors.accent),
            _BudgetStat(label: 'Jours restants', value: '${s.daysLeftInMonth} jours'),
            _BudgetStat(label: 'Moyenne journalière', value: '${formatFCFA(s.dailyAvg)} / jour'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDark ? AppDark.accentSoft : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: context.isDark ? AppDark.accent : AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Essayez de réduire vos sorties restaurant pour tenir votre budget jusqu\'à la fin du mois.',
                      style: TextStyle(fontSize: 13, color: context.isDark ? AppDark.fg : AppColors.fg, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppButton(label: 'Fermer', small: true, onPressed: () => Navigator.pop(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _BudgetStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final muted = context.isDark ? AppDark.muted : AppColors.muted;
    final fg = context.isDark ? AppDark.fg : AppColors.fg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: muted)),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? fg)),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart();

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    final data = s.donutData;
    final muted = context.isDark ? AppDark.muted : AppColors.muted;
    final fg = context.isDark ? AppDark.fg : AppColors.fg;
    if (data.isEmpty) {
      return const EmptyState(title: 'Aucune dépense', subtitle: 'Ajoutez des dépenses pour voir la répartition.');
    }
    final legend = data.take(5).toList();
    final restPct = data.length > 5 ? 100 - legend.fold(0, (sum, e) => sum + e.$2) : 0;

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(data),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (name, pct, color) in legend)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(name, style: TextStyle(fontSize: 14, color: fg)),
                      const Spacer(),
                      Text('$pct%',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                    ],
                  ),
                ),
              if (restPct > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.chartOther, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Autres', style: TextStyle(fontSize: 14, color: fg)),
                      const Spacer(),
                      Text('$restPct%',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(String, int, Color)> data;
  _DonutPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final stroke = 20.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE8E8ED);
    canvas.drawCircle(center, radius, bgPaint);

    const startAngle = -math.pi / 2;
    var current = startAngle;
    for (final (_, pct, color) in data) {
      final sweep = pct / 100 * 2 * math.pi;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(rect, current, sweep, false, paint);
      current += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.data != data;
}

class _TxnRow extends StatelessWidget {
  final Txn txn;
  final DateTime now;
  final VoidCallback onTap;
  const _TxnRow({required this.txn, required this.now, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = Categories.byName(txn.category);
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final borderSoft = isDark ? AppDark.borderSoft : AppColors.borderSoft;
    final fg = isDark ? AppDark.fg : AppColors.fg;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderSoft, width: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: cat.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(cat.icon, size: 18, color: cat.fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: fg)),
                  const SizedBox(height: 1),
                  Text(formatDateHome(txn.date, now), style: TextStyle(fontSize: 12, color: muted)),
                ],
              ),
            ),
            Text(
              montantSigne(txn.signed),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: txn.type == TxnType.income
                    ? (isDark ? AppDark.accent : AppColors.accent)
                    : fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
