import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';

class AppState extends ChangeNotifier {
  static final AppState I = AppState._();

  AppState._();

  SharedPreferences? _prefs;
  bool _loaded = false;

  UserProfile? user;
  List<Txn> transactions = [];
  bool darkMode = false;
  int budget = 150000;
  int savingsGoal = 300000;
  bool notifPush = true;
  bool notifFactures = true;
  bool notifConseils = true;
  bool ecoData = false;
  bool budgetAuto = true;

  List<AppNotification> notifications = [];
  final List<ChatMessage> chat = [];

  bool get loaded => _loaded;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Profil
    final u = _prefs!.getString('samapoche_user');
    if (u != null) {
      try {
        user = UserProfile.fromJson(jsonDecode(u) as Map<String, dynamic>);
      } catch (_) {
        _prefs!.remove('samapoche_user');
      }
    }
    // Transactions
    final t = _prefs!.getString('samapoche_txns');
    if (t != null) {
      try {
        transactions = (jsonDecode(t) as List)
            .map((e) => Txn.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
      } catch (_) {
        transactions = seedTransactions();
      }
    } else {
      transactions = seedTransactions();
      await _saveTxns();
    }
    darkMode = _prefs!.getBool('samapoche_dark') ?? false;
    budget = _prefs!.getInt('samapoche_budget') ?? 150000;
    savingsGoal = _prefs!.getInt('samapoche_goal') ?? 300000;
    notifPush = _prefs!.getBool('samapoche_notif_push') ?? true;
    notifFactures = _prefs!.getBool('samapoche_notif_factures') ?? true;
    notifConseils = _prefs!.getBool('samapoche_notif_conseils') ?? true;
    ecoData = _prefs!.getBool('samapoche_eco') ?? false;
    budgetAuto = _prefs!.getBool('samapoche_budget_auto') ?? true;

    _buildNotifications();
    _seedChat();
    _loaded = true;
    notifyListeners();
  }

  // ─── Auth ────────────────────────────────────────────────
  Future<String?> signup(UserProfile p, String password) async {
    final existing = _prefs!.getString('samapoche_user');
    if (existing != null) {
      final e = UserProfile.fromJson(jsonDecode(existing) as Map<String, dynamic>);
      if (e.email == p.email) return 'Un compte existe déjà avec cet email.';
    }
    user = p;
    await _prefs!.setString('samapoche_user', jsonEncode(p.toJson()));
    await _prefs!.setString('samapoche_pass', _hash(password));
    notifyListeners();
    return null;
  }

  Future<String?> login(String email, String password) async {
    final existing = _prefs!.getString('samapoche_user');
    if (existing == null) return 'Aucun compte trouvé. Créez-en un d\'abord.';
    final e = UserProfile.fromJson(jsonDecode(existing) as Map<String, dynamic>);
    if (e.email != email) return 'Email incorrect';
    final saved = _prefs!.getString('samapoche_pass');
    if (saved == null || saved != _hash(password)) return 'Mot de passe incorrect';
    user = e;
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    user = null;
    await _prefs!.remove('samapoche_user');
    chat.clear();
    _seedChat();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    user = p;
    await _prefs!.setString('samapoche_user', jsonEncode(p.toJson()));
    notifyListeners();
  }

  String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  // ─── Transactions ────────────────────────────────────────
  Future<void> addTxn(Txn t) async {
    transactions.insert(0, t);
    await _saveTxns();
    notifyListeners();
  }

  Future<void> updateTxn(Txn t) async {
    final i = transactions.indexWhere((x) => x.id == t.id);
    if (i >= 0) transactions[i] = t;
    await _saveTxns();
    notifyListeners();
  }

  Future<void> _saveTxns() async {
    await _prefs!.setString('samapoche_txns', jsonEncode(transactions.map((t) => t.toJson()).toList()));
  }

  // ─── Dashboard computed ──────────────────────────────────
  int get balance => transactions.fold(0, (s, t) => s + t.signed);

  List<Txn> get monthTxns {
    final now = DateTime.now();
    return transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
  }

  int get monthIncome => monthTxns.where((t) => t.type == TxnType.income).fold(0, (s, t) => s + t.amount);

  int get monthExpense => monthTxns.where((t) => t.type == TxnType.expense).fold(0, (s, t) => s + t.amount);

  int get budgetSpent =>
      transactions.where((t) => t.category == 'Alimentation' && t.type == TxnType.expense && _sameMonth(t.date)).fold(0, (s, t) => s + t.amount);

  int get budgetRemaining => budget - budgetSpent;

  double get budgetPct => budget == 0 ? 0 : (budgetSpent / budget).clamp(0, 1.0);

  int get daysLeftInMonth {
    final now = DateTime.now();
    final last = DateTime(now.year, now.month + 1, 0).day;
    return last - now.day;
  }

  int get dailyAvg => daysLeftInMonth == 0 ? 0 : (budgetRemaining / daysLeftInMonth).round();

  bool _sameMonth(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month;
  }

