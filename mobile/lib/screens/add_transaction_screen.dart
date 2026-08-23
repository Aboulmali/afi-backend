import 'package:flutter/material.dart';
import 'package:samapoche/models/models.dart';
import 'package:samapoche/state/app_state.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/utils/format.dart';
import 'package:samapoche/widgets/widgets.dart';

class AddTransactionScreen extends StatefulWidget {
  final Txn? edit;
  final VoidCallback? onClose;
  const AddTransactionScreen({super.key, this.edit, this.onClose});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late TxnType _type;
  late String _category;
  late TextEditingController _amount;
  late TextEditingController _desc;
  late DateTime _date;
  String? _amountError;
  final _payments = ['Carte Visa ••8842', 'Orange Money', 'Virement bancaire', 'Prélèvement automatique', 'Espèces'];
  late String _payment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _type = e?.type ?? TxnType.expense;
    _category = e?.category ?? 'Alimentation';
    _amount = TextEditingController(text: e != null ? formatMontant(e.amount) : '');
    _desc = TextEditingController(text: e?.description ?? '');
    _date = e?.date ?? DateTime.now();
    _payment = e?.payment ?? _payments[0];
  }

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save({bool andNew = false}) async {
    final amount = int.tryParse(_amount.text.replaceAll(' ', '')) ?? 0;
    if (amount <= 0) {
      setState(() => _amountError = 'Montant invalide');
      return;
    }
    setState(() {
      _amountError = null;
      _saving = true;
    });
    final txn = Txn(
      id: widget.edit?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _desc.text.trim().isEmpty ? Categories.byName(_category).name : _desc.text.trim(),
      category: _category,
      type: _type,
      amount: amount,
      description: _desc.text.trim().isEmpty ? Categories.byName(_category).name : _desc.text.trim(),
      payment: _payment,
      date: _date,
    );
    if (widget.edit != null) {
      await AppState.I.updateTxn(txn);
    } else {
      await AppState.I.addTxn(txn);
    }
    if (!mounted) return;
    showToast(context, widget.edit != null ? 'Transaction modifiée' : 'Transaction enregistrée', ToastType.success);
    setState(() => _saving = false);
    if (andNew) {
      setState(() {
        _amount.clear();
        _desc.clear();
        _type = TxnType.expense;
        _category = 'Alimentation';
      });
    } else {
      _close();
    }
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final muted = isDark ? AppDark.muted : AppColors.muted;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    final surface = isDark ? AppDark.surface : AppColors.surface;
    final fg = isDark ? AppDark.fg : AppColors.fg;
    final meta = isDark ? AppDark.meta : AppColors.meta;

    final cats = _type == TxnType.expense ? Categories.expenses : [Categories.salaire, Categories.autre];

    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _close,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.edit != null ? 'Modifier la transaction' : 'Nouvelle transaction',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
              const SizedBox(height: 24),

              // Type toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeToggle(
                        label: 'Dépense',
                        active: _type == TxnType.expense,
                        onTap: () => setState(() {
                          _type = TxnType.expense;
                          _category = 'Alimentation';
                        }),
                      ),
                    ),
                    Expanded(
                      child: _TypeToggle(
                        label: 'Revenu',
                        active: _type == TxnType.income,
                        onTap: () => setState(() {
                          _type = TxnType.income;
                          _category = 'Salaire';
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              Center(
                child: Text('F CFA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: muted)),
              ),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -0.03, color: fg),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: isDark ? AppDark.border : AppColors.border, fontSize: 48, fontWeight: FontWeight.w800),
                  filled: false,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorText: _amountError,
                  errorStyle: const TextStyle(fontSize: 12),
                  errorMaxLines: 1,
                ),
              ),
              const SizedBox(height: 16),

              UppercaseLabel('Catégorie'),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final c in cats)
                    _CatTile(
                      cat: c,
                      active: _category == c.name,
                      onTap: () => setState(() => _category = c.name),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              FieldLabel('Description'),
              TextField(
                controller: _desc,
                decoration: InputDecoration(
                  hintText: 'Ajoutez une description',
                  hintStyle: TextStyle(color: meta),
                ),
              ),
              const SizedBox(height: 16),

              FieldLabel('Date'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2032),
                    locale: const Locale('fr'),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppDark.border : AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: meta),
                      const SizedBox(width: 12),
                      Text(formatDateListe(_date),
                          style: TextStyle(fontSize: 16, color: fg)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              FieldLabel('Paiement'),
              DropdownButtonFormField<String>(
                initialValue: _payment,
                decoration: InputDecoration(filled: true, fillColor: surface),
                style: TextStyle(fontSize: 16, color: fg),
                dropdownColor: isDark ? AppDark.surface : AppColors.surface,
                items: [
                  for (final p in _payments)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (v) => setState(() => _payment = v ?? _payments[0]),
              ),
              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: AppButton(
                      label: 'Annuler',
                      ghost: true,
                      small: true,
                      onPressed: _close,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: widget.edit != null ? 'Enregistrer' : 'Enregistrer',
                      primary: true,
                      small: true,
                      loading: _saving,
                      onPressed: () => _save(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (widget.edit == null)
                    Expanded(
                      flex: 1,
                      child: AppButton(
                        label: '+',
                        outline: true,
                        small: true,
                        onPressed: () => _save(andNew: true),
                      ),
                    ),
                ],
              ),
              if (widget.edit == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      'Enregistrer et nouvelle transaction',
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TypeToggle({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.isDark ? AppDark.accent : AppColors.accent;
    final muted = context.isDark ? AppDark.muted : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  final Category cat;
  final bool active;
  final VoidCallback onTap;
  const _CatTile({required this.cat, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface = isDark ? AppDark.surface : AppColors.surface;
    final fg2 = isDark ? AppDark.fg2 : AppColors.fg2;
    final accentSoft = isDark ? AppDark.accentSoft : AppColors.accentSoft;
    final accent = isDark ? AppDark.accent : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? accentSoft : surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: active ? accent : cat.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cat.icon, size: 18, color: active ? Colors.white : cat.fg),
            ),
            const SizedBox(height: 6),
            Text(
              cat.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? accent : fg2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
