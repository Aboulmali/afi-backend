import 'package:flutter/material.dart';
import 'package:samapoche/screens/root_shell.dart';
import 'package:samapoche/theme.dart';
import 'package:samapoche/widgets/widgets.dart';

class WelcomeScreen extends StatelessWidget {
  final void Function(RouteName) go;
  const WelcomeScreen({super.key, required this.go});

  @override
  Widget build(BuildContext context) {
    final accent = context.isDark ? AppDark.accent : AppColors.accent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.savings_rounded, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'SamaPoche',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.03, fontFamily: 'Inter'),
            ),
            const SizedBox(height: 8),
            Text(
              'Gérez mieux. Économisez plus.',
              style: TextStyle(fontSize: 17, color: context.isDark ? AppDark.muted : AppColors.muted),
            ),
            const Spacer(),
            AppButton(
              label: "S'identifier",
              primary: true,
              large: true,
              onPressed: () => go(RouteName.login),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Créer un compte',
              outline: true,
              large: true,
              onPressed: () => go(RouteName.signup),
            ),
          ],
        ),
      ),
    );
  }
}