  List<(String, int, Color)> get donutData {
    final byCat = <String, int>{};
    for (final t in transactions.where((t) => t.type == TxnType.expense && _sameMonth(t.date))) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    if (byCat.isEmpty) return [];
    final total = byCat.values.fold(0, (s, v) => s + v);
    final list = byCat.entries.map((e) {
      final c = Categories.byName(e.key);
      return (e.key, (e.value / total * 100).round(), c.fg);
    }).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  // ─── Notifications ──────────────────────────────────────
  void _buildNotifications() {
    notifications = [
      AppNotification(
        title: 'Budget alimentation presque atteint',
        desc: 'Vous avez utilisé 82% de votre budget alimentation. Il reste 18 700 F CFA.',
        time: '14:30',
        group: "Aujourd'hui",
        bg: AppColors.warnSoft,
        fg: const Color(0xFFD97706),
        icon: Icons.warning_amber_rounded,
        read: false,
      ),
      AppNotification(
        title: "Objectif d'épargne atteint à 60%",
        desc: 'Vous avez épargné 180 000 F CFA sur votre objectif de 300 000 F CFA. Continuez !',
        time: '10:15',
        group: "Aujourd'hui",
        bg: AppColors.accentSoft,
        fg: AppColors.accent,
        icon: Icons.trending_up_rounded,
        read: false,
      ),
      AppNotification(
        title: 'Rappel : Facture Senelec',
        desc: 'Votre facture d\'électricité de 32 000 F CFA arrive à échéance le 25 juillet.',
        time: 'Lun 21 Juil',
        group: 'Cette semaine',
        bg: AppColors.infoSoft,
        fg: const Color(0xFF2563EB),
        icon: Icons.event_rounded,
        read: true,
      ),
      AppNotification(
        title: 'Dépense inhabituelle détectée',
        desc: 'Votre dépense chez Jumia (15 900 F CFA) est 40% plus élevée que votre moyenne mensuelle.',
        time: 'Ven 11 Juil',
        group: 'Cette semaine',
        bg: AppColors.dangerSoft,
        fg: AppColors.danger,
        icon: Icons.error_outline_rounded,
        read: true,
      ),
      AppNotification(
        title: 'Insight IA : Vous gérez mieux votre budget',
        desc: 'Félicitations ! Vous avez réduit vos dépenses de 8% par rapport au mois dernier. Analyse détaillée disponible.',
        time: 'Mer 2 Juil',
        group: 'Juillet 2026',
        bg: AppColors.accentSoft,
        fg: AppColors.accent,
        icon: Icons.auto_awesome_rounded,
        read: true,
      ),
    ];
  }

  void markAllRead() {
    for (final n in notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void markRead(AppNotification n) {
    n.read = true;
    notifyListeners();
  }

  // ─── Chat ────────────────────────────────────────────────
  void _seedChat() {
    final now = DateTime.now();
    final n1 = DateTime(now.year, now.month, now.day, 9, 41);
    final n2 = DateTime(now.year, now.month, now.day, 9, 42);
    final n3 = DateTime(now.year, now.month, now.day, 9, 43);
    chat.addAll([
      ChatMessage(
        text: 'Bonjour ${user?.firstName ?? ''} ! Je suis votre assistant financier. Comment puis-je vous aider aujourd\'hui ?',
        fromUser: false,
        time: n1,
      ),
      ChatMessage(text: 'Quel est mon budget alimentation ce mois-ci ?', fromUser: true, time: n2),
      ChatMessage(
        text: 'Votre budget Alimentation pour juillet est de 150 000 F CFA. Vous avez déjà dépensé 82 300 F CFA (55%). Il vous reste 67 700 F CFA pour les 9 prochains jours. Voulez-vous ajuster ce budget ?',
        fromUser: false,
        time: n2,
      ),
      ChatMessage(text: 'Des conseils pour économiser ?', fromUser: true, time: n3),
      ChatMessage(
        text: 'Voici 3 conseils personnalisés pour vous :\n\n1. Réduisez vos sorties restaurant de 20% ce mois-ci\n2. Privilégiez les achats en gros à Auchan\n3. Activez l\'arrondi automatique sur chaque transaction',
        fromUser: false,
        time: n3,
      ),
    ]);
  }

  void clearChat() {
    chat.clear();
    chat.add(ChatMessage(
      text: 'Conversation effacée. Je suis là pour vous aider !',
      fromUser: false,
      time: DateTime.now(),
    ));
    notifyListeners();
  }

  String aiReply(String q) {
    final ql = q.toLowerCase();
    if (ql.contains('budget') || ql.contains('alimentation')) {
      return 'Votre budget Alimentation pour juillet est de ${formatFCFA(budget)}. Vous avez déjà dépensé ${formatFCFA(budgetSpent)} (${(budgetPct * 100).round()}%). Il vous reste ${formatFCFA(budgetRemaining)} pour les $daysLeftInMonth prochains jours.';
    }
    if (ql.contains('dépense') || ql.contains('depense') || ql.contains('catégorie') || ql.contains('categorie')) {
      final parts = donutData.map((d) => '• ${d.$1} : ${formatFCFA(d.$2 == 0 ? 0 : (monthExpense * d.$2 / 100).round())}').join('\n');
      return 'Voici le résumé de vos dépenses pour ${moisAnnee(DateTime.now())} :\n$parts\n— Total : ${formatFCFA(monthExpense)}';
    }
    if (ql.contains('épargne') || ql.contains('epargne') || ql.contains('économi') || ql.contains('economi')) {
      return 'Pour atteindre votre objectif d\'épargne de ${formatFCFA(savingsGoal)} :\n1. Réduisez vos dépenses alimentation de 15% (~12 000 F/mois)\n2. Limitez les courses Yango aux jours de pluie\n3. Activez l\'arrondi automatique sur chaque transaction\n\nVous pourriez économiser 45 000 F CFA supplémentaires ce mois-ci !';
    }
    if (ql.contains('conseil') || ql.contains('astuce') || ql.contains('mieu')) {
      return 'Voici 3 conseils personnalisés :\n1. Réduisez vos sorties restaurant de 20% ce mois-ci\n2. Privilégiez les achats en gros à Auchan\n3. Activez les notifications de dépassement de budget';
    }
    if (ql.contains('salaire') || ql.contains('revenu')) {
      return 'Votre salaire de 450 000 F CFA a été crédité le 14 Juillet. Depuis le début du mois, vous avez dépensé ${formatFCFA(monthExpense)}, soit un taux d\'épargne de ${monthIncome == 0 ? 0 : (100 - monthExpense / monthIncome * 100).round()}%. Excellent travail !';
    }
    return 'Je suis votre assistant financier SamaPoche. Je peux vous aider à :\n• Consulter votre budget mensuel\n• Analyser vos dépenses par catégorie\n• Fixer des objectifs d\'épargne\n• Obtenir des conseils personnalisés\n\nQue souhaitez-vous savoir ?';
  }

  // ─── Settings ────────────────────────────────────────────
  Future<void> setDarkMode(bool v) async {
    darkMode = v;
    await _prefs!.setBool('samapoche_dark', v);
    notifyListeners();
  }

  Future<void> setBudget(int v) async {
    budget = v;
    await _prefs!.setInt('samapoche_budget', v);
    notifyListeners();
  }

  Future<void> setGoal(int v) async {
    savingsGoal = v;
    await _prefs!.setInt('samapoche_goal', v);
    notifyListeners();
  }

  Future<void> setPref(String key, bool v) async {
    switch (key) {
      case 'push':
        notifPush = v;
        await _prefs!.setBool('samapoche_notif_push', v);
        break;
      case 'factures':
        notifFactures = v;
        await _prefs!.setBool('samapoche_notif_factures', v);
        break;
      case 'conseils':
        notifConseils = v;
        await _prefs!.setBool('samapoche_notif_conseils', v);
        break;
      case 'eco':
        ecoData = v;
        await _prefs!.setBool('samapoche_eco', v);
        break;
      case 'auto':
        budgetAuto = v;
        await _prefs!.setBool('samapoche_budget_auto', v);
        break;
    }
    notifyListeners();
  }

  List<Txn> seedTransactions() {
    final now = DateTime.now();
    final juli = DateTime(now.year, now.month, now.day);
    DateTime dt(int day, int h, int m) {
      return DateTime(juli.year, juli.month.clamp(1, 12), day.clamp(1, DateTime(juli.year, juli.month.clamp(1, 12) + 1, 0).day), h, m);
    }

    return [
      Txn(id: 'auchan', name: 'Auchan Dakar', category: 'Alimentation', type: TxnType.expense, amount: 28500, description: 'Courses alimentaires', payment: 'Carte Visa ••8842', date: dt(22, 14, 30)),
      Txn(id: 'yango', name: 'Yango Course', category: 'Transport', type: TxnType.expense, amount: 5200, description: 'Course Ouakam → Médina', payment: 'Orange Money', date: dt(21, 8, 15)),
      Txn(id: 'salaire', name: 'Salaire Juillet', category: 'Salaire', type: TxnType.income, amount: 450000, description: 'Salaire mensuel Juillet 2026', payment: 'Virement bancaire', date: dt(14, 9, 0)),
      Txn(id: 'jumia', name: 'Jumia Sénégal', category: 'Shopping', type: TxnType.expense, amount: 15900, description: 'Electroménager & accessoires', payment: 'Carte Visa ••8842', date: dt(11, 16, 45)),
      Txn(id: 'senelec', name: 'Facture Senelec', category: 'Factures', type: TxnType.expense, amount: 32000, description: 'Électricité Juillet 2026', payment: 'Prélèvement automatique', date: dt(9, 11, 0)),
      Txn(id: 'canal', name: 'Canal+ Abonnement', category: 'Loisirs', type: TxnType.expense, amount: 12000, description: 'Abonnement mensuel Canal+', payment: 'Carte Visa ••8842', date: dt(5, 10, 0)),
      Txn(id: 'pharmacie', name: 'Pharmacie Ouakam', category: 'Santé', type: TxnType.expense, amount: 8500, description: 'Médicaments prescription', payment: 'Carte Visa ••8842', date: dt(3, 18, 30)),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }
}
