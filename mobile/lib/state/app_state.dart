import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import '../data/api_config.dart';
import '../data/api_exception.dart';
import '../data/repositories.dart';
import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';

/// État global de l'app — branché sur l'API AFI (backend FastAPI).
///
/// L'API est la source de vérité : authentification JWT, transactions,
/// budgets et agrégats du tableau de bord viennent du serveur.
/// Seuls les réglages locaux (thème, préférences de notification)
/// et le numéro de téléphone (sans endpoint backend) restent en local.
class AppState extends ChangeNotifier {
  static final AppState I = AppState._();

  AppState._();

  /// Client HTTP remplaçable (tests).
  ApiClient? _apiInstance;
  ApiClient get api => _apiInstance ??= ApiClient(baseUrl: ApiConfig.baseUrl);
  set api(ApiClient client) => _apiInstance = client;

  AuthRepository get _authRepo => AuthRepository(api.dio);
  CategoryRepository get _categoryRepo => CategoryRepository(api.dio);
  TransactionRepository get _txnRepo => TransactionRepository(api.dio);
  BudgetRepository get _budgetRepo => BudgetRepository(api.dio);
  DashboardRepository get _dashboardRepo => DashboardRepository(api.dio);

  SharedPreferences? _prefs;
  bool _loaded = false;

  UserProfile? user;
  List<Txn> transactions = [];

  // Données serveur
  Map<String, int> categoryIds = {}; // nom -> id (GET /categories)
  List<BudgetStatusLite> budgets = [];
  int? _alimentationBudgetId;
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

  double _balance = 0;
  double _monthIncome = 0;
  double _monthExpense = 0;

  bool get loaded => _loaded;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    darkMode = _prefs!.getBool('samapoche_dark') ?? false;
    budget = _prefs!.getInt('samapoche_budget') ?? 150000;
    savingsGoal = _prefs!.getInt('samapoche_goal') ?? 300000;
    notifPush = _prefs!.getBool('samapoche_notif_push') ?? true;
    notifFactures = _prefs!.getBool('samapoche_notif_factures') ?? true;
    notifConseils = _prefs!.getBool('samapoche_notif_conseils') ?? true;
    ecoData = _prefs!.getBool('samapoche_eco') ?? false;
    budgetAuto = _prefs!.getBool('samapoche_budget_auto') ?? true;

    api.onUnauthorized = () {
      _clearSession();
      notifyListeners();
    };

    // Restauration de session si un token existe
    final token = await api.tokenStore.read();
    if (token != null) {
      try {
        await _loadCurrentUser();
        await _bootstrapServerData();
      } on ApiException catch (_) {
        await forceSignOut(); // token expiré/invalide -> retour à l'accueil
      }
    }

