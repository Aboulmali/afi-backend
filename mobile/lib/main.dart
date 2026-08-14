import 'package:flutter/material.dart';

void main() {
  runApp(const SamaPocheApp());
}

class SamaPocheApp extends StatelessWidget {
  const SamaPocheApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SamaPoche',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('SamaPoche')),
      ),
    );
  }
}
