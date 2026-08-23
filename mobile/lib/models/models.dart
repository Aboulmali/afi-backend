import 'package:flutter/material.dart';

enum TxnType { expense, income }

class Category {
  final String name;
  final String emoji;
  final Color bg;
  final Color fg;
  final IconData icon;

  const Category(this.name, this.emoji, this.bg, this.fg, this.icon);
}

class Categories {
  static const alimentation = Category('Alimentation', '🛒', Color(0xFFFEF3C7), Color(0xFFD97706), Icons.restaurant);
  static const transport = Category('Transport', '🚗', Color(0xFFDBEAFE), Color(0xFF2563EB), Icons.directions_car);
  static const shopping = Category('Shopping', '🛍️', Color(0xFFFCE7F3), Color(0xFFDB2777), Icons.shopping_cart);
  static const factures = Category('Factures', '🧾', Color(0xFFFEE2E2), Color(0xFFDC2626), Icons.receipt_long);
  static const loisirs = Category('Loisirs', '🎮', Color(0xFFEDE9FE), Color(0xFF7C3AED), Icons.chat_bubble);
  static const sante = Category('Santé', '❤️', Color(0xFFDCFCE7), Color(0xFF16A34A), Icons.monitor_heart);
  static const salaire = Category('Salaire', '💰', Color(0xFFDBEAFE), Color(0xFF16A34A), Icons.attach_money);
  static const autre = Category('Autre', '📦', Color(0xFFF3F4F6), Color(0xFF6B7280), Icons.circle_outlined);

  static const all = [alimentation, transport, shopping, factures, loisirs, sante, salaire, autre];

  static Category byName(String name) =>
      all.firstWhere((c) => c.name == name, orElse: () => autre);

  static const expenses = [alimentation, transport, shopping, factures, loisirs, sante, autre];
}

class Txn {
  final String id;
  final String name;
  final String category;
  final TxnType type;
  final int amount; // F CFA, toujours positif
  final String description;
  final String payment;
  final DateTime date;

  const Txn({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.amount,
    required this.description,
    required this.payment,
    required this.date,
  });

  int get signed => type == TxnType.expense ? -amount : amount;

  Txn copyWith({String? name, String? category, TxnType? type, int? amount, String? description, String? payment, DateTime? date}) => Txn(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        payment: payment ?? this.payment,
        date: date ?? this.date,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'type': type.name,
        'amount': amount,
        'description': description,
        'payment': payment,
        'date': date.toIso8601String(),
      };

  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        type: TxnType.values.firstWhere((t) => t.name == j['type']),
        amount: (j['amount'] as num).toInt(),
        description: (j['description'] ?? '') as String,
        payment: (j['payment'] ?? '') as String,
        date: DateTime.parse(j['date'] as String),
      );
}

class UserProfile {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.characters.first}${lastName.characters.first}'.toUpperCase();

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        firstName: j['firstName'] as String,
        lastName: j['lastName'] as String,
        email: j['email'] as String,
        phone: (j['phone'] ?? '') as String,
      );
}

class AppNotification {
  final String title;
  final String desc;
  final String time;
  final String group;
  final Color bg;
  final Color fg;
  final IconData icon;
  bool read;

  AppNotification({
    required this.title,
    required this.desc,
    required this.time,
    required this.group,
    required this.bg,
    required this.fg,
    required this.icon,
    this.read = false,
  });
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage({required this.text, required this.fromUser, required this.time});
}
