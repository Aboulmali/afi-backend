import '../../models/models.dart';

/// Modèles de transport alignés 1:1 sur les schémas Pydantic du backend
/// (`app/schemas/*.py`).

class ApiUser {
  final int id;
  final String email;
  final String fullName;

  const ApiUser({required this.id, required this.email, required this.fullName});

  factory ApiUser.fromJson(Map<String, dynamic> j) => ApiUser(
        id: j['id'] as int,
        email: j['email'] as String,
        fullName: j['full_name'] as String,
      );
}

class ApiToken {
  final String accessToken;
  final String tokenType;

  const ApiToken({required this.accessToken, required this.tokenType});

  factory ApiToken.fromJson(Map<String, dynamic> j) => ApiToken(
        accessToken: j['access_token'] as String,
        tokenType: (j['token_type'] ?? 'bearer') as String,
      );
}

class ApiCategory {
  final int id;
  final String name;

  const ApiCategory({required this.id, required this.name});

  factory ApiCategory.fromJson(Map<String, dynamic> j) =>
      ApiCategory(id: j['id'] as int, name: j['name'] as String);
}

class ApiTransaction {
  final int id;
  final double amount;
  final TxnType type;
  final String description;
  final int categoryId;
  final DateTime transactionDate;

  const ApiTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.categoryId,
    required this.transactionDate,
  });

  factory ApiTransaction.fromJson(Map<String, dynamic> j) => ApiTransaction(
        id: j['id'] as int,
        amount: (j['amount'] as num).toDouble(),
        type: TxnType.values.firstWhere((t) => t.name == j['type']),
        description: (j['description'] ?? '') as String,
        categoryId: j['category_id'] as int,
        transactionDate: DateTime.parse(j['transaction_date'] as String),
      );

  /// Convertit vers le modèle d'affichage de l'app.
  /// Le backend ne connaît pas le moyen de paiement : il est conservé vide.
  Txn toTxn(Map<int, String> categoryNames) => Txn(
        id: id.toString(),
        name: description.isEmpty ? (categoryNames[categoryId] ?? 'Transaction') : description,
        category: categoryNames[categoryId] ?? 'Autre',
        type: type,
        amount: amount.round(),
        description: description,
        payment: '',
        date: transactionDate.toLocal(),
      );
}

class ApiBudgetStatus {
  final int id;
  final int categoryId;
  final String categoryName;
  final double amount;
  final double spent;
  final double percentage;
  final bool alert80;
  final bool alert100;
  final double remaining;

  const ApiBudgetStatus({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.spent,
    required this.percentage,
    required this.alert80,
    required this.alert100,
    required this.remaining,
  });

  factory ApiBudgetStatus.fromJson(Map<String, dynamic> j) => ApiBudgetStatus(
        id: j['id'] as int,
        categoryId: j['category_id'] as int,
        categoryName: j['category_name'] as String,
        amount: (j['amount'] as num).toDouble(),
        spent: (j['spent'] as num).toDouble(),
        percentage: (j['percentage'] as num).toDouble(),
        alert80: j['alert_80'] as bool,
        alert100: j['alert_100'] as bool,
        remaining: (j['remaining'] as num).toDouble(),
      );
}

class ApiBalance {
  final double balance;
  final double totalIncome;
  final double totalExpenses;
  final double monthIncome;
  final double monthExpenses;

  const ApiBalance({
    required this.balance,
    required this.totalIncome,
    required this.totalExpenses,
    required this.monthIncome,
    required this.monthExpenses,
  });

  factory ApiBalance.fromJson(Map<String, dynamic> j) => ApiBalance(
        balance: (j['balance'] as num).toDouble(),
        totalIncome: (j['total_income'] as num).toDouble(),
        totalExpenses: (j['total_expenses'] as num).toDouble(),
        monthIncome: (j['month_income'] as num).toDouble(),
        monthExpenses: (j['month_expenses'] as num).toDouble(),
      );
}