    _buildNotifications();
    _seedChat();
    _loaded = true;
    notifyListeners();
  }

  // ─── Auth (API) ──────────────────────────────────────────

  /// Inscription via POST /auth/register puis chargement des données.
  /// Retourne null si succès, sinon le message d'erreur à afficher.
  Future<String?> signup(UserProfile p, String password) async {
    try {
      final token = await _authRepo.register(
        email: p.email.trim(),
        password: password,
        fullName: p.fullName.trim(),
      );
      await api.saveToken(token.accessToken);
      await _loadCurrentUser(phone: p.phone);
      await _bootstrapServerData();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Connexion via POST /auth/login puis chargement des données.
  Future<String?> login(String email, String password) async {
    try {
      final token = await _authRepo.login(email.trim(), password);
      await api.saveToken(token.accessToken);
      await _loadCurrentUser();
      await _bootstrapServerData();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    await forceSignOut();
    notifyListeners();
  }

  /// Nettoie la session sans notifier (utilisé aussi par le hook 401).
  Future<void> forceSignOut() async {
    await api.forgetToken();
    _clearSession();
  }

  void _clearSession() {
    user = null;
    transactions = [];
    budgets = [];
    categoryIds = {};
    _alimentationBudgetId = null;
    _balance = 0;
    _monthIncome = 0;
    _monthExpense = 0;
    chat.clear();
    _seedChat();
  }

  Future<void> _loadCurrentUser({String? phone}) async {
    final me = await _authRepo.me();
    final savedPhone =
        phone ?? _prefs?.getString('samapoche_phone_${me.email}') ?? '';
    final parts = me.fullName.trim().split(RegExp(r'\s+'));
    user = UserProfile(
      firstName: parts.first,
      lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
      email: me.email,
      phone: savedPhone,
    );
  }

  /// Charge catégories, transactions, budgets et agrégats depuis l'API.
  Future<void> _bootstrapServerData() async {
    final cats = await _categoryRepo.list();
    categoryIds = {for (final c in cats) c.name: c.id};

    transactions = (await _txnRepo.list())
        .map((t) => t.toTxn(_categoryNames))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    await _refreshAggregates();
    await _syncAlimentationBudget(createIfMissing: false);

    _buildNotifications();
    _seedChat();
  }

  Map<int, String> get _categoryNames =>
      {for (final e in categoryIds.entries) e.value: e.key};

  // ─── Transactions (API) ──────────────────────────────────

  Future<void> addTxn(Txn t) async {
    final catId = categoryIds[t.category];
    if (catId == null) throw const ApiException('Catégorie inconnue.');
    final created = await _txnRepo.create(
      amount: t.amount.toDouble(),
      type: t.type,
      categoryId: catId,
      description: t.name,
      date: t.date,
    );
    transactions.insert(0, created.toTxn(_categoryNames));
    await _refreshAggregates();
    notifyListeners();
  }

  Future<void> updateTxn(Txn t) async {
    final id = int.tryParse(t.id);
    if (id == null) throw const ApiException('Transaction non synchronisée.');
    final catId = categoryIds[t.category];
    if (catId == null) throw const ApiException('Catégorie inconnue.');

    final i = transactions.indexWhere((x) => x.id == t.id);
    // Le backend ne permet pas de changer le type via PUT :
    // on supprime puis on recrée.
    if (i >= 0 && transactions[i].type != t.type) {
      await _txnRepo.delete(id);
      transactions.removeAt(i);
      await addTxn(t);
      return;
    }

    final updated = await _txnRepo.update(
      id: id,
      amount: t.amount.toDouble(),
      description: t.name,
      categoryId: catId,
    );
    if (i >= 0) transactions[i] = updated.toTxn(_categoryNames);
    await _refreshAggregates();
    notifyListeners();
  }

  Future<void> deleteTxn(Txn t) async {
    final id = int.tryParse(t.id);
    if (id != null) await _txnRepo.delete(id);
    transactions.removeWhere((x) => x.id == t.id);
    await _refreshAggregates();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    user = p;
    // Le téléphone n'a pas d'endpoint backend : stockage local uniquement.
    if (p.email.isNotEmpty) {
      await _prefs?.setString('samapoche_phone_${p.email}', p.phone);
    }
    notifyListeners();
  }

  // ─── Dashboard (valeurs serveur) ─────────────────────────

  int get balance =>
      _balance.round() != 0 || transactions.isEmpty
          ? _balance.round()
          : transactions.fold(0, (s, t) => s + t.signed);

  List<Txn> get monthTxns {
    final now = DateTime.now();
    return transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
  }

  int get monthIncome => _monthIncome.round() != 0 || transactions.isEmpty
      ? _monthIncome.round()
      : monthTxns.where((t) => t.type == TxnType.income).fold(0, (s, t) => s + t.amount);

  int get monthExpense => _monthExpense.round() != 0 || transactions.isEmpty
      ? _monthExpense.round()
      : monthTxns.where((t) => t.type == TxnType.expense).fold(0, (s, t) => s + t.amount);

  BudgetRow? get alimentationBudget {
    for (final b in budgets) {
      if (b.categoryName == 'Alimentation') {
        return BudgetRow(id: b.id, categoryId: b.categoryId, amount: b.amount, spent: b.spent);
      }
    }
    return null;
  }

  int get budgetSpent {
    final b = alimentationBudget;
    if (b != null) return b.spent.round();
    return transactions
        .where((t) => t.category == 'Alimentation' && t.type == TxnType.expense && _sameMonth(t.date))
        .fold(0, (s, t) => s + t.amount);
  }

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

  // ─── Budgets (API) ───────────────────────────────────────

  /// Le budget affiché correspond au budget « Alimentation » du mois
  /// côté serveur ; il est créé au premier réglage s'il n'existe pas.
  Future<void> setBudget(int v) async {
    budget = v;
    await _prefs?.setInt('samapoche_budget', v);
    final now = DateTime.now();
    final catId = categoryIds['Alimentation'];
    if (_alimentationBudgetId != null) {
      await _budgetRepo.updateAmount(_alimentationBudgetId!, v.toDouble());
    } else if (catId != null) {
      await _budgetRepo.create(
          categoryId: catId, amount: v.toDouble(), month: now.month, year: now.year);
      await _syncAlimentationBudget(createIfMissing: false);
    }
    await _refreshAggregates();
    notifyListeners();
  }

  Future<void> _syncAlimentationBudget({required bool createIfMissing}) async {
    final now = DateTime.now();
    budgets = (await _budgetRepo.list(month: now.month, year: now.year))
        .map((b) => BudgetStatusLite(
              id: b.id,
              categoryId: b.categoryId,
              categoryName: b.categoryName,
              amount: b.amount,
              spent: b.spent,
            ))
        .toList();
    final ali = budgets
        .where((b) => b.categoryName == 'Alimentation')
        .toList(growable: false);
    if (ali.isNotEmpty) {
      _alimentationBudgetId = ali.first.id;
      budget = ali.first.amount.round();
      await _prefs?.setInt('samapoche_budget', budget);
    } else if (createIfMissing && categoryIds['Alimentation'] != null) {
      await _budgetRepo.create(
        categoryId: categoryIds['Alimentation']!,
        amount: budget.toDouble(),
        month: now.month,
        year: now.year,
      );
      await _syncAlimentationBudget(createIfMissing: false);
    }
  }

  Future<void> _refreshAggregates() async {
    try {
      final bal = await _dashboardRepo.balance();
      _balance = bal.balance;
      _monthIncome = bal.monthIncome;
      _monthExpense = bal.monthExpenses;
    } on ApiException catch (_) {
      // Agrégats indisponibles : les valeurs calculées localement prennent le relais.
      _balance = transactions.fold(0, (s, t) => s + t.signed).toDouble();
      _monthIncome = monthTxns.where((t) => t.type == TxnType.income).fold(0, (s, t) => s + t.amount).toDouble();
      _monthExpense = monthTxns.where((t) => t.type == TxnType.expense).fold(0, (s, t) => s + t.amount).toDouble();
    }
  }

  // ─── Notifications (locales pour cette itération) ────────

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
        text: 'Votre budget Alimentation pour ce mois est de ${formatFCFA(budget)}. Vous avez déjà dépensé ${formatFCFA(budgetSpent)} (${(budgetPct * 100).round()}%). Il vous reste ${formatFCFA(budgetRemaining)} pour les $daysLeftInMonth prochains jours. Voulez-vous ajuster ce budget ?',
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
      return 'Votre budget Alimentation pour ce mois est de ${formatFCFA(budget)}. Vous avez déjà dépensé ${formatFCFA(budgetSpent)} (${(budgetPct * 100).round()}%). Il vous reste ${formatFCFA(budgetRemaining)} pour les $daysLeftInMonth prochains jours.';
    }
    if (ql.contains('dépense') || ql.contains('depense') || ql.contains('catégorie') || ql.contains('categorie')) {
      final parts = donutData.map((d) => '• ${d.$1} : ${formatFCFA(d.$2 == 0 ? 0 : (monthExpense * d.$2 / 100).round())}').join('\n');
      return 'Voici le résumé de vos dépenses :\n$parts\n— Total : ${formatFCFA(monthExpense)}';
    }
    if (ql.contains('épargne') || ql.contains('epargne') || ql.contains('économi') || ql.contains('economi')) {
      return 'Pour atteindre votre objectif d\'épargne de ${formatFCFA(savingsGoal)} :\n1. Réduisez vos dépenses alimentation de 15%\n2. Limitez les dépenses non essentielles\n3. Activez l\'arrondi automatique sur chaque transaction';
    }
    if (ql.contains('conseil') || ql.contains('astuce') || ql.contains('mieu')) {
      return 'Voici 3 conseils personnalisés :\n1. Réduisez vos sorties restaurant de 20% ce mois-ci\n2. Privilégiez les achats en gros\n3. Activez les notifications de dépassement de budget';
    }
    if (ql.contains('salaire') || ql.contains('revenu')) {
      return 'Depuis le début du mois, vous avez reçu ${formatFCFA(monthIncome)} et dépensé ${formatFCFA(monthExpense)}, soit un taux d\'épargne de ${monthIncome == 0 ? 0 : (100 - monthExpense / monthIncome * 100).round()}%. Excellent travail !';
    }
    return 'Je suis votre assistant financier SamaPoche. Je peux vous aider à :\n• Consulter votre budget mensuel\n• Analyser vos dépenses par catégorie\n• Fixer des objectifs d\'épargne\n• Obtenir des conseils personnalisés\n\nQue souhaitez-vous savoir ?';
  }

  // ─── Settings ────────────────────────────────────────────

  Future<void> setDarkMode(bool v) async {
    darkMode = v;
    await _prefs!.setBool('samapoche_dark', v);
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
}

/// Vue simplifiée d'un budget serveur pour l'affichage.
class BudgetRow {
  final int id;
  final int categoryId;
  final double amount;
  final double spent;

  const BudgetRow({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.spent,
  });
}

/// Copie légère de [ApiBudgetStatus] pour éviter une dépendance
/// circulaire entre data/ et state/.
class BudgetStatusLite {
  final int id;
  final int categoryId;
  final String categoryName;
  final double amount;
  final double spent;

  const BudgetStatusLite({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.spent,
  });
}
