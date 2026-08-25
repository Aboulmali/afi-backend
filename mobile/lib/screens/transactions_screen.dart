import 'package:flutter/material.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/screens/add_transaction_screen.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/utils/format.dart';
import 'package:samapoche/widgets/widgets.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _query = '';
  String _period = 'Tous';
  String _catFilter = 'Toutes';
  String _amountFilter = 'Tous';
  String _typeFilter = 'Tous';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) {
          final s = AppState.I;
          final now = DateTime.now();
          final filtered = _applyFilters(s.transactions, now);

          // Regroupement par mois
          final groups = <String, List<Txn>>{};
          for (final t in filtered) {
            final key = moisAnnee(t.date);
            groups.putIfAbsent(key, () => []).add(t);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transactions',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText: 'Rechercher une transaction…',
                              hintStyle: TextStyle(fontSize: 16, color: context.isDark ? AppDark.meta : AppColors.meta),
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 20, color: context.isDark ? AppDark.meta : AppColors.meta),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _openFilterModal,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.isDark ? AppDark.surface : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.isDark ? AppDark.border : AppColors.border, width: 1.5),
                            ),
                            child: Icon(Icons.tune_rounded,
                                size: 20, color: context.isDark ? AppDark.fg2 : AppColors.fg2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final p in ['Tous', 'Ce mois', '3 derniers mois', '2026', 'Personnalisé'])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppChip(
                                label: p,
                                active: _period == p,
                                onTap: () {
                                  setState(() => _period = p);
                                  if (p == 'Personnalisé') _openFilterModal();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        title: 'Aucune transaction',
                        subtitle: 'Essayez de modifier vos filtres ou d\'ajouter une nouvelle transaction.',
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: [
                          for (final entry in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 4),
                              child: Text(
                                entry.key.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: context.isDark ? AppDark.muted : AppColors.muted,
                                ),
                              ),
                            ),
                            for (final t in entry.value)
                              _TxnListItem(txn: t, onTap: () => _openDetail(t)),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Txn> _applyFilters(List<Txn> all, DateTime now) {
    var list = all;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((t) {
        return t.name.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q);
      }).toList();
    }
    switch (_period) {
      case 'Ce mois':
        list = list.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
        break;
      case '3 derniers mois':
        final from = DateTime(now.year, now.month - 2, 1);
        list = list.where((t) => !t.date.isBefore(from)).toList();
        break;
      case '2026':
        list = list.where((t) => t.date.year == 2026).toList();
        break;
    }
    if (_catFilter != 'Toutes') {
      list = list.where((t) => t.category == _catFilter).toList();
    }
    switch (_amountFilter) {
      case 'Moins de 5 000 F':
        list = list.where((t) => t.amount < 5000).toList();
        break;
      case '5 000 - 20 000 F':
        list = list.where((t) => t.amount >= 5000 && t.amount <= 20000).toList();
        break;
      case 'Plus de 20 000 F':
        list = list.where((t) => t.amount > 20000).toList();
        break;
    }
    switch (_typeFilter) {
      case 'Dépenses':
        list = list.where((t) => t.type == TxnType.expense).toList();
        break;
      case 'Revenus':
        list = list.where((t) => t.type == TxnType.income).toList();
        break;
    }
    return list;
  }

  void _openFilterModal() {
    showModal(
      context,
      StatefulBuilder(
        builder: (context, setModal) {
          Widget section(String title, List<String> options, String current, ValueChanged<String> onSelect) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionGroupLabel(title),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in options)
                      AppChip(label: o, active: current == o, onTap: () => onSelect(o)),
                  ],
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section('Par catégorie', ['Toutes', ...Categories.all.map((c) => c.name)], _catFilter, (v) {
                setModal(() => _catFilter = v);
              }),
              const SizedBox(height: 12),
              section('Par montant', ['Tous', 'Moins de 5 000 F', '5 000 - 20 000 F', 'Plus de 20 000 F'], _amountFilter, (v) {
                setModal(() => _amountFilter = v);
              }),
              const SizedBox(height: 12),
              section('Par type', ['Tous', 'Dépenses', 'Revenus'], _typeFilter, (v) {
                setModal(() => _typeFilter = v);
              }),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Réinitialiser',
                      ghost: true,
                      small: true,
                      onPressed: () {
                        setModal(() {
                          _catFilter = 'Toutes';
                          _amountFilter = 'Tous';
                          _typeFilter = 'Tous';
                        });
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Appliquer',
                      primary: true,
                      small: true,
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDetail(Txn t) {
    final cat = Categories.byName(t.category);
    final isDark = context.isDark;
    // ignore: unused_local_variable
    showModal(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: cat.bg, borderRadius: BorderRadius.circular(16)),
            child: Icon(cat.icon, size: 26, color: cat.fg),
          ),
          const SizedBox(height: 12),
          Text(t.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Text(
            montantSigne(t.signed),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.03,
              color: t.type == TxnType.income ? (isDark ? AppDark.accent : AppColors.accent) : (isDark ? AppDark.fg : AppColors.fg),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDateDetail(t.date),
            style: TextStyle(fontSize: 14, color: isDark ? AppDark.muted : AppColors.muted),
          ),
          const SizedBox(height: 20),
          _DetailRow(label: 'Catégorie', value: t.category),
          _DetailRow(label: 'Type', value: t.type == TxnType.expense ? 'Dépense' : 'Revenu'),
          _DetailRow(label: 'Description', value: t.description),
          _DetailRow(label: 'Paiement', value: t.payment),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Fermer',
                  ghost: true,
                  small: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Modifier',
                  primary: true,
                  small: true,
                  onPressed: () {
                    Navigator.pop(context);
                    _openEdit(t);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEdit(Txn t) {
    showModal(
      context,
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: AddTransactionScreen(edit: t),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final fg = isDark ? AppDark.fg : AppColors.fg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, color: muted)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

class _TxnListItem extends StatelessWidget {
  final Txn txn;
  final VoidCallback onTap;
  const _TxnListItem({required this.txn, required this.onTap});

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
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderSoft, width: 0.5))),
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
                  Text(txn.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: fg)),
                  const SizedBox(height: 1),
                  Text(formatDateListe(txn.date), style: TextStyle(fontSize: 12, color: muted)),
                ],
              ),
            ),
            Text(
              montantSigne(txn.signed),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: txn.type == TxnType.income ? (isDark ? AppDark.accent : AppColors.accent) : fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
